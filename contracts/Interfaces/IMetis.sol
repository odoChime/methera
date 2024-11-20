// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IMetis {
    function l1Token() external returns (address);

    function l2Bridge() external returns (address);

    function mint(address, uint256) external;

    function burn(address, uint256) external;
}