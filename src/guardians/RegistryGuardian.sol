/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { BaseGuardian, GuardianErrors } from "./BaseGuardian.sol";

/**
 * @title Registry Guardian
 * @author Pragma Labs
 * @notice Logic inherited by the Registry that allows:
 * - An authorized guardian to trigger an emergency stop.
 * - The protocol owner to unpause functionalities one-by-one.
 * - Anyone to unpause all functionalities after a fixed cool-down period.
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

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Throws if the withdraw functionality is paused.
     */
    modifier whenWithdrawNotPaused() {
        if (withdrawPaused) revert GuardianErrors.FunctionIsPaused();
        _;
    }

    /**
     * @dev Throws if the deposit functionality is paused.
     */
    modifier whenDepositNotPaused() {
        if (depositPaused) revert GuardianErrors.FunctionIsPaused();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                            PAUSING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc BaseGuardian
     * @dev This function will pause the functionality to:
     * - Withdraw assets.
     * - Deposit assets.
     */
    function pause() external override onlyGuardian afterCoolDownOf(32 days) {
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
     * @dev This function will unpause the functionality to:
     * - Withdraw assets.
     */
    function unpause() external override afterCoolDownOf(30 days) {
        emit PauseFlagsUpdated(withdrawPaused = false, depositPaused);
    }
}
