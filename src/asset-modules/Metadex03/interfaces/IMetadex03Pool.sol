// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03Pool {
    function tokens() external view returns (address token0, address token1);
    function POOL_TYPE() external view returns (bytes32);
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);
    function totalSupply() external view returns (uint256);
    function claimFees(address recipient) external returns (uint256, uint256);
    function index0() external view returns (uint256);
    function index1() external view returns (uint256);
    function supplyIndex0(address account) external view returns (uint256);
    function supplyIndex1(address account) external view returns (uint256);
    function claimable0(address account) external view returns (uint256);
    function claimable1(address account) external view returns (uint256);
}
