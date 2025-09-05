/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Vm } from "../../lib/forge-std/src/Vm.sol";
import { IPermit2 } from "./Interfaces.sol";

library Utils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 public constant _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    function getPermitBatchTransferSignature(
        IPermit2.PermitBatchTransferFrom memory permit,
        uint256 privateKey,
        bytes32 domainSeparator,
        address spender
    ) public pure returns (bytes memory sig) {
        bytes32[] memory tokenPermissions = new bytes32[](permit.permitted.length);
        for (uint256 i = 0; i < permit.permitted.length; ++i) {
            tokenPermissions[i] = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted[i]));
        }
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                        keccak256(abi.encodePacked(tokenPermissions)),
                        spender,
                        permit.nonce,
                        permit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function defaultERC20PermitMultiple(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256 nonce,
        uint256 deadline_
    ) public pure returns (IPermit2.PermitBatchTransferFrom memory) {
        IPermit2.TokenPermissions[] memory permitted = new IPermit2.TokenPermissions[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            permitted[i] = IPermit2.TokenPermissions({ token: tokens[i], amount: amounts[i] });
        }
        return IPermit2.PermitBatchTransferFrom({ permitted: permitted, nonce: nonce, deadline: deadline_ });
    }

    /**
     * @notice Casts a static array of addresses of length two to a dynamic array of addresses.
     * @param staticArray The static array of addresses.
     * @return dynamicArray The dynamic array of addresses.
     */
    function castArrayStaticToDynamic(address[2] calldata staticArray)
        public
        pure
        returns (address[] memory dynamicArray)
    {
        uint256 length = staticArray.length;
        dynamicArray = new address[](length);

        for (uint256 i; i < length;) {
            dynamicArray[i] = staticArray[i];

            unchecked {
                ++i;
            }
        }
    }

    function castArrayStaticToDynamic(address[3] calldata staticArray)
        public
        pure
        returns (address[] memory dynamicArray)
    {
        uint256 length = staticArray.length;
        dynamicArray = new address[](length);

        for (uint256 i; i < length;) {
            dynamicArray[i] = staticArray[i];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Casts a static array of uint256's of length two to a dynamic array of uint256's.
     * @param staticArray The static array of uint256's.
     * @return dynamicArray The dynamic array of uint256's.
     */
    function castArrayStaticToDynamic(uint256[2] calldata staticArray)
        public
        pure
        returns (uint256[] memory dynamicArray)
    {
        uint256 length = staticArray.length;
        dynamicArray = new uint256[](length);

        for (uint256 i; i < length;) {
            dynamicArray[i] = staticArray[i];

            unchecked {
                ++i;
            }
        }
    }

    function castArrayStaticToDynamic(uint256[3] calldata staticArray)
        public
        pure
        returns (uint256[] memory dynamicArray)
    {
        uint256 length = staticArray.length;
        dynamicArray = new uint256[](length);

        for (uint256 i; i < length;) {
            dynamicArray[i] = staticArray[i];

            unchecked {
                ++i;
            }
        }
    }

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
        result = veryBadBytesReplacer(bytecode, abi.encodePacked(target), abi.encodePacked(replacement));
    }

    function veryBadBytesReplacer(bytes memory bytecode, bytes memory target, bytes memory replacement)
        internal
        pure
        returns (bytes memory result)
    {
        require(target.length <= bytecode.length);
        require(target.length == replacement.length);

        uint256 lengthTarget = target.length;
        uint256 lengthBytecode = bytecode.length - lengthTarget + 1;
        uint256 i;
        for (i; i < lengthBytecode;) {
            uint256 j = 0;
            for (j; j < lengthTarget;) {
                if (bytecode[i + j] == target[j]) {
                    if (j == lengthTarget - 1) {
                        // Target found, replace with replacement, and return result.
                        return result = replaceBytes(bytecode, replacement, i);
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

    function veryBadBytesReplacer(
        bytes memory bytecode,
        bytes memory target,
        bytes memory replacement,
        bool replaceFirstOnly
    ) internal pure returns (bytes memory) {
        require(target.length <= bytecode.length);
        require(target.length == replacement.length);

        uint256 lengthTarget = target.length;
        uint256 lengthBytecode = bytecode.length - lengthTarget + 1;
        for (uint256 i; i < lengthBytecode; ++i) {
            uint256 j = 0;
            for (j; j < lengthTarget; ++j) {
                if (bytecode[i + j] == target[j]) {
                    if (j == lengthTarget - 1) {
                        // Target found, replace with replacement.
                        bytecode = replaceBytes(bytecode, replacement, i);
                        if (replaceFirstOnly) return bytecode;
                    }
                } else {
                    break;
                }
            }
        }
        return bytecode;
    }

    /**
     * @dev Reverts if startPosition + replacement.length is bigger than bytecode.length.
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

    function commutativeKeccak256(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a);
    }

    function efficientKeccak256(bytes32 a, bytes32 b) internal pure returns (bytes32 value) {
        assembly ("memory-safe") {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
