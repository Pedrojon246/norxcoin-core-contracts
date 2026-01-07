// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title NorxcoinStaking
 * @dev Contrato de staking para Norxcoin (NORX)
 * @custom:security-contact contato@norxcompany.com.br
 */
contract NorxcoinStaking is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Estrutura para armazenar informações de staking de cada usuário
    struct StakeInfo {
        uint256 amount;          // Quantidade total em stake
        uint256 rewardDebt;      // Dívida de recompensa - usado para calcular corretamente as recompensas
        uint256 lastStakeTime;   // Timestamp do último stake
        uint256 lastClaimTime;   // Timestamp da última reivindicação de recompensa
    }

    // Informações do pool de staking
    struct PoolInfo {
        uint256 totalStaked;         // Total de tokens em stake no pool
        uint256 rewardPerBlock;      // Recompensa por bloco
        uint256 accRewardPerShare;   // Recompensa acumulada por share
        uint256 lastUpdateBlock;     // Último bloco em que as recompensas foram atualizadas
        uint256 lockPeriod;          // Período de bloqueio em segundos (0 = sem bloqueio)
        bool paused;                 // Se o pool está pausado
    }

    // Permissões
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // Endereço do token NORX
    IERC20 public norxcoin;
    
    // Endereço da carteira de recompensas
    address public rewardsWallet;
    
    // ID do próximo pool
    uint256 public nextPoolId;
    
    // Mapeamento de pools
    mapping(uint256 => PoolInfo) public pools;
    
    // Mapeamento do stake de cada usuário em cada pool
    mapping(uint256 => mapping(address => StakeInfo)) public userStakes;
    
    // Eventos
    event Staked(address indexed user, uint256 indexed poolId, uint256 amount);
    event Unstaked(address indexed user, uint256 indexed poolId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 indexed poolId, uint256 reward);
    event PoolCreated(uint256 indexed poolId, uint256 rewardPerBlock, uint256 lockPeriod);
    event PoolUpdated(uint256 indexed poolId, uint256 rewardPerBlock, uint256 lockPeriod);
    event PoolPaused(uint256 indexed poolId);
    event PoolResumed(uint256 indexed poolId);

    /**
     * @dev Construtor do contrato de staking
     * @param _norxcoinAddress Endereço do contrato Norxcoin
     * @param _rewardsWallet Endereço da carteira de recompensas
     */
    constructor(
        address _norxcoinAddress,
        address _rewardsWallet
    ) {
        require(_norxcoinAddress != address(0), "Token address cannot be zero");
        require(_rewardsWallet != address(0), "Rewards wallet cannot be zero");
        
        norxcoin = IERC20(_norxcoinAddress);
        rewardsWallet = _rewardsWallet;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev Atualiza o endereço da carteira de recompensas
     * @param _newRewardsWallet Novo endereço da carteira de recompensas
     */
    function updateRewardsWallet(address _newRewardsWallet) external onlyRole(ADMIN_ROLE) {
        require(_newRewardsWallet != address(0), "New rewards wallet cannot be zero");
        rewardsWallet = _newRewardsWallet;
    }

    /**
     * @dev Cria um novo pool de staking
     * @param _rewardPerBlock Recompensa por bloco
     * @param _lockPeriod Período de bloqueio em segundos (0 = sem bloqueio)
     * @return poolId ID do pool criado
     */
    function createPool(
        uint256 _rewardPerBlock,
        uint256 _lockPeriod
    ) external onlyRole(MANAGER_ROLE) returns (uint256 poolId) {
        poolId = nextPoolId++;
        
        pools[poolId] = PoolInfo({
            totalStaked: 0,
            rewardPerBlock: _rewardPerBlock,
            accRewardPerShare: 0,
            lastUpdateBlock: block.number,
            lockPeriod: _lockPeriod,
            paused: false
        });
        
        emit PoolCreated(poolId, _rewardPerBlock, _lockPeriod);
        return poolId;
    }

    /**
     * @dev Atualiza um pool de staking existente
     * @param _poolId ID do pool
     * @param _rewardPerBlock Nova recompensa por bloco
     * @param _lockPeriod Novo período de bloqueio
     */
    function updatePool(
        uint256 _poolId,
        uint256 _rewardPerBlock,
        uint256 _lockPeriod
    ) external onlyRole(MANAGER_ROLE) {
        require(_poolId < nextPoolId, "Pool does not exist");
        
        PoolInfo storage pool = pools[_poolId];
        
        // Atualiza as recompensas acumuladas antes de modificar a taxa de recompensa
        updatePoolRewards(_poolId);
        
        pool.rewardPerBlock = _rewardPerBlock;
        pool.lockPeriod = _lockPeriod;
        
        emit PoolUpdated(_poolId, _rewardPerBlock, _lockPeriod);
    }

    /**
     * @dev Pausa um pool de staking (novos stakes são bloqueados)
     * @param _poolId ID do pool
     */
    function pausePool(uint256 _poolId) external onlyRole(ADMIN_ROLE) {
        require(_poolId < nextPoolId, "Pool does not exist");
        require(!pools[_poolId].paused, "Pool already paused");
        
        // Atualiza as recompensas acumuladas antes de pausar
        updatePoolRewards(_poolId);
        
        pools[_poolId].paused = true;
        
        emit PoolPaused(_poolId);
    }

    /**
     * @dev Retoma um pool de staking pausado
     * @param _poolId ID do pool
     */
    function resumePool(uint256 _poolId) external onlyRole(ADMIN_ROLE) {
        require(_poolId < nextPoolId, "Pool does not exist");
        require(pools[_poolId].paused, "Pool not paused");
        
        pools[_poolId].paused = false;
        pools[_poolId].lastUpdateBlock = block.number;
        
        emit PoolResumed(_poolId);
    }

    /**
     * @dev Atualiza as recompensas acumuladas de um pool
     * @param _poolId ID do pool
     */
    function updatePoolRewards(uint256 _poolId) public {
        require(_poolId < nextPoolId, "Pool does not exist");
        
        PoolInfo storage pool = pools[_poolId];
        
        if (pool.totalStaked == 0 || pool.paused) {
            pool.lastUpdateBlock = block.number;
            return;
        }
        
        uint256 blocksSinceLastUpdate = block.number.sub(pool.lastUpdateBlock);
        if (blocksSinceLastUpdate > 0) {
            uint256 reward = blocksSinceLastUpdate.mul(pool.rewardPerBlock);
            pool.accRewardPerShare = pool.accRewardPerShare.add(
                reward.mul(1e12).div(pool.totalStaked)
            );
            pool.lastUpdateBlock = block.number;
        }
    }

    /**
     * @dev Realiza stake de tokens NORX em um pool
     * @param _poolId ID do pool
     * @param _amount Quantidade de tokens para stake
     */
    function stake(uint256 _poolId, uint256 _amount) external nonReentrant {
        require(_poolId < nextPoolId, "Pool does not exist");
        require(_amount > 0, "Cannot stake 0 tokens");
        
        PoolInfo storage pool = pools[_poolId];
        require(!pool.paused, "Pool is paused");
        
        // Atualiza as recompensas do pool
        updatePoolRewards(_poolId);
        
        // Transfere tokens do usuário para o contrato
        norxcoin.safeTransferFrom(msg.sender, address(this), _amount);
        
        StakeInfo storage userStake = userStakes[_poolId][msg.sender];
        
        // Se o usuário já tem stake, calcula as recompensas pendentes
        if (userStake.amount > 0) {
            uint256 pending = userStake.amount.mul(pool.accRewardPerShare).div(1e12).sub(userStake.rewardDebt);
            if (pending > 0) {
                // Registra as recompensas pendentes
                userStake.rewardDebt = userStake.rewardDebt.add(pending);
            }
        }
        
        // Atualiza o stake do usuário
        userStake.amount = userStake.amount.add(_amount);
        userStake.rewardDebt = userStake.amount.mul(pool.accRewardPerShare).div(1e12);
        userStake.lastStakeTime = block.timestamp;
        
        // Atualiza o total de tokens em stake no pool
        pool.totalStaked = pool.totalStaked.add(_amount);
        
        emit Staked(msg.sender, _poolId, _amount);
    }

    /**
     * @dev Remove tokens do stake
     * @param _poolId ID do pool
     * @param _amount Quantidade de tokens para remover
     */
    function unstake(uint256 _poolId, uint256 _amount) external nonReentrant {
        require(_poolId < nextPoolId, "Pool does not exist");
        require(_amount > 0, "Cannot unstake 0 tokens");
        
        PoolInfo storage pool = pools[_poolId];
        StakeInfo storage userStake = userStakes[_poolId][msg.sender];
        
        require(userStake.amount >= _amount, "Insufficient staked amount");
        
        // Verifica o período de bloqueio
        if (pool.lockPeriod > 0) {
            require(
                block.timestamp >= userStake.lastStakeTime.add(pool.lockPeriod),
                "Tokens still locked"
            );
        }
        
        // Atualiza as recompensas do pool
        updatePoolRewards(_poolId);
        
        // Calcula recompensas pendentes
        uint256 pending = userStake.amount.mul(pool.accRewardPerShare).div(1e12).sub(userStake.rewardDebt);
        
        // Atualiza o stake do usuário
        userStake.amount = userStake.amount.sub(_amount);
        userStake.rewardDebt = userStake.amount.mul(pool.accRewardPerShare).div(1e12);
        
        // Atualiza o total de tokens em stake no pool
        pool.totalStaked = pool.totalStaked.sub(_amount);
        
        // Transfere tokens e recompensas para o usuário
        norxcoin.safeTransfer(msg.sender, _amount);
        
        // Se há recompensas pendentes, transfere-as também
        if (pending > 0) {
            norxcoin.safeTransferFrom(rewardsWallet, msg.sender, pending);
            userStake.lastClaimTime = block.timestamp;
            emit RewardClaimed(msg.sender, _poolId, pending);
        }
        
        emit Unstaked(msg.sender, _poolId, _amount);
    }

    /**
     * @dev Reivindicar recompensas sem remover o stake
     * @param _poolId ID do pool
     */
    function claimRewards(uint256 _poolId) external nonReentrant {
        require(_poolId < nextPoolId, "Pool does not exist");
        
        PoolInfo storage pool = pools[_poolId];
        StakeInfo storage userStake = userStakes[_poolId][msg.sender];
        
        require(userStake.amount > 0, "No staked tokens");
        
        // Atualiza as recompensas do pool
        updatePoolRewards(_poolId);
        
        // Calcula recompensas pendentes
        uint256 pending = userStake.amount.mul(pool.accRewardPerShare).div(1e12).sub(userStake.rewardDebt);
        require(pending > 0, "No rewards to claim");
        
        // Atualiza a dívida de recompensa
        userStake.rewardDebt = userStake.amount.mul(pool.accRewardPerShare).div(1e12);
        userStake.lastClaimTime = block.timestamp;
        
        // Transfere recompensas para o usuário
        norxcoin.safeTransferFrom(rewardsWallet, msg.sender, pending);
        
        emit RewardClaimed(msg.sender, _poolId, pending);
    }

    /**
     * @dev Retorna informações de stake e recompensas pendentes de um usuário
     * @param _poolId ID do pool
     * @param _user Endereço do usuário
     * @return stakedAmount Quantidade em stake
     * @return pendingRewards Recompensas pendentes
     * @return stakeTime Tempo do último stake
     * @return lockEndTime Tempo de término do bloqueio (0 se já desbloqueado)
     */
    function getUserStakeInfo(uint256 _poolId, address _user) external view returns (
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 stakeTime,
        uint256 lockEndTime
    ) {
        require(_poolId < nextPoolId, "Pool does not exist");
        
        PoolInfo storage pool = pools[_poolId];
        StakeInfo storage userStake = userStakes[_poolId][_user];
        
        stakedAmount = userStake.amount;
        stakeTime = userStake.lastStakeTime;
        
        // Calcula o tempo de término do bloqueio
        if (pool.lockPeriod > 0 && block.timestamp < userStake.lastStakeTime.add(pool.lockPeriod)) {
            lockEndTime = userStake.lastStakeTime.add(pool.lockPeriod);
        } else {
            lockEndTime = 0; // Já desbloqueado
        }
        
        // Calcula recompensas pendentes
        if (stakedAmount > 0 && pool.totalStaked > 0) {
            uint256 currentAccRewardPerShare = pool.accRewardPerShare;
            
            if (!pool.paused && block.number > pool.lastUpdateBlock) {
                uint256 blocksSinceLastUpdate = block.number.sub(pool.lastUpdateBlock);
                uint256 reward = blocksSinceLastUpdate.mul(pool.rewardPerBlock);
                currentAccRewardPerShare = currentAccRewardPerShare.add(
                    reward.mul(1e12).div(pool.totalStaked)
                );
            }
            
            pendingRewards = stakedAmount.mul(currentAccRewardPerShare).div(1e12).sub(userStake.rewardDebt);
        } else {
            pendingRewards = 0;
        }
        
        return (stakedAmount, pendingRewards, stakeTime, lockEndTime);
    }

    /**
     * @dev Obtém estatísticas gerais de um pool
     * @param _poolId ID do pool
     */
    function getPoolStats(uint256 _poolId) external view returns (
        uint256 totalStaked,
        uint256 rewardPerBlock,
        uint256 lockPeriod,
        bool isPaused,
        uint256 apr
    ) {
        require(_poolId < nextPoolId, "Pool does not exist");
        
        PoolInfo storage pool = pools[_poolId];
        
        totalStaked = pool.totalStaked;
        rewardPerBlock = pool.rewardPerBlock;
        lockPeriod = pool.lockPeriod;
        isPaused = pool.paused;
        
        // Calcula APR aproximado (Blocos por ano * recompensa por bloco / total em stake * 100)
        // Média de ~20 segundos por bloco na BSC = ~1,576,800 blocos por ano
        if (totalStaked > 0) {
            apr = 1576800 * rewardPerBlock * 100 / totalStaked;
        } else {
            apr = 0;
        }
        
        return (totalStaked, rewardPerBlock, lockPeriod, isPaused, apr);
    }

    /**
     * @dev Emergência: permite ao admin resgatar tokens enviados por acidente para o contrato
     * @param _token Endereço do token
     * @param _amount Quantidade a resgatar
     */
    function rescueTokens(address _token, uint256 _amount) external onlyRole(ADMIN_ROLE) {
        require(_token != address(norxcoin), "Cannot rescue staked tokens");
        
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }
}
