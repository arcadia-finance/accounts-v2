/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { GuardianErrors } from "../libraries/Errors.sol";
import { Owned } from "../../lib/solmate/src/auth/Owned.sol";

/**
 * @title Guardian
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of a Guardian contract.
 * It implements the following logic:
 * - An authorized guardian can trigger an emergency stop.
 * - The protocol owner can unpause functionalities one-by-one.
 * - Anyone can unpause all functionalities after a fixed cool-down period.
 */
abstract contract BaseGuardian is Owned {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Last timestamp an emergency stop was triggered.
    uint96 public pauseTimestamp;
    // Address of the Guardian.
    address public guardian;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event GuardianChanged(address indexed user, address indexed newGuardian);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Only guardians can call functions with this modifier.
     */
    modifier onlyGuardian() {
        if (msg.sender != guardian) revert GuardianErrors.OnlyGuardian();
        _;
    }

    /**
     * @dev The public unpause() function, or a second pause() function, can only called a fixed coolDownPeriod after an initial pause().
     * This gives the protocol owner time to investigate and solve potential issues,
     * but ensures that no rogue owner or guardian can lock user funds for an indefinite amount of time.
     */
    modifier afterCoolDownOf(uint256 coolDownPeriod) {
        if (block.timestamp <= pauseTimestamp + coolDownPeriod) revert GuardianErrors.CoolDownPeriodNotPassed();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() Owned(msg.sender) { }

    /* //////////////////////////////////////////////////////////////
                            GUARDIAN LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function is used to set the guardian address
     * @param guardian_ The address of the new guardian.
     */
    function changeGuardian(address guardian_) external onlyOwner {
        emit GuardianChanged(msg.sender, guardian = guardian_);
    }

    /* //////////////////////////////////////////////////////////////
                            PAUSING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function is used to pause all the flags of the contract.
     * @dev The Guardian can only pause the protocol again after 32 days have passed since the last pause.
     * This is to prevent that a malicious owner or guardian can take user funds hostage for an indefinite time.
     * After the guardian has paused the protocol, the owner has 30 days to find potential problems,
     * find a solution and unpause the protocol. If the protocol is not unpaused after 30 days,
     * an emergency procedure can be started by any user to unpause the protocol.
     * All users have now at least a two-day window to withdraw assets and close positions before
     * the protocol can again be paused 32 days after the contract was previously paused.
     */
    function pause() external virtual;

    /**
     * @notice This function is used to unpause flags that could be abused to lock user assets.
     * @dev If the protocol is not unpaused after 30 days, any user can unpause the protocol.
     * This ensures that no rogue owner or guardian can lock user funds for an indefinite amount of time.
     * All users have now at least a two-day window to withdraw assets and close positions before
     * the protocol can again be paused 32 days after the contract was previously paused.
     */
    function unpause() external virtual;
}
