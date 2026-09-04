/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StandardERC4626AM_Fuzz_Test } from "./_StandardERC4626AM.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

import { Constants } from "../../../utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "StandardERC4626AM".
 */
// forge-lint: disable-next-item(divide-before-multiply,unsafe-typecast)
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
        totalSupply = bound(totalSupply, 1, type(uint256).max);
        totalAssets = bound(totalAssets, 1, type(uint256).max);
        // A single holder can never hold more than totalSupply, and no Overflow ERC4626.
        uint256 maxShares = type(uint256).max / totalAssets;
        if (totalSupply < maxShares) maxShares = totalSupply;
        shares = bound(shares, 1, maxShares);

        // And: The usd value of the shares overflows (test-case), and no Overflow Registry.
        uint256 assetValue = shares * totalAssets / totalSupply;
        vm.assume(assetValue > 0);
        uint256 minRate = type(uint256).max / assetValue / (Constants.WAD / 10 ** Constants.TOKEN_ORACLE_DECIMALS) + 1;
        vm.assume(minRate <= type(uint256).max / Constants.WAD);
        rateToken1ToUsd_ = bound(rateToken1ToUsd_, minRate, type(uint256).max / Constants.WAD);

        vm.prank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd_));

        vm.prank(users.owner);
        erc4626AM.addAsset(address(ybToken1));

        //Cheat totalSupply
        stdstore.target(address(ybToken1)).sig(ybToken1.totalSupply.selector).checked_write(totalSupply);

        //Cheat balance of
        stdstore.target(address(mockERC20.token1))
            .sig(ybToken1.balanceOf.selector)
            .with_key(address(ybToken1))
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
        totalSupply = bound(totalSupply, 1, type(uint256).max);

        // No Overflow Registry
        rateToken1ToUsd_ = bound(rateToken1ToUsd_, 0, type(uint256).max / Constants.WAD / 1e18);
        // A single holder can never hold more than totalSupply, and no Overflow ERC4626.
        uint256 maxShares = totalSupply;
        if (totalAssets > 0 && type(uint256).max / totalAssets < maxShares) {
            maxShares = type(uint256).max / totalAssets;
        }
        shares = bound(shares, 0, maxShares);

        // And: The usd value of the shares does not overflow.
        uint256 assetValue = shares * totalAssets / totalSupply;
        if (assetValue > 0) {
            uint256 maxRate = type(uint256).max / assetValue / (Constants.WAD / 10 ** Constants.TOKEN_ORACLE_DECIMALS);
            uint256 maxRateRegistry = type(uint256).max / Constants.WAD / 1e18;
            rateToken1ToUsd_ = bound(rateToken1ToUsd_, 0, maxRate < maxRateRegistry ? maxRate : maxRateRegistry);
        }

        uint256 expectedValueInUsd = (Constants.WAD * rateToken1ToUsd_ / 10 ** Constants.TOKEN_ORACLE_DECIMALS)
            * (shares * totalAssets / totalSupply) / 10 ** Constants.TOKEN_DECIMALS;

        vm.prank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd_));

        vm.prank(users.owner);
        erc4626AM.addAsset(address(ybToken1));

        //Cheat totalSupply
        stdstore.target(address(ybToken1)).sig(ybToken1.totalSupply.selector).checked_write(totalSupply);

        //Cheat balance of
        stdstore.target(address(mockERC20.token1))
            .sig(ybToken1.balanceOf.selector)
            .with_key(address(ybToken1))
            .checked_write(totalAssets);

        (uint256 actualValueInUsd,,) = erc4626AM.getValue(address(creditorUsd), address(ybToken1), 0, shares);

        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
