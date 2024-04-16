/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { BitPackingLib } from "../../../src/libraries/BitPackingLib.sol";

contract BitPackingLibExtension {
    function pack(bool[] memory boolValues, uint80[] memory uintValues) public pure returns (bytes32 packedData) {
        packedData = BitPackingLib.pack(boolValues, uintValues);
    }

    function unpack(bytes32 packedData) public pure returns (bool[] memory boolValues, uint256[] memory uintValues) {
        (boolValues, uintValues) = BitPackingLib.unpack(packedData);
    }
}
