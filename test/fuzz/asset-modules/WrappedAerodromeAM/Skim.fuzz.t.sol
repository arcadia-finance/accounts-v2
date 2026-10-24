/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "skim" of contract "WrappedAerodromeAM".
 */
contract Skim_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
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
        wrappedAerodromeAM.skim(pool_);
    }

    function testFuzz_Revert_skim_NonExistingPool(address pool_) public {
        // Given: A pool that is not added as an asset.

        // When: The pool is skimmed.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(WrappedAerodromeAM.PoolNotAllowed.selector);
        wrappedAerodromeAM.skim(pool_);
    }

    function testFuzz_Success_skim_NonZeroTotalWrapped(
        bool stable,
        uint256 fee0,
        uint256 fee1,
        WrappedAerodromeAM.PoolState memory poolState,
        uint256 balanceOf
    ) public {
        // Given: A pool that is added as an asset with a non-zero wrapped total.
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);
        vm.assume(poolState.totalWrapped != 0);
        wrappedAerodromeAM.setPoolState(address(aeroPool), poolState);
        (address token0, address token1) = aeroPool.tokens();
        wrappedAerodromeAM.setTokens(address(aeroPool), token0, token1);

        // And: The Asset Module holds at least the wrapped total.
        balanceOf = bound(balanceOf, poolState.totalWrapped, type(uint256).max);
        deal(address(aeroPool), address(wrappedAerodromeAM), balanceOf, true);

        // And: The pool accrued fees that fit in the fee accumulators.
        fee0 = bound(fee0, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(aeroPool.token0(), aeroPool.poolFees(), fee0, true);
        deal(aeroPool.token1(), aeroPool.poolFees(), fee1, true);

        // When: The pool is skimmed.
        vm.prank(users.owner);
        wrappedAerodromeAM.skim(address(aeroPool));

        // Then: The Asset Module keeps exactly the wrapped total.
        assertEq(aeroPool.balanceOf(address(wrappedAerodromeAM)), poolState.totalWrapped);

        // And: The owner receives the surplus pool tokens.
        assertEq(aeroPool.balanceOf(users.owner), balanceOf - poolState.totalWrapped);

        // And: The claimed pool fees sit in the Asset Module.
        assertEq(ERC20(aeroPool.token0()).balanceOf(address(wrappedAerodromeAM)), fee0);
        assertEq(ERC20(aeroPool.token1()).balanceOf(address(wrappedAerodromeAM)), fee1);

        // And: The pool accumulators advanced and the wrapped total is unchanged.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedAerodromeAM.poolState(address(aeroPool));

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
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);
        poolState.totalWrapped = 0;
        wrappedAerodromeAM.setPoolState(address(aeroPool), poolState);
        (address token0, address token1) = aeroPool.tokens();
        wrappedAerodromeAM.setTokens(address(aeroPool), token0, token1);

        // And: The Asset Module holds pool tokens that nobody wrapped.
        deal(address(aeroPool), address(wrappedAerodromeAM), balanceOf, true);

        // And: The pool accrued fees.
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(aeroPool.token0(), aeroPool.poolFees(), fee0, true);
        deal(aeroPool.token1(), aeroPool.poolFees(), fee1, true);

        // When: The pool is skimmed.
        vm.prank(users.owner);
        wrappedAerodromeAM.skim(address(aeroPool));

        // Then: The Asset Module keeps no pool tokens.
        assertEq(aeroPool.balanceOf(address(wrappedAerodromeAM)), 0);

        // And: The owner receives every pool token.
        assertEq(aeroPool.balanceOf(users.owner), balanceOf);

        // And: The claimed pool fees sit in the Asset Module.
        assertEq(ERC20(aeroPool.token0()).balanceOf(address(wrappedAerodromeAM)), fee0);
        assertEq(ERC20(aeroPool.token1()).balanceOf(address(wrappedAerodromeAM)), fee1);

        // And: The pool accumulators did not advance.
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedAerodromeAM.poolState(address(aeroPool));

        assertEq(poolState_.fee0PerLiquidity, poolState.fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, poolState.fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, 0);
    }
}
