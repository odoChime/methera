// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { TransferHelper } from "./Utils/Library.sol";
import "./Interfaces/IAMTDepositPool.sol";
import "./Interfaces/IAMTRewardPool.sol";
import "./Interfaces/IYMetis.sol";
import "./Interfaces/IMetis.sol";
import "./Interfaces/IL2Bridge.sol";
import "./Utils/AMTConstants.sol";
import "./Interfaces/IAMTConfig.sol";

contract AMTDepositPool is IAMTDepositPool, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    IAMTConfig public config;
    uint256 public totalDeposits;

    address[] public strategyList;

    struct UserInfo {
        uint256 totalDeposit;
        mapping(address => uint256) strategyDeposits;
        mapping(address => uint256) pendingRewards; 
    }

    struct StrategyInfo {
        uint256 totalDeposits;
        uint256 pendingRewards;
    }

    mapping(address => UserInfo) public users;
    mapping(address => StrategyInfo) public strategies;


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _config) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AMTConstants.ADMIN_ROLE, msg.sender);

        config = IAMTConfig(_config);
        totalDeposits = 0;
    }

    function getYMetisAmountToMint(
        uint256 _amount
    ) public view returns (uint256) {
        return _amount;
    }

    function deposit(
        uint256 _minYMetisAmountToReceive,
        string calldata _referralId,
        address _strategy
    ) external payable updateTotalDeposits returns (uint256) {
        require(msg.value > 0, "AMTDepositPool: INVALID_AMOUNT");
        require(_strategy == address(0), "AMTDepositPool: INVALID_STRATEGY");

        uint256 yMetisAmount = getYMetisAmountToMint(msg.value);

        require(
            yMetisAmount >= _minYMetisAmountToReceive,
            "AMTDepositPool: yMetis is too high"
        );
        users[msg.sender].totalDeposit += yMetisAmount;
        users[msg.sender].strategyDeposits[_strategy] += yMetisAmount;
        strategies[_strategy].totalDeposits += yMetisAmount;

        totalDeposits += yMetisAmount;
        IYMetis(config.getContract(AMTConstants.ART_METIS)).mint(
            msg.sender,
            yMetisAmount
        );

        emit MetisDeposited(msg.sender, _strategy, yMetisAmount, yMetisAmount, _referralId);
        return yMetisAmount;
    }

    function harvest() public {
        uint256 reward = IAMTRewardPool(
            config.getContract(AMTConstants.AMT_REWARD_POOL)
        ).claimReward();
        if (reward == 0) {
            return;
        }
        for (uint256 i = 0; i < strategyList.length; i++) {
            address strategy = strategyList[i];
            uint256 strategyReward = (reward * strategies[strategy].totalDeposits) / totalDeposits;

            strategies[strategy].pendingRewards += strategyReward;
            emit StrategyRewardDistributed(strategy, strategyReward);
        }

        // totalDeposits += reward;
        emit Harvested(msg.sender, reward);
    }

    function bridgeMetisToL1(
        uint32 l1GasLimit
    ) external payable onlyRole(AMTConstants.ADMIN_ROLE) {
        address l1StakingPool = config.getContract(
            AMTConstants.L1_STAKING_POOL
        );
        require(
            l1StakingPool != address(0),
            "AMTDepositPool: INVALID_L1_STAKING_POOL"
        );
        uint256 balance = address(this).balance - msg.value;
        if (balance == 0) {
            return;
        }

        IL2Bridge(IMetis(config.getContract(AMTConstants.METIS)).l2Bridge())
            .withdrawMetisTo{value: msg.value}(
            l1StakingPool,
            balance,
            l1GasLimit,
            "0x00"
        );
        emit BridgeMetisToL1(msg.sender, balance);
    }

    function adminWithdrawMetis(
        uint256 _amount
    ) external onlyAdminOrWithdrawalManager {
        require(_amount > 0, "AMTDepositPool: invalid amount");
        uint256 balance = address(this).balance;
        require(_amount <= balance, "AMTDepositPool: amount exceeds balance");

        TransferHelper.safeTransferETH(msg.sender, _amount);
        emit AdminWithdrawnMetis(msg.sender, _amount);
    }

    function initiateWithdrawalFor(
        address _user,
        uint256 _yMetisAmount,
        uint256 _metisAmount,
        address _strategy
    ) external onlyWithdrawalManager {
        require(
            _yMetisAmount > 0 && _metisAmount > 0,
            "AMTDepositPool: invalid amount"
        );
        UserInfo storage user = users[_user];

        require(
            user.strategyDeposits[_strategy] >= _metisAmount,
            "AMTDepositPool: insufficient deposit in strategy"
        );

        IYMetis(config.getContract(AMTConstants.ART_METIS)).burn(
            _user,
            _yMetisAmount
        );
        user.totalDeposit -= _metisAmount;
        user.strategyDeposits[_strategy] -= _metisAmount;

        strategies[_strategy].totalDeposits -= _metisAmount;
        totalDeposits -= _metisAmount;
        emit InitiateWithdrawalFor(_user, _yMetisAmount, _metisAmount);
    }

    modifier updateTotalDeposits() {
        harvest();
        _;
    }

    modifier onlyWithdrawalManager() {
        require(
            msg.sender ==
                config.getContract(AMTConstants.AMT_WITHDRAWAL_MANAGER),
            "AMTDepositPool: only withdrawal manager"
        );
        _;
    }

    modifier onlyAdminOrWithdrawalManager() {
        require(
            hasRole(AMTConstants.ADMIN_ROLE, msg.sender) ||
                msg.sender ==
                config.getContract(AMTConstants.AMT_WITHDRAWAL_MANAGER),
            "AMTDepositPool: only admin or withdrawal manager"
        );
        _;
    }

    function addStrategy(address _strategy) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(_strategy != address(0), "AMTDepositPool: INVALID_STRATEGY_ADDRESS");
        strategyList.push(_strategy);
        emit StrategyAdded(_strategy);
    }

    function removeStrategy(address _strategy) public onlyRole(AMTConstants.ADMIN_ROLE) {
        uint256 index = findStrategyIndex(_strategy);
        require(index < strategyList.length, "Strategy not found");

        strategyList[index] = strategyList[strategyList.length - 1];
        strategyList.pop();

        emit StrategyRemoved(_strategy);
    }

    function findStrategyIndex(address _strategy) internal view returns (uint256) {
        for (uint256 i = 0; i < strategyList.length; i++) {
            if (strategyList[i] == _strategy) {
                return i;
            }
        }
        revert("Strategy not found");
    }

    receive() external payable {}
}
