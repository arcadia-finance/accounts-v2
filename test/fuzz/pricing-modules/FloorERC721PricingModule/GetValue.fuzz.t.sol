/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

import { Constants } from "../../../utils/Constants.sol";
import { IPricingModule } from "../../../../src/interfaces/IPricingModule.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "FloorERC721PricingModule".
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
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, type(uint128).max, 0, 0
        );
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getValue(uint256 rateNft2ToUsd, uint256 assetId, uint256 amount) public {
        // No overflow OracleHub.
        rateNft2ToUsd = bound(rateNft2ToUsd, 0, type(uint256).max / Constants.WAD);

        // No overflow valueInUsd.
        if (rateNft2ToUsd != 0) amount = bound(amount, 0, type(uint256).max / Constants.WAD / rateNft2ToUsd);

        uint256 expectedValueInUsd = Constants.WAD * rateNft2ToUsd / 10 ** Constants.nftOracleDecimals * amount;

        vm.prank(users.defaultTransmitter);
        mockOracles.nft2ToUsd.transmit(int256(rateNft2ToUsd));

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(mockERC721.nft2),
            assetId: assetId,
            assetAmount: amount,
            baseCurrency: UsdBaseCurrencyID,
            creditor: address(creditorUsd)
        });
        // When: getValue called
        (uint256 actualValueInUsd,,) = floorERC721PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd
        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
