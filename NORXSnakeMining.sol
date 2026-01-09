// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

contract NORXSnakeMining {
    
    IERC20 public norxToken;
    IERC20 public usdtToken;
    
    address public constant TREASURY = 0x69BCFbC6533C94350D2EbCe457758D17dAbdB1b1;
    address public constant ADMIN = 0x797Eb3b6fDfc4f96512eC0061E4D5242FbDED434;
    address public constant NORX_TOKEN = 0x9F8ace87A43851aCc21B6a00A84b4F9088563179;
    
    address public owner;
    uint256 private _guard = 1;
    bool public paused;
    
    enum Tier { Iniciante, Bronze, Prata, Ouro, Platina, Diamante }
    enum PaymentMethod { NORX_MINERADO, BNB, USDT }
    
    struct TierConfig {
        uint256 minBalance;
        uint256 rewardPerToken;
        uint256 dailyLimit;
        bool active;
    }
    
    struct PlayerStats {
        uint256 norxMinedBalance;
        uint256 totalMined;
        uint256 todayMined;
        uint256 lastMiningTime;
        uint256 lastDailyReset;
        uint256 gamesPlayed;
        uint256 highScore;
        Tier currentTier;
        mapping(uint256 => bool) ownedItems;
    }
    
    struct MarketplaceItem {
        uint256 priceNORX;
        uint256 priceBNB;
        uint256 priceUSDT;
        uint256 durationHours;
        bool isActive;
        bool acceptsNORX;
        bool acceptsBNB;
        bool acceptsUSDT;
        Tier minTier;
        uint256 maxPurchases;
        uint256 totalPurchased;
    }
    
    struct GameSession {
        address player;
        uint256 startTime;
        uint256 tokensCollected;
        uint256 rewardEarned;
        uint256 comboCount;
        uint256 maxCombo;
        bool active;
        Tier tier;
    }
    
    struct TokenRarity {
        uint256 multiplier;
        uint256 spawnChance;
        bool active;
    }
    
    struct FeeConfig {
        uint256 purchaseFeePercent;
        uint256 withdrawFeePercent;
        uint256 protocolFeePercent;
        bool feesActive;
    }
    
    mapping(uint256 => TierConfig) public tiers;
    mapping(uint256 => MarketplaceItem) public items;
    mapping(uint256 => TokenRarity) public rarities;
    mapping(address => PlayerStats) public players;
    mapping(address => mapping(uint256 => uint256)) public itemExpiry;
    mapping(address => mapping(uint256 => uint256)) public itemPurchaseCount;
    mapping(bytes32 => GameSession) public sessions;
    mapping(address => bytes32) public activeSession;
    
    uint256 public nextItemId;
    uint256 public totalPlayersEver;
    uint256 public totalGamesPlayed;
    uint256 public totalRewardsDistributed;
    uint256 public foxDragonItemId;
    
    FeeConfig public fees;
    uint256 public comboBonus = 10;
    uint256 public minGameTime = 10;
    uint256 public maxGameTime = 3600;
    uint256 public minWithdraw = 100 * 10**18;
    uint256 public norxPriceUSD = 4 * 10**16;
    uint256 public bnbPriceUSD = 650 * 10**18;
    
    bool public gameActive = true;
    
    event GameStarted(address indexed player, bytes32 sessionId, Tier tier);
    event TokenCollected(address indexed player, uint256 reward);
    event GameEnded(address indexed player, uint256 totalReward);
    event Withdrawn(address indexed player, uint256 amount, uint256 fee);
    event ItemPurchased(address indexed player, uint256 itemId, PaymentMethod method, uint256 price);
    event NORXPurchased(address indexed buyer, uint256 amount, PaymentMethod method);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier nonReentrant() {
        _guard++;
        uint256 g = _guard;
        _;
        require(g == _guard);
    }
    
    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }
    
    constructor(address _usdt) {
        require(_usdt != address(0));
        owner = ADMIN;
        norxToken = IERC20(NORX_TOKEN);
        usdtToken = IERC20(_usdt);
        fees = FeeConfig(2, 1, 5, true);
        
        _initTiers();
        _initRarities();
        _initItems();
    }
    
    function _initTiers() private {
        tiers[0] = TierConfig(0, 10000000000, 100000000000000, true);
        tiers[1] = TierConfig(100000*10**18, 1000000000000, 100000000000000000, true);
        tiers[2] = TierConfig(500000*10**18, 5000000000000, 500000000000000000, true);
        tiers[3] = TierConfig(1000000*10**18, 10000000000000, 1000000000000000000, true);
        tiers[4] = TierConfig(3000000*10**18, 30000000000000, 3000000000000000000, true);
        tiers[5] = TierConfig(5000000*10**18, 50000000000000, 10000000000000000000, true);
    }
    
    function _initRarities() private {
        rarities[0] = TokenRarity(1, 7000, true);
        rarities[1] = TokenRarity(2, 2000, true);
        rarities[2] = TokenRarity(5, 800, true);
        rarities[3] = TokenRarity(10, 190, true);
        rarities[4] = TokenRarity(50, 10, true);
    }
    
    function _initItems() private {
        items[nextItemId++] = MarketplaceItem(100000000000000000,3000000000000000,2000000000000000000,24,true,true,true,true,Tier.Bronze,0,0);
        items[nextItemId++] = MarketplaceItem(50000000000000000,1500000000000000,1000000000000000000,24,true,true,true,true,Tier.Iniciante,0,0);
        items[nextItemId++] = MarketplaceItem(500000000000000000,7500000000000000,5000000000000000000,24,true,true,true,true,Tier.Prata,0,0);
        items[nextItemId++] = MarketplaceItem(1000000000000000000,15000000000000000,10000000000000000000,24,true,true,true,true,Tier.Ouro,0,0);
        items[nextItemId++] = MarketplaceItem(2000000000000000000,30000000000000000,20000000000000000000,24,true,true,true,true,Tier.Platina,0,0);
        items[nextItemId++] = MarketplaceItem(5000000000000000000,75000000000000000,50000000000000000000,24,true,true,true,true,Tier.Diamante,0,0);
        items[nextItemId++] = MarketplaceItem(3000000000000000000,45000000000000000,30000000000000000000,24,true,true,true,true,Tier.Platina,0,0);
        items[nextItemId++] = MarketplaceItem(1000000000000000000,3000000000000000,2000000000000000000,0,true,true,true,true,Tier.Bronze,0,0);
        items[nextItemId++] = MarketplaceItem(5000000000000000000,15000000000000000,10000000000000000000,0,true,true,true,true,Tier.Prata,0,0);
        items[nextItemId++] = MarketplaceItem(10000000000000000000,30000000000000000,20000000000000000000,0,true,true,true,true,Tier.Ouro,0,0);
        items[nextItemId++] = MarketplaceItem(25000000000000000000,75000000000000000,50000000000000000000,0,true,true,true,true,Tier.Platina,0,0);
        items[nextItemId++] = MarketplaceItem(50000000000000000000,150000000000000000,100000000000000000000,0,true,true,true,true,Tier.Diamante,0,0);
        items[nextItemId++] = MarketplaceItem(100000000000000000000,300000000000000000,200000000000000000000,0,true,true,true,true,Tier.Diamante,100,0);
        foxDragonItemId = nextItemId++;
        items[foxDragonItemId] = MarketplaceItem(0,1000000000000000000,650000000000000000000,0,true,false,true,true,Tier.Iniciante,0,0);
    }
    
    function startGame() external nonReentrant whenNotPaused returns (bytes32) {
        require(gameActive && activeSession[msg.sender] == bytes32(0));
        
        Tier t = getTier(msg.sender);
        bytes32 sid = keccak256(abi.encodePacked(msg.sender, block.timestamp, totalGamesPlayed));
        
        sessions[sid] = GameSession(msg.sender, block.timestamp, 0, 0, 0, 0, true, t);
        activeSession[msg.sender] = sid;
        
        PlayerStats storage p = players[msg.sender];
        if (p.lastMiningTime == 0) totalPlayersEver++;
        p.gamesPlayed++;
        p.currentTier = t;
        totalGamesPlayed++;
        
        emit GameStarted(msg.sender, sid, t);
        return sid;
    }
    
    function collectToken(bytes32 sid, uint256 tType, uint256 combo) external nonReentrant whenNotPaused {
        GameSession storage s = sessions[sid];
        require(s.active && s.player == msg.sender);
        require(block.timestamp - s.startTime <= maxGameTime);
        require(rarities[tType].active);
        
        PlayerStats storage p = players[msg.sender];
        _resetDaily(p);
        
        TierConfig memory tc = tiers[uint256(s.tier)];
        require(tc.active);
        
        uint256 r = tc.rewardPerToken * rarities[tType].multiplier * (100 + (combo/10)*comboBonus) / 100;
        
        if (p.todayMined + r > tc.dailyLimit) {
            r = tc.dailyLimit > p.todayMined ? tc.dailyLimit - p.todayMined : 0;
        }
        
        if (r > 0) {
            s.tokensCollected++;
            s.rewardEarned += r;
            s.comboCount = combo;
            if (combo > s.maxCombo) s.maxCombo = combo;
            p.todayMined += r;
            p.lastMiningTime = block.timestamp;
        }
        
        emit TokenCollected(msg.sender, r);
    }
    
    function endGame(bytes32 sid, uint256 score) external nonReentrant {
        GameSession storage s = sessions[sid];
        require(s.active && s.player == msg.sender);
        require(block.timestamp - s.startTime >= minGameTime);
        
        s.active = false;
        activeSession[msg.sender] = bytes32(0);
        
        PlayerStats storage p = players[msg.sender];
        if (score > p.highScore) p.highScore = score;
        
        uint256 r = s.rewardEarned;
        if (fees.feesActive && fees.protocolFeePercent > 0) {
            r -= (r * fees.protocolFeePercent) / 100;
        }
        
        p.norxMinedBalance += r;
        p.totalMined += s.rewardEarned;
        
        emit GameEnded(msg.sender, r);
    }
    
    function withdraw(uint256 amt) external payable nonReentrant {
        PlayerStats storage p = players[msg.sender];
        require(amt >= minWithdraw && p.norxMinedBalance >= amt);
        
        uint256 f = 0;
        if (fees.feesActive && fees.withdrawFeePercent > 0) {
            f = (amt * norxPriceUSD * fees.withdrawFeePercent) / (bnbPriceUSD * 100);
            require(msg.value >= f);
            if (f > 0) payable(TREASURY).transfer(f);
            if (msg.value > f) payable(msg.sender).transfer(msg.value - f);
        }
        
        p.norxMinedBalance -= amt;
        require(norxToken.transfer(msg.sender, amt));
        totalRewardsDistributed += amt;
        
        emit Withdrawn(msg.sender, amt, f);
    }
    
    function buyWithNorx(uint256 id) external payable nonReentrant whenNotPaused {
        MarketplaceItem storage it = items[id];
        require(it.isActive && it.acceptsNORX && id < nextItemId);
        require(getTier(msg.sender) >= it.minTier);
        if (it.maxPurchases > 0) require(itemPurchaseCount[msg.sender][id] < it.maxPurchases);
        
        uint256 p = it.priceNORX;
        require(p > 0 && players[msg.sender].norxMinedBalance >= p);
        
        players[msg.sender].norxMinedBalance -= p;
        _chargeFeeBNB(p);
        _finalize(id, it);
        
        emit ItemPurchased(msg.sender, id, PaymentMethod.NORX_MINERADO, p);
    }
    
    function buyWithBNB(uint256 id) external payable nonReentrant whenNotPaused {
        MarketplaceItem storage it = items[id];
        require(it.isActive && it.acceptsBNB && id < nextItemId);
        require(getTier(msg.sender) >= it.minTier);
        if (it.maxPurchases > 0) require(itemPurchaseCount[msg.sender][id] < it.maxPurchases);
        
        uint256 p = it.priceBNB;
        require(p > 0);
        
        uint256 f = fees.feesActive ? (p * fees.purchaseFeePercent) / 100 : 0;
        require(msg.value >= p + f);
        
        payable(TREASURY).transfer(p);
        if (f > 0) payable(TREASURY).transfer(f);
        if (msg.value > p + f) payable(msg.sender).transfer(msg.value - p - f);
        
        _finalize(id, it);
        
        emit ItemPurchased(msg.sender, id, PaymentMethod.BNB, p);
    }
    
    function buyWithUSDT(uint256 id, uint256 maxAmt) external payable nonReentrant whenNotPaused {
        MarketplaceItem storage it = items[id];
        require(it.isActive && it.acceptsUSDT && id < nextItemId);
        require(getTier(msg.sender) >= it.minTier);
        if (it.maxPurchases > 0) require(itemPurchaseCount[msg.sender][id] < it.maxPurchases);
        
        uint256 p = it.priceUSDT;
        require(p > 0 && maxAmt >= p);
        require(usdtToken.allowance(msg.sender, address(this)) >= p, "Approve USDT");
        require(usdtToken.transferFrom(msg.sender, TREASURY, p));
        
        _chargeFeeBNB(p);
        _finalize(id, it);
        
        emit ItemPurchased(msg.sender, id, PaymentMethod.USDT, p);
    }
    
    function buyNorxBNB(uint256 amt) external payable nonReentrant whenNotPaused {
        require(amt > 0);
        uint256 p = (amt * norxPriceUSD / 10**18) * 10**18 / bnbPriceUSD;
        require(msg.value >= p);
        
        payable(TREASURY).transfer(p);
        if (msg.value > p) payable(msg.sender).transfer(msg.value - p);
        require(norxToken.transfer(msg.sender, amt));
        
        emit NORXPurchased(msg.sender, amt, PaymentMethod.BNB);
    }
    
    function buyNorxUSDT(uint256 amt) external nonReentrant whenNotPaused {
        require(amt > 0);
        uint256 p = (amt * norxPriceUSD) / 10**18;
        require(usdtToken.allowance(msg.sender, address(this)) >= p, "Approve USDT");
        require(usdtToken.transferFrom(msg.sender, TREASURY, p));
        require(norxToken.transfer(msg.sender, amt));
        
        emit NORXPurchased(msg.sender, amt, PaymentMethod.USDT);
    }
    
    function _chargeFeeBNB(uint256 baseAmt) private {
        if (!fees.feesActive || fees.purchaseFeePercent == 0) return;
        
        uint256 f = (baseAmt * norxPriceUSD * fees.purchaseFeePercent) / (bnbPriceUSD * 100);
        require(msg.value >= f);
        if (f > 0) payable(TREASURY).transfer(f);
        if (msg.value > f) payable(msg.sender).transfer(msg.value - f);
    }
    
    function _finalize(uint256 id, MarketplaceItem storage it) private {
        players[msg.sender].ownedItems[id] = true;
        itemPurchaseCount[msg.sender][id]++;
        it.totalPurchased++;
        if (it.durationHours > 0) {
            itemExpiry[msg.sender][id] = block.timestamp + (it.durationHours * 1 hours);
        }
    }
    
    function _resetDaily(PlayerStats storage p) private {
        uint256 cd = block.timestamp / 1 days;
        uint256 ld = p.lastDailyReset / 1 days;
        if (cd > ld) {
            p.todayMined = 0;
            p.lastDailyReset = block.timestamp;
        }
    }
    
    function getTier(address a) public view returns (Tier) {
        uint256 b = norxToken.balanceOf(a);
        if (tiers[5].active && b >= tiers[5].minBalance) return Tier.Diamante;
        if (tiers[4].active && b >= tiers[4].minBalance) return Tier.Platina;
        if (tiers[3].active && b >= tiers[3].minBalance) return Tier.Ouro;
        if (tiers[2].active && b >= tiers[2].minBalance) return Tier.Prata;
        if (tiers[1].active && b >= tiers[1].minBalance) return Tier.Bronze;
        return Tier.Iniciante;
    }
    
    function getStats(address a) external view returns (uint256 mined, uint256 wallet, uint256 total, uint256 today, uint256 games, uint256 score, Tier t) {
        PlayerStats storage p = players[a];
        return (p.norxMinedBalance, norxToken.balanceOf(a), p.totalMined, p.todayMined, p.gamesPlayed, p.highScore, getTier(a));
    }
    
    function calcWithdrawFee(uint256 amt) external view returns (uint256) {
        if (!fees.feesActive || fees.withdrawFeePercent == 0) return 0;
        return (amt * norxPriceUSD * fees.withdrawFeePercent) / (bnbPriceUSD * 100);
    }
    
    function checkUSDTAllowance(address u) external view returns (uint256) {
        return usdtToken.allowance(u, address(this));
    }
    
    function depositNORX(uint256 amt) external onlyOwner {
        require(norxToken.transferFrom(msg.sender, address(this), amt));
    }
    
    function updateFees(uint256 p, uint256 w, uint256 pr, bool a) external onlyOwner {
        require(p <= 10 && w <= 10 && pr <= 20);
        fees = FeeConfig(p, w, pr, a);
    }
    
    function updateMinWithdraw(uint256 m) external onlyOwner { minWithdraw = m; }
    function updateNorxPrice(uint256 p) external onlyOwner { norxPriceUSD = p; }
    function updateBnbPrice(uint256 p) external onlyOwner { bnbPriceUSD = p; }
    function setActive(bool a) external onlyOwner { gameActive = a; }
    function setPaused(bool p) external onlyOwner { paused = p; }
    
    function updateTier(uint256 id, uint256 mb, uint256 rpt, uint256 dl) external onlyOwner {
        require(id <= 5);
        tiers[id] = TierConfig(mb, rpt, dl, true);
    }
    
    function updateItem(uint256 id, uint256 pn, uint256 pb, uint256 pu) external onlyOwner {
        require(id < nextItemId);
        items[id].priceNORX = pn;
        items[id].priceBNB = pb;
        items[id].priceUSDT = pu;
    }
    
    function withdrawBNB(uint256 a) external onlyOwner { payable(TREASURY).transfer(a); }
    function withdrawUSDT(uint256 a) external onlyOwner { require(usdtToken.transfer(TREASURY, a)); }
    function withdrawNORX(uint256 a) external onlyOwner { require(norxToken.transfer(TREASURY, a)); }
    function transferOwnership(address n) external onlyOwner { require(n != address(0)); owner = n; }
    
    receive() external payable {}

    function addNewItem(
    uint256 pn, 
    uint256 pb, 
    uint256 pu, 
    uint256 duration, 
    Tier minTier, 
    uint256 maxP
) external onlyOwner {
    items[nextItemId++] = MarketplaceItem(
        pn,      // Preço em NORX
        pb,      // Preço em BNB
        pu,      // Preço em USDT
        duration,// Duração em Horas (0 = Vitalício)
        true,    // isActive
        true,    // acceptsNORX
        true,    // acceptsBNB
        true,    // acceptsUSDT
        minTier, // Tier Mínimo necessário
        maxP,    // Máximo de compras (0 = Ilimitado)
        0        // totalPurchased inicial
    );
}
}
