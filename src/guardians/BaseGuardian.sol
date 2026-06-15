/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

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
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp <= pauseTimestamp + coolDownPeriod) revert GuardianErrors.CoolDownPeriodNotPassed();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param owner_ The address of the Owner.
     */
    constructor(address owner_) Owned(owner_) { }

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
     * @dev The Guardian can only pause the protocol again after the cool-down period has passed since the last pause.
     * This prevents a malicious owner or guardian from taking user funds hostage for an indefinite time.
     * After the guardian has paused the protocol, the owner can investigate and unpause functionalities one-by-one.
     * If the protocol is not unpaused before the cool-down period elapses, any user can unpause it via unpause().
     * The length of the cool-down period is set by the implementation.
     */
    function pause() external virtual;

    /**
     * @notice This function is used to unpause flags that could be abused to lock user assets.
     * @dev Once the cool-down period has passed since the last pause, any user can unpause the protocol.
     * This ensures that no rogue owner or guardian can lock user funds for an indefinite amount of time.
     * The length of the cool-down period is set by the implementation.
     */
    function unpause() external virtual;
}
