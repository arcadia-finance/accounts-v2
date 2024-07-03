/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IStakedSlipstreamAM {
    function mint(uint256 id) external returns (uint256 tokenId);
}
