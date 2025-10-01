/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.30;

import { IFactory } from "../../interfaces/IFactory.sol";
import { Owned } from "../../../lib/solmate/src/auth/Owned.sol";

/**
 * @title Guard for preventing multi Account reentrancy and cross account pausing.
 * @author Pragma Labs
 */
contract AccountsGuard is Owned {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the Arcadia Factory.
    IFactory public immutable ARCADIA_FACTORY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Flag indicating if the functionalities are paused.
    bool public paused;

    // Address of the Guardian.
    address public guardian;

    /* //////////////////////////////////////////////////////////////
                          TRANSIENT STORAGE
    ////////////////////////////////////////////////////////////// */

    // The address of the Arcadia Account that initiated the lock.
    address internal transient account;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error Locked();
    error OnlyAccount();
    error OnlyGuardian();
    error Paused();
    error Reentered();

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event GuardianChanged(address indexed user, address indexed newGuardian);
    event PauseFlagsUpdated(bool pauseUpdate);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Throws when caller is not the guardian.
     */
    modifier onlyGuardian() {
        if (msg.sender != guardian) revert OnlyGuardian();
        _;
    }

    /**
     * @dev Throws if the functionalities are paused.
     */
    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param owner_ The address of the Owner.
     * @param arcadiaFactory The contract address of the Arcadia Factory.
     */
    constructor(address owner_, address arcadiaFactory) Owned(owner_) {
        ARCADIA_FACTORY = IFactory(arcadiaFactory);
    }

    /* ///////////////////////////////////////////////////////////////
                        REENTRANCY GUARD LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Locks the cross accounts guard.
     * @param pauseCheck Bool indicating if a pause check should be done.
     * @dev Serves as a cross account reentrancy and pause guard.
     * @dev lock() and unlock() should always be called atomically at the beginning and end of any Account-function
     * that should be protected by the cross accounts guard.
     * The guard gives NO reentrancy protection for non atomic flows.
     * @dev If the AccountsGuard gets in an invalid state due to a faulty implementation in an Account
     * where the Guard was locked but not unlocked (should never happen in practice),
     * then only calls within the same transaction as the faulty call will revert.
     */
    function lock(bool pauseCheck) external {
        if (pauseCheck && paused) revert Paused();
        if (account != address(0)) revert Reentered();
        if (!ARCADIA_FACTORY.isAccount(msg.sender)) revert OnlyAccount();

        account = msg.sender;
    }

    /**
     * @notice Unlocks the cross accounts guard.
     * @dev lock() and unlock() should always be called atomically at the beginning and end of any Account-function
     * that should be protected by the cross accounts guard.
     * The guard gives NO reentrancy protection for non atomic flows.
     */
    function unLock() external {
        if (account != msg.sender) revert OnlyAccount();

        account = address(0);
    }

    /* ///////////////////////////////////////////////////////////////
                        PAUSE GUARD LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets a new guardian.
     * @param guardian_ The address of the new guardian.
     */
    function changeGuardian(address guardian_) external onlyOwner {
        emit GuardianChanged(msg.sender, guardian = guardian_);
    }

    /**
     * @notice Pauses all functionalities.
     */
    function pause() external onlyGuardian whenNotPaused {
        emit PauseFlagsUpdated(paused = true);
    }

    /**
     * @notice Sets the pause flag.
     * @param paused_ Flag indicating if the functionalities are paused.
     */
    function setPauseFlag(bool paused_) external onlyOwner {
        emit PauseFlagsUpdated(paused = paused_);
    }
}
