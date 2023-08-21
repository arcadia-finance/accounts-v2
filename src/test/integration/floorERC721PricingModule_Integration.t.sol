/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test, Constants } from "../Base_IntegrationAndUnit.t.sol";
import { IPricingModule_UsdOnly } from "../../interfaces/IPricingModule_UsdOnly.sol";
import { FloorERC721PricingModule_UsdOnly } from "../../PricingModules/FloorERC721PricingModule_UsdOnly.sol";

contract FloorERC721PricingModule_Integration_Test is Base_IntegrationAndUnit_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function test_getValue() public {
        uint256 expectedValueInUsd = (rates.nft1ToToken1 * rates.token1ToUsd * Constants.WAD)
            / 10 ** (Constants.nftOracleDecimals + Constants.tokenOracleDecimals);

        IPricingModule_UsdOnly.GetValueInput memory getValueInput = IPricingModule_UsdOnly.GetValueInput({
            asset: address(mockERC721.nft1),
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
