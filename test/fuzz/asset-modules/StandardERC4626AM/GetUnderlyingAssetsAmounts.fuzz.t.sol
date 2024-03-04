/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StandardERC4626AM_Fuzz_Test } from "./_StandardERC4626AM.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts()" of contract "StandardERC4626AM".
 */
contract GetUnderlyingAssetsAmounts_StandardERC4626AM_Fuzz_Test is StandardERC4626AM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626AM_Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        erc4626AM.addAsset(address(ybToken1));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getUnderlyingAssetsAmounts(uint256 shares, uint256 totalSupply, uint256 totalAssets)
        public
    {
        // Given: userBalance is smaller than total amount of shares (invariant ERC20).
        shares = bound(shares, 0, totalSupply);

        // And: "convertToAssets()" does not overflow.
        if (shares > 0) totalAssets = bound(totalAssets, 0, type(uint256).max / shares);

        // And: state is persisted.
        //Cheat totalSupply
        stdstore.target(address(ybToken1)).sig(ybToken1.totalSupply.selector).checked_write(totalSupply);
        //Cheat balance of
        stdstore.target(address(mockERC20.token1)).sig(ybToken1.balanceOf.selector).with_key(address(ybToken1))
            .checked_write(totalAssets);

        // When: "_getUnderlyingAssetsAmounts" is called with 'shares'.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(ybToken1)));
        bytes32[] memory emptyArray = new bytes32[](1);
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            erc4626AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, shares, emptyArray);

        // Then: The correct underlyingAssetsAmount is returned.
        uint256 expectedUnderlyingAssetsAmount = totalSupply > 0 ? shares * totalAssets / totalSupply : 0;
        assertEq(underlyingAssetsAmounts[0], expectedUnderlyingAssetsAmount);

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }
}
