/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IComptroller {
    /**
     * @notice Claim all rewards for a specified group of users, tokens, and market sides
     * @param holders The addresses to claim for
     * @param mTokens The list of markets to claim in
     * @param borrowers Whether or not to claim earned by borrowing
     * @param suppliers Whether or not to claim earned by supplying
     */
    function claimReward(address[] memory holders, address[] memory mTokens, bool borrowers, bool suppliers) external;
}
