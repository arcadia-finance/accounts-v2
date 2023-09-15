/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

import { FloorERC721PricingModule } from "../../../../pricing-modules/FloorERC721PricingModule.sol";

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
    function testFuzz_Success_deployment(address mainRegistry_, address oracleHub_, uint256 assetType_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(users.creatorAddress);
        FloorERC721PricingModule erc20PricingModule_ = new FloorERC721PricingModule(
            mainRegistry_,
            oracleHub_,
            assetType_
        );
        vm.stopPrank();

        assertEq(erc20PricingModule_.mainRegistry(), mainRegistry_);
        assertEq(erc20PricingModule_.oracleHub(), oracleHub_);
        assertEq(erc20PricingModule_.assetType(), assetType_);
        assertEq(erc20PricingModule_.riskManager(), users.creatorAddress);
    }
}
