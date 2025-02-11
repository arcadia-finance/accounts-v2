/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IStakedSlipstreamAM {
    function mint(uint256 id) external returns (uint256 tokenId);
    function claimReward(uint256 id) external returns (uint256 rewards);
    function burn(uint256 id) external returns (uint256 rewards);
}
