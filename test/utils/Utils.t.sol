/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Utils } from "./Utils.sol";
import { Test } from "../../lib/forge-std/src/Test.sol";

contract Utils_Test is Test {
    function setUp() public { }

    function test_Revert_veryBadBytesReplacer_Short() public {
        bytes memory bytecode = hex"4fe34f199b19b2b4f47f68442619d555527d244f78a3297ea8";
        bytes32 target = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytes32 replacement = 0x100000000000000000000000000000000000000000000000000000000000000f;

        vm.expectRevert();
        Utils.veryBadBytesReplacer(bytecode, target, replacement);
    }

    function test_Revert_veryBadBytesReplacer_NoMatch() public {
        bytes memory bytecode = hex"e34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b55";
        bytes32 target = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytes32 replacement = 0x100000000000000000000000000000000000000000000000000000000000000f;

        vm.expectRevert();
        Utils.veryBadBytesReplacer(bytecode, target, replacement);
    }

    function test_Success_veryBadBytesReplacer_FirstByte() public {
        bytes memory bytecode = hex"e34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b544f4f";
        bytes32 target = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytes32 replacement = 0x100000000000000000000000000000000000000000000000000000000000000f;

        bytes memory expectedResult = hex"100000000000000000000000000000000000000000000000000000000000000f4f4f";

        bytes memory actualResult = Utils.veryBadBytesReplacer(bytecode, target, replacement);
        assertEq(actualResult, expectedResult);
    }

    function test_Success_veryBadBytesReplacer_LastByte() public {
        bytes memory bytecode = hex"4f4fe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54";
        bytes32 target = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytes32 replacement = 0x100000000000000000000000000000000000000000000000000000000000000f;

        bytes memory expectedResult = hex"4f4f100000000000000000000000000000000000000000000000000000000000000f";

        bytes memory actualResult = Utils.veryBadBytesReplacer(bytecode, target, replacement);
        assertEq(actualResult, expectedResult);
    }

    function test_Success_veryBadBytesReplacer_MiddleByte() public {
        bytes memory bytecode = hex"4fe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b544f";
        bytes32 target = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytes32 replacement = 0x100000000000000000000000000000000000000000000000000000000000000f;

        bytes memory expectedResult = hex"4f100000000000000000000000000000000000000000000000000000000000000f4f";

        bytes memory actualResult = Utils.veryBadBytesReplacer(bytecode, target, replacement);
        assertEq(actualResult, expectedResult);
    }
}
