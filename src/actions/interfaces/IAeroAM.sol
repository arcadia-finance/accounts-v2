/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

interface IAeroAM {
    function mint(address pool, uint128 amount) external returns (uint256 tokenId);
}
