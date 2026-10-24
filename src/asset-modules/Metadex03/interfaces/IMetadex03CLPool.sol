// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03CLPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function gauge() external view returns (address);
}
