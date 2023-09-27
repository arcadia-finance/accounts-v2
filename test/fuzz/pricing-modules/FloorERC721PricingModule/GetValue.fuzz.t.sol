/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

import { IPricingModule_New } from "../../../../src/interfaces/IPricingModule_New.sol";

/**
 * @notice Fuzz tests for the "getValue" of contract "FloorERC721PricingModule".
 */
contract GetValue_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();

        // Add Nft2 (which has an oracle directly to usd).
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput_New, type(uint128).max
        );
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getValue(uint256 rateNft2ToUsd) public {
        // No overflow OracleHub.
        vm.assume(rateNft2ToUsd <= type(uint256).max / Constants.WAD);

        uint256 expectedValueInUsd = Constants.WAD * rateNft2ToUsd / 10 ** Constants.nftOracleDecimals;

        vm.prank(users.defaultTransmitter);
        mockOracles.nft2ToUsd.transmit(int256(rateNft2ToUsd));

        IPricingModule_New.GetValueInput memory getValueInput = IPricingModule_New.GetValueInput({
            asset: address(mockERC721.nft2),
            assetId: 0,
            assetAmount: 1,
            baseCurrency: UsdBaseCurrencyID
        });
        // When: getValue called
        (uint256 actualValueInUsd,,) = floorERC721PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd
        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
