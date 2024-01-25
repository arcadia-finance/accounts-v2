/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

/**
 * @title Library for packing sequences of oracles in a single bytes32-object
 * @author Pragma Labs
 */
library BitPackingLib {
    /**
     * @notice Packs sequences of oracles in a single bytes32-object.
     * @param boolValues Array with the direction of the rate for each oracle:
     *  - 0 prices the BaseAsset in units of QuoteAsset.
     *  - 1 prices the QuoteAsset in units of BaseAsset.
     * @param uintValues Array with the unique identifier of each oracle.
     * @return packedData The packed oracle data.
     * @dev Both arrays always have equal length and length is smaller than or equal to 3.
     */
    function pack(bool[] memory boolValues, uint80[] memory uintValues) internal pure returns (bytes32 packedData) {
        assembly {
            // Get the length of the arrays.
            let length := mload(boolValues)

            // Store the total length in the two right most bits
            // Length is always smaller than or equal to 3.
            packedData := length

            // Loop to pack the array-elements.
            for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                // Calculate the offset for elements at index i.
                let offset := mul(32, add(i, 1))

                // Read the value of the boolean at index i.
                let boolValue := mload(add(boolValues, offset))

                // Read the value of the uint80 at index i.
                let uintValue := mload(add(uintValues, offset))

                // Shift the boolValue to the left by 2 + i * 80 bits.
                // Then OR the result with packedData.
                packedData := or(packedData, shl(add(mul(i, 81), 2), boolValue))

                // Shift the uintValue to the left by 3 + i * 80 bits.
                // Then OR the result with packedData.
                packedData := or(packedData, shl(add(mul(i, 81), 3), uintValue))
            }
        }
    }

    /**
     * @notice Unpacks a sequence of oracles from the bytes32-object.
     * @param packedData The packed oracle data.
     * @return boolValues Array with the direction of the rate for each oracle:
     *  - 0 prices the BaseAsset in units of QuoteAsset.
     *  - 1 prices the QuoteAsset in units of BaseAsset.
     * @return uintValues Array with the unique identifier of each oracle.
     * @dev Both arrays always have equal length and length is smaller than or equal to 3.
     * @dev There are three ways the object can be packed, depending on the value of the rightmost two bits:
     * uint80, bool, uint2 (=01) or
     * uint80, bool uint80, bool, uint2 (=10) or
     * uint80, bool, uint80, bool uint80, bool, uint2 (=11).
     */
    function unpack(bytes32 packedData) internal pure returns (bool[] memory boolValues, uint256[] memory uintValues) {
        assembly {
            // Use bitmask to extract the array length from the rightmost 2 bits.
            // Length is always smaller than or equal to 3.
            let length := and(packedData, 0x3)

            // Calculate the total memory size of each array.
            // 32 bytes per index of the array + 32 bytes for the array length.
            let memSize := mul(add(length, 1), 32)

            // Initiate the boolean array at the next free memory slot.
            boolValues := mload(0x40)

            // Initiate the uint80 array after the boolean array.
            uintValues := add(boolValues, memSize)

            // Update the free memory pointer to the next free memory slot.
            mstore(0x40, add(uintValues, memSize))

            // Store the sizes of the arrays at the first slot of each array.
            mstore(boolValues, length)
            mstore(uintValues, length)

            // Loop to unpack the array-elements.
            for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                // Shift to the right by 2 + i * 81 bits.
                // Then use bitmask to extract the boolean at index i from the rightmost bit.
                let boolValue := and(shr(add(mul(i, 81), 2), packedData), 0x1)

                // Shift to the right by 3 + i * 81 bits.
                // Then use bitmask to extract the uint80 at index i from the rightmost 80 bits.
                let uintValue := and(shr(add(mul(i, 81), 3), packedData), 0xFFFFFFFFFFFFFFFFFFFF)

                // Calculate the offset for elements at index i.
                let offset := mul(32, add(i, 1))

                // Store the value of the boolean at index i.
                mstore(add(boolValues, offset), boolValue)

                // Store the value of the boolean at index i.
                mstore(add(uintValues, offset), uintValue)
            }
        }
    }
}
