// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title Proxy
 * @author Pragma Labs
 * @dev Implementation based on ERC1967: Proxy Storage Slots.
 * See https://eips.ethereum.org/EIPS/eip-1967.
 */
contract RevertingProxy {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Storage slot with the address of the current implementation.
    // This is the hardcoded keccak-256 hash of: "eip1967.proxy.implementation" subtracted by 1.
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Storage slot for the Account logic, a struct to avoid storage conflict when dealing with upgradeable contracts.
    struct AddressSlot {
        address value;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error ErrorMessage();

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event Upgraded(address indexed implementation);

    /* //////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param implementation The contract address of the Account logic.
     */
    constructor(address implementation) payable {
        _getAddressSlot(IMPLEMENTATION_SLOT).value = implementation;
        emit Upgraded(implementation);

        if (implementation != address(0)) revert ErrorMessage();
    }

    /*///////////////////////////////////////////////////////////////
                        IMPLEMENTATION LOGIC
    ///////////////////////////////////////////////////////////////*/

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
}
