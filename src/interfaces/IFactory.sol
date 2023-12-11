/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IFactory {
    /**
     * @notice Checks if a contract is an Account.
     * @param account The contract address of the Account.
     * @return bool indicating if the address is an Account or not.
     */
    function isAccount(address account) external view returns (bool);

    /**
     * @notice Function used to transfer an Account, called by the Account itself.
     * @param to The target.
     */
    function safeTransferAccount(address to) external;
}
