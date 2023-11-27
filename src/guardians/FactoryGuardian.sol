/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity 0.8.22;

import { BaseGuardian, GuardianErrors } from "./BaseGuardian.sol";

/**
 * @title Factory Guardian
 * @author Pragma Labs
 * @notice Logic inherited by the Factory that allows:
 * - An authorized guardian to trigger an emergency stop.
 * - The protocol owner to unpause functionalities.
 * - Anyone to unpause all functionalities after a fixed cool-down period.
 */
abstract contract FactoryGuardian is BaseGuardian {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Flag indicating if the create() function is paused.
    bool public createPaused;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error FunctionNotImplemented();

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event PauseFlagsUpdated(bool createPauseUpdate);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Throws if the createAccount functionality is paused.
     */
    modifier whenCreateNotPaused() {
        if (createPaused) revert GuardianErrors.FunctionIsPaused();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                            PAUSING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc BaseGuardian
     * @dev This function will pause the functionality to create new Accounts.
     */
    function pause() external override onlyGuardian afterCoolDownOf(32 days) {
        pauseTimestamp = uint96(block.timestamp);

        emit PauseFlagsUpdated(createPaused = true);
    }

    /**
     * @notice This function is used to unpause the creation of Accounts.
     * @param createPaused_ "False" when create functionality should be unpaused.
     * @dev This function can unpause the creation of new Accounts.
     * @dev Can only update flags from paused (true) to unpaused (false), cannot be used the other way around
     * (to set unpaused flags to paused).
     */
    function unpause(bool createPaused_) external onlyOwner {
        emit PauseFlagsUpdated(createPaused = createPaused && createPaused_);
    }

    /**
     * @notice This function is not implemented.
     * @dev No reason to be able to create an Account if the owner of the Factory did not unpause createAccount().
     */
    function unpause() external pure override {
        revert FunctionNotImplemented();
    }
}
