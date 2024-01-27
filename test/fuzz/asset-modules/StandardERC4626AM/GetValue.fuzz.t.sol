/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StandardERC4626AM_Fuzz_Test } from "./_StandardERC4626AM.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

import { Constants } from "../../../utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "StandardERC4626AM".
 */
contract GetValue_StandardERC4626AM_Fuzz_Test is StandardERC4626AM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValue_Overflow(
        uint256 rateToken1ToUsd_,
        uint256 shares,
        uint256 totalSupply,
        uint256 totalAssets
    ) public {
        vm.assume(shares <= totalSupply);
        vm.assume(totalSupply > 0);
        vm.assume(totalAssets > 0);
        vm.assume(rateToken1ToUsd_ > 0);

        // No Overflow Registry
        vm.assume(rateToken1ToUsd_ <= type(uint256).max / Constants.WAD);
        // No Overflow ERC4626
        vm.assume(shares <= type(uint256).max / totalAssets);

        vm.assume(
            shares * totalAssets / totalSupply
                > type(uint256).max / (Constants.WAD * rateToken1ToUsd_ / 10 ** Constants.tokenOracleDecimals)
        );

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd_));

        vm.prank(users.creatorAddress);
        erc4626AM.addAsset(address(ybToken1));

        //Cheat totalSupply
        stdstore.target(address(ybToken1)).sig(ybToken1.totalSupply.selector).checked_write(totalSupply);

        //Cheat balance of
        stdstore.target(address(mockERC20.token1)).sig(ybToken1.balanceOf.selector).with_key(address(ybToken1))
            .checked_write(totalAssets);

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        erc4626AM.getValue(address(creditorUsd), address(ybToken1), 0, shares);
    }

    function testFuzz_Success_getValue(
        uint256 rateToken1ToUsd_,
        uint256 shares,
        uint256 totalSupply,
        uint256 totalAssets
    ) public {
        vm.assume(shares <= totalSupply);
        vm.assume(totalSupply > 0);

        // No Overflow Registry
        vm.assume(rateToken1ToUsd_ <= type(uint256).max / Constants.WAD / 1e18);
        // No Overflow ERC4626
        if (totalAssets > 0) {
            vm.assume(shares <= type(uint256).max / totalAssets);
        }
        // No Overflow

        if (rateToken1ToUsd_ != 0) {
            vm.assume(
                shares * totalAssets / totalSupply
                    <= type(uint256).max / (Constants.WAD * rateToken1ToUsd_ / 10 ** Constants.tokenOracleDecimals)
            );
        }

        uint256 expectedValueInUsd = (Constants.WAD * rateToken1ToUsd_ / 10 ** Constants.tokenOracleDecimals)
            * (shares * totalAssets / totalSupply) / 10 ** Constants.tokenDecimals;

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd_));

        vm.prank(users.creatorAddress);
        erc4626AM.addAsset(address(ybToken1));

        //Cheat totalSupply
        stdstore.target(address(ybToken1)).sig(ybToken1.totalSupply.selector).checked_write(totalSupply);

        //Cheat balance of
        stdstore.target(address(mockERC20.token1)).sig(ybToken1.balanceOf.selector).with_key(address(ybToken1))
            .checked_write(totalAssets);

        (uint256 actualValueInUsd,,) = erc4626AM.getValue(address(creditorUsd), address(ybToken1), 0, shares);

        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
