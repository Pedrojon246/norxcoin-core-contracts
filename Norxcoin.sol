// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NorxcoinUpdated is ERC20, ERC20Burnable, Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TAX_MANAGER_ROLE = keccak256("TAX_MANAGER_ROLE");

    uint256 public constant INITIAL_SUPPLY = 1_500_000_000 * 10**18;
    uint256 public constant INITIAL_BURN_AMOUNT = 375_000_000 * 10**18;
    uint256 public constant COMPANY_AMOUNT = 300_000_000 * 10**18;
    uint256 public constant REWARDS_AMOUNT = 300_000_000 * 10**18;
    uint256 public constant TEAM_AMOUNT = 75_000_000 * 10**18;
    uint256 public constant PERSONAL_AMOUNT = 75_000_000 * 10**18;

    uint256 public transferTaxRate = 150; // 1,5%
    uint256 public constant TAX_DENOMINATOR = 10000;
    address public taxRecipient;
    
    mapping(address => bool) public isExcludedFromTax;

    address public teamVestingContract;
    address public treasuryAddress;
    address public rewardsAddress;
    address public personalAddress;

    event TokensAllocated(address indexed to, uint256 amount, string purpose);
    event TransferTaxRateUpdated(uint256 previousRate, uint256 newRate);
    event TaxRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event AddressExcludedFromTax(address indexed account);
    event TaxCollected(address indexed from, address indexed to, uint256 taxAmount);

    constructor(
        address _treasuryAddress,
        address _rewardsAddress,
        address _personalAddress,
        address _taxRecipient
    ) ERC20("Norxcoin", "NORX") {
        require(_treasuryAddress != address(0), "Treasury address cannot be zero");
        require(_rewardsAddress != address(0), "Rewards address cannot be zero");
        require(_personalAddress != address(0), "Personal address cannot be zero");
        require(_taxRecipient != address(0), "Tax recipient address cannot be zero");

        treasuryAddress = _treasuryAddress;
        rewardsAddress = _rewardsAddress;
        personalAddress = _personalAddress;
        taxRecipient = _taxRecipient;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(TAX_MANAGER_ROLE, msg.sender);

        // Mint total supply
        _mint(address(this), INITIAL_SUPPLY);
        
        // Burn 25%
        _burn(address(this), INITIAL_BURN_AMOUNT);
        
        // Distribute tokens
        _transfer(address(this), treasuryAddress, COMPANY_AMOUNT);
        emit TokensAllocated(treasuryAddress, COMPANY_AMOUNT, "Company Reserve");

        _transfer(address(this), rewardsAddress, REWARDS_AMOUNT);
        emit TokensAllocated(rewardsAddress, REWARDS_AMOUNT, "Rewards Pool");
        
        _transfer(address(this), personalAddress, PERSONAL_AMOUNT);
        emit TokensAllocated(personalAddress, PERSONAL_AMOUNT, "Personal Wallet");

        // Exclude from tax
        isExcludedFromTax[address(this)] = true;
        isExcludedFromTax[treasuryAddress] = true;
        isExcludedFromTax[rewardsAddress] = true;
        isExcludedFromTax[personalAddress] = true;
        isExcludedFromTax[_taxRecipient] = true;
        isExcludedFromTax[msg.sender] = true;
    }

    function setTeamVestingContract(address _teamVestingContract) external onlyRole(ADMIN_ROLE) {
        require(_teamVestingContract != address(0), "Vesting contract cannot be zero");
        require(teamVestingContract == address(0), "Vesting contract already set");
        
        teamVestingContract = _teamVestingContract;
        _transfer(address(this), teamVestingContract, TEAM_AMOUNT);
        isExcludedFromTax[_teamVestingContract] = true;
        
        emit TokensAllocated(teamVestingContract, TEAM_AMOUNT, "Team Vesting");
    }

    function transferForLiquidity(address liquidityManager) external onlyRole(ADMIN_ROLE) {
        require(liquidityManager != address(0), "Liquidity manager cannot be zero");
        uint256 remainingLiquidity = balanceOf(address(this));
        require(remainingLiquidity > 0, "No tokens left for liquidity");
        
        isExcludedFromTax[liquidityManager] = true;
        _transfer(address(this), liquidityManager, remainingLiquidity);
        emit TokensAllocated(liquidityManager, remainingLiquidity, "PancakeSwap Liquidity");
    }

    function setTransferTaxRate(uint256 newTaxRate) external onlyRole(TAX_MANAGER_ROLE) {
        require(newTaxRate <= 1000, "Tax rate cannot exceed 10%");
        emit TransferTaxRateUpdated(transferTaxRate, newTaxRate);
        transferTaxRate = newTaxRate;
    }

    function setTaxRecipient(address newTaxRecipient) external onlyRole(TAX_MANAGER_ROLE) {
        require(newTaxRecipient != address(0), "Tax recipient cannot be zero");
        isExcludedFromTax[newTaxRecipient] = true;
        emit TaxRecipientUpdated(taxRecipient, newTaxRecipient);
        taxRecipient = newTaxRecipient;
    }

    function excludeFromTax(address account) external onlyRole(TAX_MANAGER_ROLE) {
        isExcludedFromTax[account] = true;
        emit AddressExcludedFromTax(account);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transferWithTax(owner, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferWithTax(from, to, amount);
        return true;
    }

    function _transferWithTax(address from, address to, uint256 amount) internal {
        require(!paused(), "Token transfers are paused");
        
        if (isExcludedFromTax[from] || isExcludedFromTax[to] || transferTaxRate == 0) {
            _transfer(from, to, amount);
            return;
        }
        
        uint256 taxAmount = (amount * transferTaxRate) / TAX_DENOMINATOR;
        uint256 amountAfterTax = amount - taxAmount;
        
        _transfer(from, to, amountAfterTax);
        _transfer(from, taxRecipient, taxAmount);
        
        emit TaxCollected(from, to, taxAmount);
    }
}
