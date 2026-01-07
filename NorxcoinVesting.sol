// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title NorxcoinVesting
 * @dev Contrato para o vesting dos tokens da equipe Norx
 * @custom:security-contact contato@norxcompany.com.br
 */
contract NorxcoinVesting is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public norxcoin;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct VestingSchedule {
        uint256 totalAmount;          // Quantidade total de tokens para vesting
        uint256 releasedAmount;       // Quantidade já liberada
        uint256 startTime;            // Timestamp de início do vesting
        uint256 duration;             // Duração total em segundos (12 meses)
        uint256 releaseInterval;      // Intervalo de liberação (3 meses)
        uint256 releasePerInterval;   // Porcentagem liberada por intervalo (25%)
        bool isActive;                // Se o vesting está ativo
    }

    mapping(address => VestingSchedule) public vestingSchedules;
    address[] public beneficiaries;

    event VestingScheduleCreated(address indexed beneficiary, uint256 totalAmount);
    event VestingScheduleRevoked(address indexed beneficiary, uint256 remainingAmount);
    event TokensReleased(address indexed beneficiary, uint256 amount);

    /**
     * @dev Construtor do contrato de vesting
     * @param _norxcoinAddress Endereço do contrato Norxcoin
     */
    constructor(address _norxcoinAddress) {
        require(_norxcoinAddress != address(0), "Token address cannot be zero");
        norxcoin = IERC20(_norxcoinAddress);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Cria um cronograma de vesting para um beneficiário
     * @param _beneficiary Endereço do beneficiário
     * @param _totalAmount Quantidade total de tokens para vesting
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount
    ) external onlyRole(ADMIN_ROLE) {
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_totalAmount > 0, "Vesting amount must be greater than zero");
        require(!vestingSchedules[_beneficiary].isActive, "Vesting schedule already exists");

        // 12 meses de vesting com liberação a cada 3 meses (25% por vez)
        uint256 startTime = block.timestamp;
        uint256 duration = 365 days; // 12 meses
        uint256 releaseInterval = 90 days; // 3 meses
        uint256 releasePerInterval = 25; // 25% por intervalo

        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _totalAmount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            releaseInterval: releaseInterval,
            releasePerInterval: releasePerInterval,
            isActive: true
        });

        beneficiaries.push(_beneficiary);
        
        emit VestingScheduleCreated(_beneficiary, _totalAmount);
    }

    /**
     * @dev Calcula quanto um beneficiário pode sacar no momento
     * @param _beneficiary Endereço do beneficiário
     * @return Quantidade disponível para saque
     */
    function calculateReleasableAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        
        if (!schedule.isActive || block.timestamp < schedule.startTime) {
            return 0;
        }

        // Calcula quantos intervalos de liberação se passaram
        uint256 elapsedTime = block.timestamp.sub(schedule.startTime);
        
        if (elapsedTime >= schedule.duration) {
            // Vesting completo
            return schedule.totalAmount.sub(schedule.releasedAmount);
        }

        uint256 intervals = elapsedTime.div(schedule.releaseInterval).add(1);
        uint256 vestedPercentage = intervals.mul(schedule.releasePerInterval);
        
        if (vestedPercentage > 100) {
            vestedPercentage = 100;
        }

        uint256 vestedAmount = schedule.totalAmount.mul(vestedPercentage).div(100);
        uint256 releasableAmount = vestedAmount.sub(schedule.releasedAmount);
        
        return releasableAmount;
    }

    /**
     * @dev Permite que um beneficiário saque seus tokens de acordo com o cronograma
     */
    function release() external nonReentrant {
        address beneficiary = msg.sender;
        uint256 releasableAmount = calculateReleasableAmount(beneficiary);
        
        require(releasableAmount > 0, "No tokens available for release");
        
        vestingSchedules[beneficiary].releasedAmount = 
            vestingSchedules[beneficiary].releasedAmount.add(releasableAmount);
        
        require(norxcoin.transfer(beneficiary, releasableAmount), "Token transfer failed");
        
        emit TokensReleased(beneficiary, releasableAmount);
    }

    /**
     * @dev Permite que o admin revogue um cronograma de vesting (uso emergencial)
     * @param _beneficiary Endereço do beneficiário
     * @param _recipient Endereço para receber os tokens restantes
     */
    function revokeVestingSchedule(
        address _beneficiary,
        address _recipient
    ) external onlyRole(ADMIN_ROLE) {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        
        require(schedule.isActive, "No active vesting schedule");
        require(_recipient != address(0), "Recipient cannot be zero address");
        
        uint256 remainingAmount = schedule.totalAmount.sub(schedule.releasedAmount);
        
        schedule.isActive = false;
        
        require(norxcoin.transfer(_recipient, remainingAmount), "Token transfer failed");
        
        emit VestingScheduleRevoked(_beneficiary, remainingAmount);
    }

    /**
     * @dev Retorna o número total de beneficiários
     */
    function getBeneficiariesCount() external view returns (uint256) {
        return beneficiaries.length;
    }

    /**
     * @dev Retorna o status atual do vesting de um beneficiário
     */
    function getVestingStatus(address _beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 releasableAmount,
        uint256 remainingAmount,
        uint256 nextReleaseTime,
        bool isActive
    ) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        
        totalAmount = schedule.totalAmount;
        releasedAmount = schedule.releasedAmount;
        releasableAmount = calculateReleasableAmount(_beneficiary);
        remainingAmount = schedule.totalAmount.sub(schedule.releasedAmount);
        isActive = schedule.isActive;
        
        // Calcula o próximo período de liberação
        uint256 elapsedTime = block.timestamp.sub(schedule.startTime);
        uint256 currentInterval = elapsedTime.div(schedule.releaseInterval);
        nextReleaseTime = schedule.startTime.add(schedule.releaseInterval.mul(currentInterval + 1));
        
        return (totalAmount, releasedAmount, releasableAmount, remainingAmount, nextReleaseTime, isActive);
    }
}
