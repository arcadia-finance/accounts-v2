/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface IAccount {
    /**
     * @notice Returns the Account version.
     * @return version The Account version.
     */
    function ACCOUNT_VERSION() external view returns (uint16);

    /**
     * @notice Initiates the variables of the Account.
     * @param owner The sender of the 'createAccount' on the factory
     * @param registry The 'beacon' contract with the external logic.
     * @param baseCurrency The Base-currency in which the Account is denominated.
     * @param creditor The contract address of the trusted creditor.
     */
    function initialize(address owner, address registry, address baseCurrency, address creditor) external;

    /**
     * @notice Updates the Account version and stores a new address in the EIP1967 implementation slot.
     * @param newImplementation The contract with the new Account logic.
     * @param newRegistry The MainRegistry for this specific implementation (might be identical as the old registry).
     * @param data Arbitrary data, can contain instructions to execute when updating Account to new logic.
     * @param newVersion The new version of the Account logic.
     */
    function upgradeAccount(address newImplementation, address newRegistry, uint16 newVersion, bytes calldata data)
        external;

    /**
     * @notice Transfers ownership of the contract to a new account.
     * @param newOwner The new owner of the Account.
     */
    function transferOwnership(address newOwner) external;
}
