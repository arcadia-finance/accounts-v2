/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.22;

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

    /**
     * @notice Function used to transfer an Account between users based on Account address.
     * @param from The sender.
     * @param to The target.
     * @param account The address of the Account that is transferred.
     * @dev This method transfers an Account on Account address instead of id and
     * also transfers the Account proxy contract to the new owner.
     * @dev The Account itself cannot become its owner.
     */
    function safeTransferFrom(address from, address to, address account) external;

    /**
     * @notice This function allows Account owners to upgrade the implementation of the Account.
     * @param account Account that needs to be upgraded.
     * @param version The accountVersion to upgrade to.
     * @param proofs The Merkle proofs that prove the compatibility of the upgrade from current to new account version.
     * @dev As each Account is a proxy, the implementation of the proxy can be changed by the owner of the Account.
     * Checks are done such that only compatible versions can be upgraded to.
     * Merkle proofs and their leaves can be found on https://www.github.com/arcadia-finance.
     */
    function upgradeAccountVersion(address account, uint256 version, bytes32[] calldata proofs) external;
}
