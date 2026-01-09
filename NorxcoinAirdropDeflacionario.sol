// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function burn(uint256 amount) external;
}

contract NorxcoinAirdropDeflacionario {
    IERC20 public immutable norxToken;
    address public owner;
    
    // Configurações do Airdrop
    uint256 public constant MAX_TOKENS_PER_USER = 140 * 10**18; // 140 tokens
    uint256 public constant BURN_MULTIPLIER = 10; // Queima 10x o que distribui
    uint256 public constant TOTAL_AIRDROP_SUPPLY = 1_000_000 * 10**18; // 1M tokens
    uint256 public constant TOTAL_APPROVED_SUPPLY = 11_000_000 * 10**18; // 11M tokens
    
    // Pontuações das tarefas
    uint256 public constant TWITTER_FOLLOW = 15 * 10**18;
    uint256 public constant TELEGRAM_JOIN = 15 * 10**18;
    uint256 public constant INSTAGRAM_FOLLOW = 15 * 10**18;
    uint256 public constant YOUTUBE_SUBSCRIBE = 15 * 10**18;
    uint256 public constant TWITTER_LIKE_BONUS = 5 * 10**18;
    uint256 public constant TWITTER_RETWEET_BONUS = 20 * 10**18;
    uint256 public constant REFERRAL_BONUS = 55 * 10**18;
    
    // Estado do airdrop
    uint256 public totalDistributed;
    uint256 public totalBurned;
    uint256 public totalParticipants;
    bool public airdropActive = true;
    
    // Mapeamentos
    mapping(address => uint256) public userTokens; // Tokens acumulados por usuário
    mapping(address => bool) public hasClaimed; // Se usuário já fez claim
    mapping(address => UserTasks) public userTasks; // Tarefas completadas
    
    struct UserTasks {
        bool twitterFollow;
        bool telegramJoin;
        bool instagramFollow;
        bool youtubeSubscribe;
        bool twitterLike;
        bool twitterRetweet;
        uint8 referralsCompleted; // Máximo 5 referrals
    }
    
    // Eventos
    event TaskCompleted(address indexed user, string task, uint256 tokensEarned);
    event TokensClaimed(address indexed user, uint256 tokensReceived, uint256 tokensBurned);
    event AirdropStatusChanged(bool active);
    event EmergencyWithdraw(uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Apenas o owner pode executar");
        _;
    }
    
    modifier airdropIsActive() {
        require(airdropActive, "Airdrop nao esta ativo");
        _;
    }
    
    constructor() {
        norxToken = IERC20(0x9F8ace87A43851aCc21B6a00A84b4F9088563179);
        owner = 0x797Eb3b6fDfc4f96512eC0061E4D5242FbDED434;
    }
    
    // ============================
    // FUNÇÕES DE TAREFAS
    // ============================
    
    function completeTwitterFollow(address user) external onlyOwner airdropIsActive {
        require(!userTasks[user].twitterFollow, "Tarefa ja completada");
        require(userTokens[user] + TWITTER_FOLLOW <= MAX_TOKENS_PER_USER, "Limite de tokens excedido");
        
        userTasks[user].twitterFollow = true;
        userTokens[user] += TWITTER_FOLLOW;
        
        emit TaskCompleted(user, "TwitterFollow", TWITTER_FOLLOW);
    }
    
    function completeTelegramJoin(address user) external onlyOwner airdropIsActive {
        require(!userTasks[user].telegramJoin, "Tarefa ja completada");
        require(userTokens[user] + TELEGRAM_JOIN <= MAX_TOKENS_PER_USER, "Limite de tokens excedido");
        
        userTasks[user].telegramJoin = true;
        userTokens[user] += TELEGRAM_JOIN;
        
        emit TaskCompleted(user, "TelegramJoin", TELEGRAM_JOIN);
    }
    
    function completeInstagramFollow(address user) external onlyOwner airdropIsActive {
        require(!userTasks[user].instagramFollow, "Tarefa ja completada");
        require(userTokens[user] + INSTAGRAM_FOLLOW <= MAX_TOKENS_PER_USER, "Limite de tokens excedido");
        
        userTasks[user].instagramFollow = true;
        userTokens[user] += INSTAGRAM_FOLLOW;
        
        emit TaskCompleted(user, "InstagramFollow", INSTAGRAM_FOLLOW);
    }
    
    function completeYouTubeSubscribe(address user) external onlyOwner airdropIsActive {
        require(!userTasks[user].youtubeSubscribe, "Tarefa ja completada");
        require(userTokens[user] + YOUTUBE_SUBSCRIBE <= MAX_TOKENS_PER_USER, "Limite de tokens excedido");
        
        userTasks[user].youtubeSubscribe = true;
        userTokens[user] += YOUTUBE_SUBSCRIBE;
        
        emit TaskCompleted(user, "YouTubeSubscribe", YOUTUBE_SUBSCRIBE);
    }
    
    function completeTwitterLike(address user) external onlyOwner airdropIsActive {
        require(userTasks[user].twitterFollow, "Precisa seguir no Twitter primeiro");
        require(!userTasks[user].twitterLike, "Tarefa ja completada");
        require(userTokens[user] + TWITTER_LIKE_BONUS <= MAX_TOKENS_PER_USER, "Limite de tokens excedido");
        
        userTasks[user].twitterLike = true;
        userTokens[user] += TWITTER_LIKE_BONUS;
        
        emit TaskCompleted(user, "TwitterLike", TWITTER_LIKE_BONUS);
    }
    
    function completeTwitterRetweet(address user) external onlyOwner airdropIsActive {
        require(userTasks[user].twitterFollow, "Precisa seguir no Twitter primeiro");
        require(!userTasks[user].twitterRetweet, "Tarefa ja completada");
        require(userTokens[user] + TWITTER_RETWEET_BONUS <= MAX_TOKENS_PER_USER, "Limite de tokens excedido");
        
        userTasks[user].twitterRetweet = true;
        userTokens[user] += TWITTER_RETWEET_BONUS;
        
        emit TaskCompleted(user, "TwitterRetweet", TWITTER_RETWEET_BONUS);
    }
    
    function completeReferral(address user) external onlyOwner airdropIsActive {
        require(userTasks[user].referralsCompleted < 5, "Maximo de 5 referrals atingido");
        require(userTokens[user] + REFERRAL_BONUS <= MAX_TOKENS_PER_USER, "Limite de tokens excedido");
        
        userTasks[user].referralsCompleted++;
        userTokens[user] += REFERRAL_BONUS;
        
        emit TaskCompleted(user, "Referral", REFERRAL_BONUS);
    }
    
    // ============================
    // FUNÇÃO DE CLAIM (PRINCIPAL)
    // ============================
    
    function claimTokens() external airdropIsActive {
        address user = msg.sender;
        require(userTokens[user] > 0, "Nenhum token para reivindicar");
        require(!hasClaimed[user], "Tokens ja foram reivindicados");
        require(totalDistributed + userTokens[user] <= TOTAL_AIRDROP_SUPPLY, "Suprimento do airdrop esgotado");
        
        uint256 tokensToReceive = userTokens[user];
        uint256 tokensToBurn = tokensToReceive * BURN_MULTIPLIER;
        
        // Verificar se há tokens suficientes para queimar
        require(norxToken.balanceOf(address(this)) >= tokensToReceive + tokensToBurn, "Tokens insuficientes no contrato");
        
        // Marcar como claimed
        hasClaimed[user] = true;
        totalDistributed += tokensToReceive;
        totalBurned += tokensToBurn;
        totalParticipants++;
        
        // Transferir tokens para o usuário
        require(norxToken.transfer(user, tokensToReceive), "Falha na transferencia");
        
        // Queimar tokens (10x)
        norxToken.burn(tokensToBurn);
        
        emit TokensClaimed(user, tokensToReceive, tokensToBurn);
    }
    
    // ============================
    // FUNÇÕES ADMINISTRATIVAS
    // ============================
    
    function setAirdropStatus(bool _active) external onlyOwner {
        airdropActive = _active;
        emit AirdropStatusChanged(_active);
    }
    
    function emergencyWithdrawTokens() external onlyOwner {
        uint256 balance = norxToken.balanceOf(address(this));
        require(balance > 0, "Nenhum token para retirar");
        
        require(norxToken.transfer(owner, balance), "Falha na retirada");
        emit EmergencyWithdraw(balance);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Novo owner nao pode ser zero");
        owner = newOwner;
    }
    
    // ============================
    // FUNÇÕES DE CONSULTA
    // ============================
    
    function getUserInfo(address user) external view returns (
        uint256 tokensEarned,
        bool claimed,
        UserTasks memory tasks,
        uint256 maxTokens
    ) {
        return (
            userTokens[user],
            hasClaimed[user],
            userTasks[user],
            MAX_TOKENS_PER_USER
        );
    }
    
    function getAirdropStats() external view returns (
        uint256 _totalDistributed,
        uint256 _totalBurned,
        uint256 _totalParticipants,
        uint256 _remainingSupply,
        bool _active
    ) {
        return (
            totalDistributed,
            totalBurned,
            totalParticipants,
            TOTAL_AIRDROP_SUPPLY - totalDistributed,
            airdropActive
        );
    }
    
    function getContractBalance() external view returns (uint256) {
        return norxToken.balanceOf(address(this));
    }
    
    function calculateUserMaxTokens(address user) external view returns (uint256) {
        UserTasks memory tasks = userTasks[user];
        uint256 maxPossible = 0;
        
        // Tarefas básicas
        if (!tasks.twitterFollow) maxPossible += TWITTER_FOLLOW;
        if (!tasks.telegramJoin) maxPossible += TELEGRAM_JOIN;
        if (!tasks.instagramFollow) maxPossible += INSTAGRAM_FOLLOW;
        if (!tasks.youtubeSubscribe) maxPossible += YOUTUBE_SUBSCRIBE;
        
        // Bônus (dependem do Twitter Follow)
        if (tasks.twitterFollow) {
            if (!tasks.twitterLike) maxPossible += TWITTER_LIKE_BONUS;
            if (!tasks.twitterRetweet) maxPossible += TWITTER_RETWEET_BONUS;
        }
        
        // Referrals (máximo 5)
        uint256 remainingReferrals = 5 - tasks.referralsCompleted;
        maxPossible += remainingReferrals * REFERRAL_BONUS;
        
        return maxPossible;
    }
    
    // ============================
    // FUNÇÃO PARA MÚLTIPLAS TAREFAS
    // ============================
    
    function completeMultipleTasks(
        address user,
        bool _twitterFollow,
        bool _telegramJoin,
        bool _instagramFollow,
        bool _youtubeSubscribe,
        bool _twitterLike,
        bool _twitterRetweet,
        uint8 _referrals
    ) external onlyOwner airdropIsActive {
        require(_referrals <= 5, "Maximo 5 referrals");
        
        uint256 totalTokensToAdd = 0;
        
        // Calcular total de tokens que serão adicionados
        if (_twitterFollow && !userTasks[user].twitterFollow) {
            totalTokensToAdd += TWITTER_FOLLOW;
        }
        if (_telegramJoin && !userTasks[user].telegramJoin) {
            totalTokensToAdd += TELEGRAM_JOIN;
        }
        if (_instagramFollow && !userTasks[user].instagramFollow) {
            totalTokensToAdd += INSTAGRAM_FOLLOW;
        }
        if (_youtubeSubscribe && !userTasks[user].youtubeSubscribe) {
            totalTokensToAdd += YOUTUBE_SUBSCRIBE;
        }
        if (_twitterLike && !userTasks[user].twitterLike && (userTasks[user].twitterFollow || _twitterFollow)) {
            totalTokensToAdd += TWITTER_LIKE_BONUS;
        }
        if (_twitterRetweet && !userTasks[user].twitterRetweet && (userTasks[user].twitterFollow || _twitterFollow)) {
            totalTokensToAdd += TWITTER_RETWEET_BONUS;
        }
        
        uint8 newReferrals = _referrals - userTasks[user].referralsCompleted;
        if (newReferrals > 0) {
            totalTokensToAdd += newReferrals * REFERRAL_BONUS;
        }
        
        require(userTokens[user] + totalTokensToAdd <= MAX_TOKENS_PER_USER, "Limite de tokens excedido");
        
        // Aplicar mudanças
        if (_twitterFollow && !userTasks[user].twitterFollow) {
            userTasks[user].twitterFollow = true;
        }
        if (_telegramJoin && !userTasks[user].telegramJoin) {
            userTasks[user].telegramJoin = true;
        }
        if (_instagramFollow && !userTasks[user].instagramFollow) {
            userTasks[user].instagramFollow = true;
        }
        if (_youtubeSubscribe && !userTasks[user].youtubeSubscribe) {
            userTasks[user].youtubeSubscribe = true;
        }
        if (_twitterLike && !userTasks[user].twitterLike && userTasks[user].twitterFollow) {
            userTasks[user].twitterLike = true;
        }
        if (_twitterRetweet && !userTasks[user].twitterRetweet && userTasks[user].twitterFollow) {
            userTasks[user].twitterRetweet = true;
        }
        if (_referrals > userTasks[user].referralsCompleted) {
            userTasks[user].referralsCompleted = _referrals;
        }
        
        userTokens[user] += totalTokensToAdd;
        
        emit TaskCompleted(user, "MultipleTasks", totalTokensToAdd);
    }
}
