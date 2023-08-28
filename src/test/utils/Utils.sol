/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

library Utils {
    function deployBytecode(bytes memory bytecode) internal returns (address addr) {
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }

    /**
     * @dev Non-optimised code to replace a certain 32 bytes sequence in a longer bytes object.
     * @dev Assumes the 32 bytes sequence is exactly once present in the bytes object.
     * Reverts if it is not present and only replaces first occurrence if present multiple times.
     */
    function veryBadBytesReplacer(bytes memory bytecode, bytes32 target, bytes32 replacement)
        internal
        pure
        returns (bytes memory result)
    {
        require(target.length <= bytecode.length);

        bytes memory target_ = abi.encodePacked(target);
        bytes memory replacement_ = abi.encodePacked(replacement);

        uint256 lengthTarget = target_.length;
        uint256 lengthBytecode = bytecode.length - lengthTarget + 1;
        uint256 i;
        for (i; i < lengthBytecode;) {
            uint256 j = 0;
            for (j; j < lengthTarget;) {
                if (bytecode[i + j] == target_[j]) {
                    if (j == lengthTarget - 1) {
                        // Target found, replace with replacement, and return result.
                        return result = replaceBytes(bytecode, replacement_, i);
                    }
                } else {
                    break;
                }
                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
        // Should always find one single match. -> revert if not.
        revert();
    }

    /**
     * @dev Reverts if startPosition + replacement.length is bigger as bytecode.length.
     */
    function replaceBytes(bytes memory bytecode, bytes memory replacement, uint256 startPosition)
        internal
        pure
        returns (bytes memory)
    {
        uint256 lengthReplacement = replacement.length;
        for (uint256 j; j < lengthReplacement;) {
            bytecode[startPosition + j] = replacement[j];

            unchecked {
                ++j;
            }
        }
        return bytecode;
    }
}
