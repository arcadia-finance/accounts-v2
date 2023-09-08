/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "./Fuzz.t.sol";
import { IPricingModule_UsdOnly } from "../../interfaces/IPricingModule_UsdOnly.sol";
import { FloorERC721PricingModule_UsdOnly } from "../../pricing-modules/FloorERC721PricingModule_UsdOnly.sol";

contract FloorERC721PricingModule_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_getValue(uint96 rateNft1ToToken1, uint96 rateToken1ToUsd) public {
        // Does not test on overflow, test to check if function correctly returns value in Usd
        uint256 expectedValueInUsd = (uint256(rateNft1ToToken1) * uint256(rateToken1ToUsd) * Constants.WAD)
            / 10 ** (Constants.nftOracleDecimals + Constants.tokenOracleDecimals);

        vm.startPrank(users.defaultTransmitter);
        mockOracles.nft1ToToken1.transmit(int256(uint256(rateNft1ToToken1)));
        mockOracles.token1ToUsd.transmit(int256(uint256(rateToken1ToUsd)));
        vm.stopPrank();

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
