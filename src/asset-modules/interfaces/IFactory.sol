/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IFactory {
    /**
     * @notice Returns the owner of an Account.
     * @param account The Account address.
     * @return owner The Account owner.
     * @dev Function does not revert when a non-existing Account is passed, but returns zero-address as owner.
     */
    function ownerOfAccount(address account) external view returns (address owner);
}
