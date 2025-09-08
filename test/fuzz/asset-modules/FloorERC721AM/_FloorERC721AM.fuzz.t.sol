/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Common logic needed by all "FloorERC721AM" fuzz tests.
 */
abstract contract FloorERC721AM_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    bytes32 internal oraclesNft2ToUsd;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.owner);
        chainlinkOM.addOracle(address(mockOracles.nft2ToUsd), "NFT2", "USD", 2 days);

        uint80[] memory oracleNft2ToUsdArr = new uint80[](1);
        oracleNft2ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.nft2ToUsd)));
        oraclesNft2ToUsd = BitPackingLib.pack(BA_TO_QA_SINGLE, oracleNft2ToUsdArr);
    }
}
