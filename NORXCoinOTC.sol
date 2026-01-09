// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title NORXCoinOTC
 * @dev Contrato de venda direta (OTC) para NORXCOIN na BSC
 * @notice Este contrato permite a compra de NORX com BNB ou USDT
 * 
 * Fluxo de compra (exemplo: 1.000 NORX):
 * - Usuário paga valor equivalente em BNB ou USDT
 * - Usuário recebe: 985 NORX (98,5%)
 * - Carteira de taxa recebe: 15 NORX (1,5%)
 * - Dead wallet recebe: 100 NORX (10% queima sobre valor bruto)
 * - Total saindo do contrato: 1.100 NORX
 */
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract NORXCoinOTC is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ============================================
    // STATE VARIABLES
    // ============================================
    
    /// @notice Endereço do token NORXCOIN
    IERC20 public immutable norxToken;
    
    /// @notice Endereço do USDT (BEP-20) na BSC
    IERC20 public immutable usdtToken;
    
    /// @notice Oracle Chainlink para BNB/USD na BSC Mainnet
    AggregatorV3Interface public immutable bnbUsdPriceFeed;
    
    /// @notice Endereço da carteira morta para queima
    address public constant DEAD_WALLET = 0x000000000000000000000000000000000000dEaD;
    
    /// @notice Carteira que recebe as taxas de 1,5%
    address public feeWallet;
    
    /// @notice Carteira que recebe os pagamentos (BNB/USDT)
    address public paymentWallet;
    
    /// @notice Carteira autorizada a gerenciar o estoque de tokens
    address public stockManager;
    
    /// @notice Preço de venda em USD (com 6 decimais - ex: 0.04 USD = 40000)
    /// @dev 1 USD = 1_000_000, então $0.04 = 40_000
    uint256 public priceUSD;
    
    /// @notice Taxa de operação em basis points (150 = 1.5%)
    uint256 public constant FEE_RATE = 150;
    
    /// @notice Taxa de queima em basis points (1000 = 10%)
    uint256 public constant BURN_RATE = 1000;
    
    /// @notice Base para cálculo de porcentagens (10000 = 100%)
    uint256 public constant BASIS_POINTS = 10000;
    
    /// @notice Decimais do preço USD (6 decimais)
    uint256 public constant PRICE_DECIMALS = 6;

    // ============================================
    // EVENTS
    // ============================================
    
    event TokensPurchased(
        address indexed buyer,
        uint256 tokenAmount,
        uint256 amountPaid,
        address paymentToken,
        uint256 feeAmount,
        uint256 burnAmount
    );
    
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event FeeWalletUpdated(address oldWallet, address newWallet);
    event PaymentWalletUpdated(address oldWallet, address newWallet);
    event StockManagerUpdated(address oldManager, address newManager);
    event TokensDeposited(address indexed from, uint256 amount);
    event TokensWithdrawn(address indexed to, uint256 amount);
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);

    // ============================================
    // MODIFIERS
    // ============================================
    
    modifier onlyStockManager() {
        require(msg.sender == stockManager, "Only stock manager can call this");
        _;
    }

    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    /**
     * @notice Inicializa o contrato OTC
     * @param _norxToken Endereço do token NORXCOIN
     * @param _usdtToken Endereço do USDT (BEP-20)
     * @param _bnbUsdPriceFeed Oracle Chainlink BNB/USD
     * @param _feeWallet Carteira que recebe as taxas
     * @param _paymentWallet Carteira que recebe os pagamentos
     * @param _stockManager Carteira autorizada a gerenciar estoque
     * @param _initialPriceUSD Preço inicial em USD (6 decimais)
     */
    constructor(
        address _norxToken,
        address _usdtToken,
        address _bnbUsdPriceFeed,
        address _feeWallet,
        address _paymentWallet,
        address _stockManager,
        uint256 _initialPriceUSD
    ) Ownable(msg.sender) {
        require(_norxToken != address(0), "Invalid token address");
        require(_usdtToken != address(0), "Invalid USDT address");
        require(_bnbUsdPriceFeed != address(0), "Invalid price feed");
        require(_feeWallet != address(0), "Invalid fee wallet");
        require(_paymentWallet != address(0), "Invalid payment wallet");
        require(_stockManager != address(0), "Invalid stock manager");
        require(_initialPriceUSD > 0, "Price must be greater than 0");
        
        norxToken = IERC20(_norxToken);
        usdtToken = IERC20(_usdtToken);
        bnbUsdPriceFeed = AggregatorV3Interface(_bnbUsdPriceFeed);
        feeWallet = _feeWallet;
        paymentWallet = _paymentWallet;
        stockManager = _stockManager;
        priceUSD = _initialPriceUSD;
    }

    // ============================================
    // EXTERNAL FUNCTIONS - PURCHASE
    // ============================================
    
    /**
     * @notice Compra NORX tokens com BNB
     * @param tokenAmount Quantidade de NORX tokens desejada
     */
    function buyWithBNB(uint256 tokenAmount) external payable nonReentrant whenNotPaused {
        require(tokenAmount > 0, "Amount must be greater than 0");
        
        // Calcula valores
        (uint256 totalNeeded, uint256 userReceives, uint256 feeAmount, uint256 burnAmount) = 
            calculatePurchaseAmounts(tokenAmount);
        
        // Verifica estoque disponível
        uint256 contractBalance = norxToken.balanceOf(address(this));
        require(contractBalance >= totalNeeded, "Insufficient token balance in contract");
        
        // Calcula quanto BNB é necessário
        uint256 bnbRequired = calculateBNBAmount(tokenAmount);
        require(msg.value >= bnbRequired, "Insufficient BNB sent");
        
        // Transfere BNB para carteira de pagamentos
        (bool success, ) = paymentWallet.call{value: msg.value}("");
        require(success, "BNB transfer failed");
        
        // Executa as transferências de tokens
        _executeTokenTransfers(msg.sender, userReceives, feeAmount, burnAmount);
        
        emit TokensPurchased(
            msg.sender,
            tokenAmount,
            msg.value,
            address(0), // address(0) representa BNB
            feeAmount,
            burnAmount
        );
    }
    
    /**
     * @notice Compra NORX tokens com USDT
     * @param tokenAmount Quantidade de NORX tokens desejada
     */
    function buyWithUSDT(uint256 tokenAmount) external nonReentrant whenNotPaused {
        require(tokenAmount > 0, "Amount must be greater than 0");
        
        // Calcula valores
        (uint256 totalNeeded, uint256 userReceives, uint256 feeAmount, uint256 burnAmount) = 
            calculatePurchaseAmounts(tokenAmount);
        
        // Verifica estoque disponível
        uint256 contractBalance = norxToken.balanceOf(address(this));
        require(contractBalance >= totalNeeded, "Insufficient token balance in contract");
        
        // Calcula quanto USDT é necessário
        uint256 usdtRequired = calculateUSDTAmount(tokenAmount);
        
        // Transfere USDT do comprador para carteira de pagamentos
        usdtToken.safeTransferFrom(msg.sender, paymentWallet, usdtRequired);
        
        // Executa as transferências de tokens
        _executeTokenTransfers(msg.sender, userReceives, feeAmount, burnAmount);
        
        emit TokensPurchased(
            msg.sender,
            tokenAmount,
            usdtRequired,
            address(usdtToken),
            feeAmount,
            burnAmount
        );
    }

    // ============================================
    // INTERNAL FUNCTIONS
    // ============================================
    
    /**
     * @dev Executa as transferências de tokens para comprador, fee wallet e burn
     */
    function _executeTokenTransfers(
        address buyer,
        uint256 userReceives,
        uint256 feeAmount,
        uint256 burnAmount
    ) internal {
        // Transfere tokens para o comprador (98,5%)
        norxToken.safeTransfer(buyer, userReceives);
        
        // Transfere taxa para fee wallet (1,5%)
        norxToken.safeTransfer(feeWallet, feeAmount);
        
        // Queima tokens (10%)
        norxToken.safeTransfer(DEAD_WALLET, burnAmount);
    }

    // ============================================
    // VIEW FUNCTIONS - CALCULATIONS
    // ============================================
    
    /**
     * @notice Calcula os valores de uma compra
     * @param tokenAmount Quantidade de tokens desejada
     * @return totalNeeded Total de tokens que saem do contrato
     * @return userReceives Tokens que o usuário recebe (98,5%)
     * @return feeAmount Tokens de taxa (1,5%)
     * @return burnAmount Tokens queimados (10%)
     */
    function calculatePurchaseAmounts(uint256 tokenAmount) 
        public 
        pure 
        returns (
            uint256 totalNeeded,
            uint256 userReceives,
            uint256 feeAmount,
            uint256 burnAmount
        ) 
    {
        // Calcula taxa (1,5%)
        feeAmount = (tokenAmount * FEE_RATE) / BASIS_POINTS;
        
        // Calcula queima (10%)
        burnAmount = (tokenAmount * BURN_RATE) / BASIS_POINTS;
        
        // Usuário recebe: valor total - taxa
        userReceives = tokenAmount - feeAmount;
        
        // Total necessário: valor da compra + queima
        totalNeeded = tokenAmount + burnAmount;
    }
    
    /**
     * @notice Calcula quanto BNB é necessário para comprar X tokens
     * @param tokenAmount Quantidade de tokens desejada
     * @return BNB necessário (em wei)
     */
    function calculateBNBAmount(uint256 tokenAmount) public view returns (uint256) {
        // Preço total em USD (com 6 decimais)
        uint256 totalUSD = (tokenAmount * priceUSD) / (10 ** 18); // NORX tem 18 decimais
        
        // Obtém preço do BNB em USD
        uint256 bnbPriceUSD = getBNBPrice();
        
        // Calcula BNB necessário
        // totalUSD tem 6 decimais, bnbPriceUSD tem 8 decimais
        // Resultado deve ter 18 decimais (wei)
        uint256 bnbAmount = (totalUSD * 10 ** 20) / bnbPriceUSD;
        
        return bnbAmount;
    }
    
    /**
     * @notice Calcula quanto USDT é necessário para comprar X tokens
     * @param tokenAmount Quantidade de tokens desejada
     * @return USDT necessário (com 18 decimais)
     */
    function calculateUSDTAmount(uint256 tokenAmount) public view returns (uint256) {
        // Preço total em USD (com 6 decimais)
        uint256 totalUSD = (tokenAmount * priceUSD) / (10 ** 18); // NORX tem 18 decimais
        
        // USDT tem 18 decimais na BSC
        // Converte de 6 decimais para 18 decimais
        uint256 usdtAmount = totalUSD * 10 ** 12;
        
        return usdtAmount;
    }
    
    /**
     * @notice Obtém o preço atual do BNB em USD
     * @return Preço do BNB com 8 decimais
     */
    function getBNBPrice() public view returns (uint256) {
        (
            /* uint80 roundId */,
            int256 answer,
            /* uint256 startedAt */,
            uint256 updatedAt,
            /* uint80 answeredInRound */
        ) = bnbUsdPriceFeed.latestRoundData();
        
        require(answer > 0, "Invalid price from oracle");
        require(updatedAt > 0, "Price not updated");
        require(block.timestamp - updatedAt < 1 hours, "Price data too old");
        
        return uint256(answer); // Retorna com 8 decimais
    }
    
    /**
     * @notice Retorna o estoque disponível de NORX no contrato
     * @return Quantidade de tokens disponíveis
     */
    function getAvailableStock() external view returns (uint256) {
        return norxToken.balanceOf(address(this));
    }

    // ============================================
    // ADMIN FUNCTIONS - STOCK MANAGEMENT
    // ============================================
    
    /**
     * @notice Deposita tokens NORX no contrato (apenas Stock Manager)
     * @param amount Quantidade de tokens a depositar
     */
    function depositTokens(uint256 amount) external onlyStockManager {
        require(amount > 0, "Amount must be greater than 0");
        
        norxToken.safeTransferFrom(msg.sender, address(this), amount);
        
        emit TokensDeposited(msg.sender, amount);
    }
    
    /**
     * @notice Saca tokens NORX do contrato (apenas Stock Manager)
     * @param amount Quantidade de tokens a sacar
     */
    function withdrawTokens(uint256 amount) external onlyStockManager {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 contractBalance = norxToken.balanceOf(address(this));
        require(contractBalance >= amount, "Insufficient balance");
        
        norxToken.safeTransfer(msg.sender, amount);
        
        emit TokensWithdrawn(msg.sender, amount);
    }

    // ============================================
    // ADMIN FUNCTIONS - CONFIGURATION
    // ============================================
    
    /**
     * @notice Atualiza o preço de venda em USD (apenas Owner)
     * @param newPriceUSD Novo preço com 6 decimais
     */
    function updatePrice(uint256 newPriceUSD) external onlyOwner {
        require(newPriceUSD > 0, "Price must be greater than 0");
        
        uint256 oldPrice = priceUSD;
        priceUSD = newPriceUSD;
        
        emit PriceUpdated(oldPrice, newPriceUSD);
    }
    
    /**
     * @notice Atualiza a carteira que recebe as taxas (apenas Owner)
     * @param newFeeWallet Novo endereço da fee wallet
     */
    function updateFeeWallet(address newFeeWallet) external onlyOwner {
        require(newFeeWallet != address(0), "Invalid address");
        
        address oldWallet = feeWallet;
        feeWallet = newFeeWallet;
        
        emit FeeWalletUpdated(oldWallet, newFeeWallet);
    }
    
    /**
     * @notice Atualiza a carteira que recebe os pagamentos (apenas Owner)
     * @param newPaymentWallet Novo endereço da payment wallet
     */
    function updatePaymentWallet(address newPaymentWallet) external onlyOwner {
        require(newPaymentWallet != address(0), "Invalid address");
        
        address oldWallet = paymentWallet;
        paymentWallet = newPaymentWallet;
        
        emit PaymentWalletUpdated(oldWallet, newPaymentWallet);
    }
    
    /**
     * @notice Atualiza o gerente de estoque (apenas Owner)
     * @param newStockManager Novo endereço do stock manager
     */
    function updateStockManager(address newStockManager) external onlyOwner {
        require(newStockManager != address(0), "Invalid address");
        
        address oldManager = stockManager;
        stockManager = newStockManager;
        
        emit StockManagerUpdated(oldManager, newStockManager);
    }
    
    /**
     * @notice Pausa o contrato (apenas Owner)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Retoma o contrato (apenas Owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @notice Saque de emergência de qualquer token (apenas Owner)
     * @param token Endereço do token (use address(0) para BNB)
     * @param to Endereço destino
     * @param amount Quantidade a sacar
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");
        
        if (token == address(0)) {
            // Saque de BNB
            (bool success, ) = to.call{value: amount}("");
            require(success, "BNB transfer failed");
        } else {
            // Saque de token ERC20
            IERC20(token).safeTransfer(to, amount);
        }
        
        emit EmergencyWithdraw(token, to, amount);
    }
    
    /**
     * @notice Permite que o contrato receba BNB
     */
    receive() external payable {}
}
