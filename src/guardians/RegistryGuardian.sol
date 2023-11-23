/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity 0.8.19;

import { BaseGuardian } from "./BaseGuardian.sol";

/**
 * @title Registry Guardian
 * @author Pragma Labs
 * @notice Logic inherited by the Registry that allows an authorized guardian to trigger an emergency stop.
 * It also enables public or authorized guardian to unpause in certain cases.
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

    event PauseFlagsUpdated(bool withdrawPauseUpdate, bool depositPauseUpdate);

    /*
    //////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////
    */

    /**
     * @dev Throws if the withdraw functionality is paused.
     */
    modifier whenWithdrawNotPaused() {
        if (withdrawPaused) revert FunctionIsPaused();
        _;
    }

    /**
     * @dev Throws if the deposit functionality is paused.
     */
    modifier whenDepositNotPaused() {
        if (depositPaused) revert FunctionIsPaused();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                            PAUSING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc BaseGuardian
     */
    function pause() external override onlyGuardian {
        if (block.timestamp <= pauseTimestamp + 32 days) revert CannotPause();
        pauseTimestamp = uint96(block.timestamp);

        emit PauseFlagsUpdated(withdrawPaused = true, depositPaused = true);
    }

    /**
     * @notice This function is used to unpause one or more flags.
     * @param withdrawPaused_ It is false when withdraw functionality should be unPaused.
     * @param depositPaused_ It is false when deposit functionality should be unPaused.
     * @dev This function can unPause withdraw and deposit individually.
     * @dev Can only update flags from paused (true) to unpaused (false), cannot be used the other way around
     * (to set unpaused flags to paused).
     */
    function unpause(bool withdrawPaused_, bool depositPaused_) external onlyOwner {
        emit PauseFlagsUpdated(
            withdrawPaused = withdrawPaused && withdrawPaused_, depositPaused = depositPaused && depositPaused_
        );
    }

    /**
     * @inheritdoc BaseGuardian
     * @dev This function is used to unpause withdraw and deposit at the same time.
     */
    function unpause() external override {
        if (block.timestamp <= pauseTimestamp + 30 days) revert CannotUnpause();
        emit PauseFlagsUpdated(withdrawPaused = false, depositPaused = false);
    }
}
