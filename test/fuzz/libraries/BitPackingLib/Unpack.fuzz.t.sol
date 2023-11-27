/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { BitPackingLib_Fuzz_Test } from "./_BitPackingLib.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "unpack" of contract "BitPackingLib".
 */
contract Unpack_BitPackingLib_Fuzz_Test is BitPackingLib_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        BitPackingLib_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_unpack(uint256 length, bool[3] memory baseToQuoteAsset, uint80[3] memory oracles)
        public
    {
        length = bound(length, 1, 3);
        bool[] memory directions_ = new bool[](length);
        uint80[] memory oracles_ = new uint80[](length);
        for (uint256 i; i < length; ++i) {
            directions_[i] = baseToQuoteAsset[i];
            oracles_[i] = oracles[i];
        }

        bytes32 oracleSequence = bitPackingLib.pack(directions_, oracles_);
        (bool[] memory actualDirections, uint256[] memory actualOracles) = bitPackingLib.unpack(oracleSequence);

        for (uint256 i; i < length; ++i) {
            assertEq(actualDirections[i], baseToQuoteAsset[i]);
            assertEq(actualOracles[i], oracles[i]);
        }
    }
}
