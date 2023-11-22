/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity 0.8.19;

import { BaseGuardian } from "./BaseGuardian.sol";

/**
 * @title Registry Guardian
 * @author Pragma Labs
 * @notice This module provides the logic for the Registry that allows authorized accounts to trigger an emergency stop.
 */
abstract contract RegistryGuardian is BaseGuardian {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Flag indicating if the withdraw() function is paused.
    bool public withdrawPaused;
    // Flag indicating if the deposit() function is paused.
    bool public depositPaused;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event PauseUpdate(bool withdrawPauseUpdate, bool depositPauseUpdate);

    /*
    //////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////
    */

    /*
    //////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////
    */

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for withdraw assets.
     * It throws if withdraw is paused.
     */
    modifier whenWithdrawNotPaused() {
        if (withdrawPaused) revert FunctionIsPaused();
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for deposit assets.
     * It throws if deposit assets is paused.
     */
    modifier whenDepositNotPaused() {
        if (depositPaused) revert FunctionIsPaused();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() { }

    /* //////////////////////////////////////////////////////////////
                            PAUSING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc BaseGuardian
     */
    function pause() external override onlyGuardian {
        if (block.timestamp <= pauseTimestamp + 32 days) revert CannotPause();
        withdrawPaused = true;
        depositPaused = true;
        pauseTimestamp = block.timestamp;

        emit PauseUpdate(true, true);
    }

    /**
     * @notice This function is used to unpause one or more flags.
     * @param withdrawPaused_ false when withdraw functionality should be unpaused.
     * @param depositPaused_ false when deposit functionality should be unpaused.
     * @dev This function can unpause repay, withdraw, borrow, and deposit individually.
     * @dev Can only update flags from paused (true) to unpaused (false), cannot be used the other way around
     * (to set unpaused flags to paused).
     */
    function unpause(bool withdrawPaused_, bool depositPaused_) external onlyOwner {
        withdrawPaused = withdrawPaused && withdrawPaused_;
        depositPaused = depositPaused && depositPaused_;

        emit PauseUpdate(withdrawPaused, depositPaused);
    }

    /**
     * @inheritdoc BaseGuardian
     */
    function unpause() external override {
        if (block.timestamp <= pauseTimestamp + 30 days) revert CannotUnpause();
        withdrawPaused = false;
        depositPaused = false;

        emit PauseUpdate(false, false);
    }
}
