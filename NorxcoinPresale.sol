// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NorxcoinPresale is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IERC20 public norxcoin;
    
    // PREÇOS FIXOS EM BNB PARA CADA TIER
    uint256 public constant BRONZE_MAX = 100_000 * 10**18; // 100k tokens
    uint256 public constant SILVER_MAX = 500_000 * 10**18; // 500k tokens  
    uint256 public constant GOLD_MAX = 1_000_000 * 10**18; // 1M tokens
    
    uint256 public constant BRONZE_PRICE_BNB = 16666666666666666; // ~0.0167 BNB ≈ $10
    uint256 public constant SILVER_PRICE_BNB = 83333333333333333; // ~0.0833 BNB ≈ $50  
    uint256 public constant GOLD_PRICE_BNB = 166666666666666666;  // ~0.1667 BNB ≈ $100
    
    uint256 public constant BRONZE_LIMIT = 500;
    uint256 public constant SILVER_LIMIT = 100;
    uint256 public constant GOLD_LIMIT = 50;
    uint256 public constant TOTAL_TOKENS_FOR_SALE = 150_000_000 * 10**18;
    
    uint256 public totalTokensSold;
    uint256 public totalBNBRaised;
    uint256 public participantCount;
    uint256 public bronzeParticipants;
    uint256 public silverParticipants;
    uint256 public goldParticipants;
    
    mapping(address => uint256) public tokensPurchased;
    mapping(address => uint256) public bnbContributed;
    mapping(address => bool) public hasParticipated;
    
    address[] public participants;
    address public treasuryWallet;
    
    event TokensPurchased(address indexed buyer, uint256 bnbAmount, uint256 tokenAmount);
    event PresaleFinalized(uint256 totalTokensSold, uint256 totalBNBRaised);

    constructor(address _norxcoinAddress, address _treasuryWallet) {
        require(_norxcoinAddress != address(0), "Token address cannot be zero");
        require(_treasuryWallet != address(0), "Treasury wallet cannot be zero");
        
        norxcoin = IERC20(_norxcoinAddress);
        treasuryWallet = _treasuryWallet;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    function buyBronze() external payable nonReentrant whenNotPaused {
        require(bronzeParticipants < BRONZE_LIMIT, "Bronze tier sold out");
        require(!hasParticipated[msg.sender], "Already participated");
        require(msg.value >= BRONZE_PRICE_BNB, "Insufficient BNB for Bronze tier");
        
        _processPurchase(BRONZE_MAX, BRONZE_PRICE_BNB);
        bronzeParticipants = bronzeParticipants.add(1);
    }
    
    function buySilver() external payable nonReentrant whenNotPaused {
        require(silverParticipants < SILVER_LIMIT, "Silver tier sold out");
        require(!hasParticipated[msg.sender], "Already participated");
        require(msg.value >= SILVER_PRICE_BNB, "Insufficient BNB for Silver tier");
        
        _processPurchase(SILVER_MAX, SILVER_PRICE_BNB);
        silverParticipants = silverParticipants.add(1);
    }
    
    function buyGold() external payable nonReentrant whenNotPaused {
        require(goldParticipants < GOLD_LIMIT, "Gold tier sold out");
        require(!hasParticipated[msg.sender], "Already participated");
        require(msg.value >= GOLD_PRICE_BNB, "Insufficient BNB for Gold tier");
        
        _processPurchase(GOLD_MAX, GOLD_PRICE_BNB);
        goldParticipants = goldParticipants.add(1);
    }
    
    function _processPurchase(uint256 tokenAmount, uint256 bnbRequired) internal {
        require(norxcoin.balanceOf(address(this)) >= tokenAmount, "Insufficient token balance");
        require(totalTokensSold.add(tokenAmount) <= TOTAL_TOKENS_FOR_SALE, "Exceeds total tokens for sale");
        
        participants.push(msg.sender);
        hasParticipated[msg.sender] = true;
        participantCount = participantCount.add(1);
        
        tokensPurchased[msg.sender] = tokenAmount;
        bnbContributed[msg.sender] = bnbRequired;
        totalTokensSold = totalTokensSold.add(tokenAmount);
        totalBNBRaised = totalBNBRaised.add(bnbRequired);
        
        norxcoin.safeTransfer(msg.sender, tokenAmount);
        payable(treasuryWallet).transfer(bnbRequired);
        
        uint256 excess = msg.value.sub(bnbRequired);
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
        
        emit TokensPurchased(msg.sender, bnbRequired, tokenAmount);
    }

    function getTierPrices() external pure returns (uint256, uint256, uint256) {
        return (BRONZE_PRICE_BNB, SILVER_PRICE_BNB, GOLD_PRICE_BNB);
    }

    function getTierAvailability() external view returns (bool, bool, bool, uint256, uint256, uint256) {
        return (
            bronzeParticipants < BRONZE_LIMIT,
            silverParticipants < SILVER_LIMIT,
            goldParticipants < GOLD_LIMIT,
            BRONZE_LIMIT.sub(bronzeParticipants),
            SILVER_LIMIT.sub(silverParticipants),
            GOLD_LIMIT.sub(goldParticipants)
        );
    }

    function pausePresale() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpausePresale() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function finalizePresale() external onlyRole(ADMIN_ROLE) {
        _pause();
        uint256 remainingTokens = norxcoin.balanceOf(address(this));
        if (remainingTokens > 0) {
            norxcoin.safeTransfer(treasuryWallet, remainingTokens);
        }
        emit PresaleFinalized(totalTokensSold, totalBNBRaised);
    }

    receive() external payable {
        revert("Use buyBronze(), buySilver() or buyGold() functions");
    }
}
