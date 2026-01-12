/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.30;

import { AccountErrors } from "../libraries/Errors.sol";
import { AccountStorageV1 } from "./AccountStorageV1.sol";
import { IAccount } from "../interfaces/IAccount.sol";
import { IAccountsGuard } from "../interfaces/IAccountsGuard.sol";

/**
 * @title Arcadia Account Placeholder
 * @author Pragma Labs
 * @notice This contract is a placeholder of the logic implementation of a certain version of Arcadia Accounts.
 */
contract AccountPlaceholder is AccountStorageV1, IAccount {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Bools indicating if the function being called can be paused by the AccountsGuard.
    bool internal constant WITH_PAUSE_CHECK = true;
    bool internal constant WITHOUT_PAUSE_CHECK = false;

    // The Account Version.
    uint256 public immutable ACCOUNT_VERSION;
    // The cool-down period after an account action, that might be disadvantageous for a new Owner,
    // during which ownership cannot be transferred to prevent the old Owner from frontrunning a transferFrom().
    uint256 public constant COOL_DOWN_PERIOD = 5 minutes;
    // Storage slot with the address of the current Implementation.
    // This is the hardcoded keccak-256 hash of: "eip1967.proxy.implementation" subtracted by 1.
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // The contract address of the Arcadia Accounts Factory.
    address public immutable FACTORY;
    // The contract address of the Accounts Guard.
    IAccountsGuard public immutable ACCOUNTS_GUARD;

    // Storage slot for the Implementation contract, a struct to avoid storage conflict when dealing with upgradeable contracts.
    struct AddressSlot {
        address value;
    }

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @param pauseCheck Bool indicating if a pause check should be done.
     * @dev Throws if cross accounts guard is reentered or paused.
     * @dev Locks/unlocks the cross accounts guard before/after the function is executed.
     */
    modifier nonReentrant(bool pauseCheck) {
        ACCOUNTS_GUARD.lock(pauseCheck);
        _;
        ACCOUNTS_GUARD.unLock();
    }

    /**
     * @dev Throws if called by any address other than the Factory address.
     */
    modifier onlyFactory() {
        if (msg.sender != FACTORY) revert AccountErrors.OnlyFactory();
        _;
    }

    /**
     * @dev Throws if called by any address other than the owner.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert AccountErrors.OnlyOwner();
        _;
    }

    /**
     * @dev Starts the cool-down period during which ownership cannot be transferred.
     * This prevents the old Owner from frontrunning a transferFrom().
     */
    modifier updateActionTimestamp() {
        lastActionTimestamp = uint32(block.timestamp);
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param factory The contract address of the Arcadia Accounts Factory.
     * @param accountsGuard The contract address of the Accounts Guard.
     * @param version The Account Version.
     */
    constructor(address factory, address accountsGuard, uint256 version) {
        // This will only be the owner of the Account implementation.
        // and will not affect any subsequent proxy implementation using this Account implementation.
        owner = msg.sender;

        FACTORY = factory;
        ACCOUNTS_GUARD = IAccountsGuard(accountsGuard);
        ACCOUNT_VERSION = version;
    }

    /* ///////////////////////////////////////////////////////////////
                          PROXY MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Initiates the variables of the Account.
     * @param owner_ The sender of the 'createAccount' on the Factory
     * @param registry_ The 'beacon' contract with the external logic to price assets.
     * @dev A proxy will be used to interact with the Account implementation.
     * This function will only be called (once) in the same transaction as the proxy Account creation through the Factory.
     * @dev The Registry is not used in the placeholder implementation, but a valid registry must be set to be compatible with V1 Accounts.
     */
    function initialize(address owner_, address registry_, address)
        external
        onlyFactory
        nonReentrant(WITH_PAUSE_CHECK)
    {
        if (registry_ == address(0)) revert AccountErrors.InvalidRegistry();
        owner = owner_;
        registry = registry_;
    }

    /**
     * @notice Upgrades the Account version and stores a new address in the EIP1967 implementation slot.
     * @param newImplementation The new contract address of the Account implementation.
     * @param newRegistry The Registry for this specific newImplementation.
     * @param data Arbitrary data, can contain instructions to execute when updating Account to new implementation.
     * @dev This function MUST be added to new Account implementations.
     */
    function upgradeAccount(address newImplementation, address newRegistry, uint256, bytes calldata data)
        external
        onlyFactory
        nonReentrant(WITHOUT_PAUSE_CHECK)
        updateActionTimestamp
    {
        // Cache old parameters.
        address oldImplementation = _getAddressSlot(IMPLEMENTATION_SLOT).value;
        uint256 oldVersion = ACCOUNT_VERSION;

        // Store new parameters.
        _getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
        registry = newRegistry;

        // Hook on the new logic to finalize upgrade.
        // Used to eg. Remove exposure from old Registry and add exposure to the new RegistryL2.
        // Extra data can be added by the Factory for complex instructions.
        this.upgradeHook(oldImplementation, address(0), oldVersion, data);

        // Event emitted by Factory.
    }

    /**
     * @notice Returns the "AddressSlot" with member "value" located at "slot".
     * @param slot The slot where the address of the Logic contract is stored.
     * @return r The address stored in slot.
     */
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @notice Finalizes the Upgrade to a new Account version on the new implementation Contract.
     * param oldImplementation The old contract address of the Account implementation.
     * param oldRegistry The Registry of the old version (might be identical to the new registry)
     * param oldVersion The old version of the Account implementation.
     * param data Arbitrary data, can contain instructions to execute in this function.
     * @dev If upgradeHook() is implemented, it MUST verify that msg.sender == address(this).
     */
    function upgradeHook(address, address, uint256, bytes calldata) external {
        // Function must be non-view, we do a sstore to suppress pure/view warning for proxy compatibility.
        owner = owner;

        // Placeholder implementations are strictly for creating Accounts of a certain version.
        // It should never be possible to upgrade an Account to a Placeholder implementation.
        revert AccountErrors.InvalidUpgrade();
    }

    /* ///////////////////////////////////////////////////////////////
                        OWNERSHIP MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Transfers ownership of the contract to a new Account.
     * @param newOwner The new owner of the Account.
     * @dev Can only be called by the current owner via the Factory.
     * A transfer of ownership of the Account is triggered by a transfer
     * of ownership of the accompanying ERC721 Account NFT, issued by the Factory.
     * Owner of Account NFT = owner of Account
     * @dev Function uses a cool-down period during which ownership cannot be transferred.
     * Cool-down period is triggered after any account action, that might be disadvantageous for a new Owner.
     * This prevents the old Owner from frontrunning a transferFrom().
     */
    function transferOwnership(address newOwner) external onlyFactory nonReentrant(WITHOUT_PAUSE_CHECK) {
        if (block.timestamp <= lastActionTimestamp + COOL_DOWN_PERIOD) revert AccountErrors.CoolDownPeriodNotPassed();

        // The Factory will check that the new owner is not address(0).
        owner = newOwner;
    }
}
