/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

import { IPricingModule } from "../../../../interfaces/IPricingModule.sol";

/**
 * @notice Fuzz tests for the "getValue" of contract "FloorERC721PricingModule".
 */
contract GetValue_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_getValue(uint96 rateNft1ToToken1, uint96 rateToken1ToUsd) public {
        // Does not test on overflow, test to check if function correctly returns value in Usd
        uint256 expectedValueInUsd = (uint256(rateNft1ToToken1) * uint256(rateToken1ToUsd) * Constants.WAD)
            / 10 ** (Constants.nftOracleDecimals + Constants.tokenOracleDecimals);

        vm.startPrank(users.defaultTransmitter);
        mockOracles.nft1ToToken1.transmit(int256(uint256(rateNft1ToToken1)));
        mockOracles.token1ToUsd.transmit(int256(uint256(rateToken1ToUsd)));
        vm.stopPrank();

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
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
