/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "skim" of contract "WrappedMetadex03AM".
 */
contract Skim_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_skim_NotOwner(address unprivilegedAddress, address pool_) public {
        // Given: The unprivileged address is not the owner of the Asset Module.
        vm.assume(unprivilegedAddress != users.owner);

        // When: An arbitrary pool is skimmed.
        // Then: It reverts.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        wrappedMetadex03AM.skim(pool_);
    }

    function testFuzz_Revert_skim_NonExistingPool(address pool_) public {
        // Given: A pool that is not added as an asset.

        // When: The pool is skimmed.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(WrappedAerodromeAM.PoolNotAllowed.selector);
        wrappedMetadex03AM.skim(pool_);
    }

    function testFuzz_Success_skim_NonZeroTotalWrapped(
        bool stable,
        uint256 fee0,
        uint256 fee1,
        WrappedAerodromeAM.PoolState memory poolState,
        uint256 balanceOf
    ) public {
        // Given: A pool that is added as an asset with a non-zero wrapped total.
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        vm.assume(poolState.totalWrapped != 0);
        wrappedMetadex03AM.setPoolState(address(metadex03Pool), poolState);
        (address token0, address token1) = metadex03Pool.tokens();
        wrappedMetadex03AM.setTokens(address(metadex03Pool), token0, token1);

        // And: The Asset Module holds at least the wrapped total.
        balanceOf = bound(balanceOf, poolState.totalWrapped, type(uint256).max);
        deal(address(metadex03Pool), address(wrappedMetadex03AM), balanceOf, true);

        // And: The pool accrued fees that fit in the fee accumulators.
        fee0 = bound(fee0, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        setClaimables(metadex03Pool, address(wrappedMetadex03AM), fee0, fee1);
        deal(metadex03Pool.token0(), metadex03Pool.poolFees(), fee0, true);
        deal(metadex03Pool.token1(), metadex03Pool.poolFees(), fee1, true);

        // When: The pool is skimmed.
        vm.prank(users.owner);
        wrappedMetadex03AM.skim(address(metadex03Pool));

        // Then: The Asset Module keeps exactly the wrapped total.
        assertEq(metadex03Pool.balanceOf(address(wrappedMetadex03AM)), poolState.totalWrapped);

        // And: The owner receives the surplus pool tokens.
        assertEq(metadex03Pool.balanceOf(users.owner), balanceOf - poolState.totalWrapped);

        // And: The claimed pool fees sit in the Asset Module.
        assertEq(ERC20(metadex03Pool.token0()).balanceOf(address(wrappedMetadex03AM)), fee0);
        assertEq(ERC20(metadex03Pool.token1()).balanceOf(address(wrappedMetadex03AM)), fee1);

        // And: The pool accumulators advanced and the wrapped total is unchanged.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedMetadex03AM.poolState(address(metadex03Pool));

        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        unchecked {
            // forge-lint: disable-next-item(unsafe-typecast)
            fee0PerLiquidity = poolState.fee0PerLiquidity + uint128(fee0.mulDivDown(1e18, poolState.totalWrapped));
            // forge-lint: disable-next-item(unsafe-typecast)
            fee1PerLiquidity = poolState.fee1PerLiquidity + uint128(fee1.mulDivDown(1e18, poolState.totalWrapped));
        }
        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped);
    }

    function testFuzz_Success_skim_ZeroTotalWrapped(
        bool stable,
        uint256 fee0,
        uint256 fee1,
        WrappedAerodromeAM.PoolState memory poolState,
        uint256 balanceOf
    ) public {
        // Given: A pool that is added as an asset with a zero wrapped total.
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        poolState.totalWrapped = 0;
        wrappedMetadex03AM.setPoolState(address(metadex03Pool), poolState);
        (address token0, address token1) = metadex03Pool.tokens();
        wrappedMetadex03AM.setTokens(address(metadex03Pool), token0, token1);

        // And: The Asset Module holds pool tokens that nobody wrapped.
        deal(address(metadex03Pool), address(wrappedMetadex03AM), balanceOf, true);

        // And: The pool accrued fees.
        setClaimables(metadex03Pool, address(wrappedMetadex03AM), fee0, fee1);
        deal(metadex03Pool.token0(), metadex03Pool.poolFees(), fee0, true);
        deal(metadex03Pool.token1(), metadex03Pool.poolFees(), fee1, true);

        // When: The pool is skimmed.
        vm.prank(users.owner);
        wrappedMetadex03AM.skim(address(metadex03Pool));

        // Then: The Asset Module keeps no pool tokens.
        assertEq(metadex03Pool.balanceOf(address(wrappedMetadex03AM)), 0);

        // And: The owner receives every pool token.
        assertEq(metadex03Pool.balanceOf(users.owner), balanceOf);

        // And: The claimed pool fees sit in the Asset Module.
        assertEq(ERC20(metadex03Pool.token0()).balanceOf(address(wrappedMetadex03AM)), fee0);
        assertEq(ERC20(metadex03Pool.token1()).balanceOf(address(wrappedMetadex03AM)), fee1);

        // And: The pool accumulators did not advance.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedMetadex03AM.poolState(address(metadex03Pool));

        assertEq(poolState_.fee0PerLiquidity, poolState.fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, poolState.fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, 0);
    }
}
