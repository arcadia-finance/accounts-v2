/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

import { FloorERC721PricingModule } from "../../../../src/pricing-modules/FloorERC721PricingModule.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "FloorERC721PricingModule".
 */
contract Constructor_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address mainRegistry_, address oracleHub_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(users.creatorAddress);
        FloorERC721PricingModule erc721PricingModule_ = new FloorERC721PricingModule(
            mainRegistry_,
            oracleHub_);
        vm.stopPrank();

        assertEq(erc721PricingModule_.MAIN_REGISTRY(), mainRegistry_);
        assertEq(erc721PricingModule_.ORACLE_HUB(), oracleHub_);
        assertEq(erc721PricingModule_.ASSET_TYPE(), 1);
        assertEq(erc721PricingModule_.riskManager(), users.creatorAddress);
    }
}
