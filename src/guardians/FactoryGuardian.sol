/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity 0.8.19;

import { BaseGuardian } from "./BaseGuardian.sol";

/**
 * @title Factory Guardian
 * @author Pragma Labs
 * @notice This module provides the logic for the Factory that allows authorized accounts to trigger an emergency stop.
 */
abstract contract FactoryGuardian is BaseGuardian {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Flag indicating if the create() function is paused.
    bool public createPaused;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event PauseUpdate(bool createPauseUpdate);

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
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for create Accounts.
     * It throws if create Account is paused.
     */
    modifier whenCreateNotPaused() {
        if (createPaused) revert FunctionIsPaused();
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
        createPaused = true;
        pauseTimestamp = block.timestamp;

        emit PauseUpdate(true);
    }

    /**
     * @notice This function is used to unpause the creation of Accounts.
     * @param createPaused_ false when create functionality should be unPaused.
     * @dev This function can unPause repay, withdraw, borrow, and deposit individually.
     * @dev Can only update flags from paused (true) to unPaused (false), cannot be used the other way around
     * (to set unPaused flags to paused).
     */
    function unpause(bool createPaused_) external onlyOwner {
        createPaused = createPaused && createPaused_;

        emit PauseUpdate(createPaused);
    }

    /**
     * @inheritdoc BaseGuardian
     */
    function unpause() external override {
        if (block.timestamp <= pauseTimestamp + 30 days) revert CannotUnpause();
        createPaused = false;

        emit PauseUpdate(false);
    }
}
