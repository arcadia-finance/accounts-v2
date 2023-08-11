/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.13;

interface IFactory {
    /**
     * @notice Checks if a contract is a Account.
     * @param account The contract address of the Account.
     * @return bool indicating if the address is a Account or not.
     */
    function isAccount(address account) external view returns (bool);

    /**
     * @notice Function called by a Account at the start of a liquidation to transfer ownership to the Liquidator contract.
     * @param liquidator The contract address of the liquidator.
     */
    function liquidate(address liquidator) external;
}
