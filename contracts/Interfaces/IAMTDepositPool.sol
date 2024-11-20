// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IAMTDepositPool {
    function getYMetisAmountToMint(
        uint256 _amount
    ) external view returns (uint256);

    function deposit(
        uint256 _minYMetisAmountToReceive,
        string calldata _referralId,
        address _strategy
    ) external payable returns (uint256);

    function harvest() external;

    function bridgeMetisToL1(uint32 l1Gas) external payable;

    function adminWithdrawMetis(uint256 _amount) external;

    function initiateWithdrawalFor(
        address _user,
        uint256 _yMetisAmount,
        uint256 _depositAmount,
        address _strategy
    ) external;

    event MetisDeposited(
        address indexed _user,
        address indexed _strategy,
        uint256 _amount,
        uint256 _yMetisAmount,
        string _referralId
    );
    event Harvested(address indexed _user, uint256 _amount);
    event BridgeMetisToL1(address indexed _user, uint256 _amount);
    event AdminWithdrawnMetis(address indexed _user, uint256 _amount);
    event InitiateWithdrawalFor(
        address indexed _user,
        uint256 _yMetisAmount,
        uint256 _depositAmount
    );
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event StrategyRewardDistributed(address indexed strategy, uint256 _strategyReward);
}
