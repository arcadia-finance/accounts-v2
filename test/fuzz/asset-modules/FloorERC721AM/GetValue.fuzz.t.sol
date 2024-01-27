/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FloorERC721AM_Fuzz_Test } from "./_FloorERC721AM.fuzz.t.sol";

import { Constants } from "../../../utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "FloorERC721AM".
 */
contract GetValue_FloorERC721AM_Fuzz_Test is FloorERC721AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721AM_Fuzz_Test.setUp();

        // Add Nft2 (which has an oracle directly to usd).
        vm.prank(users.creatorAddress);
        floorERC721AM.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, type(uint112).max, 0, 0
        );
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValue_Overflow(uint256 rateNft2ToUsd, uint256 assetId, uint256 amount) public {
        // No overflow Registry.
        rateNft2ToUsd = bound(rateNft2ToUsd, 1, type(uint256).max / 10 ** (36 - Constants.nftOracleDecimals));

        // Overflow valueInUsd Asset Module (test-case).
        amount = bound(
            amount, type(uint256).max / rateNft2ToUsd / 10 ** (18 - Constants.nftOracleDecimals) + 1, type(uint256).max
        );

        vm.prank(users.defaultTransmitter);
        mockOracles.nft2ToUsd.transmit(int256(rateNft2ToUsd));

        vm.expectRevert(bytes(""));
        floorERC721AM.getValue(address(creditorUsd), address(mockERC721.nft2), assetId, amount);
    }

    function testFuzz_Success_getValue(uint256 rateNft2ToUsd, uint256 assetId, uint256 amount) public {
        // No overflow Registry.
        rateNft2ToUsd = bound(rateNft2ToUsd, 0, type(uint256).max / 10 ** (36 - Constants.nftOracleDecimals));

        // No overflow valueInUsd in Asset Module.
        if (rateNft2ToUsd != 0) {
            amount = bound(amount, 0, type(uint256).max / rateNft2ToUsd / 10 ** (18 - Constants.nftOracleDecimals));
        }

        uint256 expectedValueInUsd = amount * rateNft2ToUsd * 10 ** (18 - Constants.nftOracleDecimals);

        vm.prank(users.defaultTransmitter);
        mockOracles.nft2ToUsd.transmit(int256(rateNft2ToUsd));

        // When: getValue called
        (uint256 actualValueInUsd,,) =
            floorERC721AM.getValue(address(creditorUsd), address(mockERC721.nft2), assetId, amount);

        // Then: actualValueInUsd should be equal to expectedValueInUsd
        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
