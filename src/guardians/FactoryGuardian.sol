/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity 0.8.19;

import { BaseGuardian } from "./BaseGuardian.sol";

/**
 * @title Factory Guardian
 * @author Pragma Labs
 * @notice This module holds the logic that allows authorized accounts to trigger an emergency stop in the Factory.
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

    event PauseFlagUpdated(bool createPauseUpdate);

    /*
    //////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////
    */

    /**
     * @dev This modifier is used to restrict access to the creation of new Accounts when this functionality is paused.
     * It throws if createAccount() is paused.
     */
    modifier whenCreateNotPaused() {
        if (createPaused) revert FunctionIsPaused();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                            PAUSING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function will pause the functionality to create new Accounts.
     */
    function pause() external override onlyGuardian {
        if (block.timestamp <= pauseTimestamp + 32 days) revert CannotPause();
        createPaused = true;
        pauseTimestamp = block.timestamp;

        emit PauseFlagUpdated(true);
    }

    /**
     * @notice This function is used to unpause the creation of Accounts.
     * @param createPaused_ "False" when create functionality should be unpaused.
     * @dev This function can unpause the creation of new Accounts.
     */
    function unpause(bool createPaused_) external onlyOwner {
        emit PauseFlagUpdated(createPaused = createPaused && createPaused_);
    }

    /**
     * @notice This function is not implemented. If someone would ever need to call this function, it means
     * that the protocol can't be trusted anymore. No reason to create be able to create an Account.
     */
    function unpause() external override onlyOwner { }
}
