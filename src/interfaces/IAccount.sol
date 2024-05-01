/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IAccount {
    /**
     * @notice Returns the Account version.
     * @return version The Account version.
     */
    function ACCOUNT_VERSION() external view returns (uint256);

    /**
     * @notice Returns the Arcadia Accounts Factory.
     * @return factory The contract address of the Arcadia Accounts Factory.
     */
    function FACTORY() external view returns (address);

    /**
     * @notice Initiates the variables of the Account.
     * @param owner The sender of the 'createAccount' on the factory
     * @param registry The 'beacon' contract with the external logic.
     * @param creditor The contract address of the creditor.
     */
    function initialize(address owner, address registry, address creditor) external;

    /**
     * @notice Updates the Account version and stores a new address in the EIP1967 implementation slot.
     * @param newImplementation The contract with the new Account logic.
     * @param newRegistry The Registry for this specific implementation (might be identical as the old registry).
     * @param data Arbitrary data, can contain instructions to execute when updating Account to new logic.
     * @param newVersion The new version of the Account logic.
     */
    function upgradeAccount(address newImplementation, address newRegistry, uint256 newVersion, bytes calldata data)
        external;

    /**
     * @notice Transfers ownership of the contract to a new account.
     * @param newOwner The new owner of the Account.
     */
    function transferOwnership(address newOwner) external;

    /**
     * @notice Executes a flash action.
     * @param actionTarget The contract address of the actionTarget to execute external logic.
     * @param actionData A bytes object containing three structs and two bytes objects.
     * The first struct contains the info about the assets to withdraw from this Account to the actionTarget.
     * The second struct contains the info about the owner's assets that need to be transferred from the owner to the actionTarget.
     * The third struct contains the permit for the Permit2 transfer.
     * The first bytes object contains the signature for the Permit2 transfer.
     * The second bytes object contains the encoded input for the actionTarget.
     * @dev This function optimistically chains multiple actions together (= do a flash action):
     * - It can optimistically withdraw assets from the Account to the actionTarget.
     * - It can transfer assets directly from the owner to the actionTarget.
     * - It can execute external logic on the actionTarget, and interact with any DeFi protocol to swap, stake, claim...
     * - It can deposit all recipient tokens from the actionTarget back into the Account.
     * At the very end of the flash action, the following check is performed:
     * - The Account is in a healthy state (collateral value is greater than open liabilities).
     * If a check fails, the whole transaction reverts.
     */
    function flashAction(address actionTarget, bytes calldata actionData) external;
}
