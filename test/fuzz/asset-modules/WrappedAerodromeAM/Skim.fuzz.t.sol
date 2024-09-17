/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Pool } from "../../../utils/mocks/Aerodrome/AeroPoolMock.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

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
        // Given : unprivileged address is not the owner of the AM.
        vm.assume(unprivilegedAddress != users.owner);

        // When : Calling skim().
        // Then : It should revert.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        wrappedAerodromeAM.skim(pool_);
    }

    function testFuzz_Revert_skim_NonExistingPool(address pool_) public {
        // When : Owner Calls skim() for non existing aeroPool.
        // Then : It should revert.
        vm.prank(users.owner);
        vm.expectRevert(WrappedAerodromeAM.PoolNotAllowed.selector);
        wrappedAerodromeAM.skim(pool_);
    }

    function testFuzz_Success_skim_ZeroTotalWrapped(
        bool stable,
        uint256 fee0,
        uint256 fee1,
        WrappedAerodromeAM.PoolState memory poolState,
        uint256 balanceOf
    ) public {
        // Given : Valid aeroPool
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);

        // And: totalWrapped is zero.
        poolState.totalWrapped = 0;

        // And: State is persisted.
        deal(address(aeroPool), address(wrappedAerodromeAM), balanceOf, true);
        wrappedAerodromeAM.setPoolState(address(aeroPool), poolState);
        (address token0, address token1) = aeroPool.tokens();
        wrappedAerodromeAM.setTokens(address(aeroPool), token0, token1);
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(aeroPool.token0(), aeroPool.poolFees(), fee0, true);
        deal(aeroPool.token1(), aeroPool.poolFees(), fee1, true);

        // When : Owner calls skim()
        vm.prank(users.owner);
        wrappedAerodromeAM.skim(address(aeroPool));

        // Then  Balance of the AM equals 0.
        assertEq(aeroPool.balanceOf(address(wrappedAerodromeAM)), 0);

        // And : Owner gets the excess aeroPool tokens.
        assertEq(aeroPool.balanceOf(users.owner), balanceOf);

        // And : The fees are send to the AM.
        assertEq(ERC20(aeroPool.token0()).balanceOf(address(wrappedAerodromeAM)), fee0);
        assertEq(ERC20(aeroPool.token1()).balanceOf(address(wrappedAerodromeAM)), fee1);

        // And : Pool values should be updated correctly
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedAerodromeAM.poolState(address(aeroPool));

        assertEq(poolState_.fee0PerLiquidity, poolState.fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, poolState.fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, 0);
    }

    function testFuzz_Success_skim_NonZeroTotalWrapped(
        bool stable,
        uint256 fee0,
        uint256 fee1,
        WrappedAerodromeAM.PoolState memory poolState,
        uint256 balanceOf
    ) public {
        // Given : Valid aeroPool
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);

        // And: totalWrapped is bigger than zero.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, type(uint128).max));

        // And: aeroPool balance of the AM is equal or bigger than totalWrapped (invariant).
        balanceOf = bound(balanceOf, poolState.totalWrapped, type(uint256).max);

        // And: deltaFeesPerLiquidity is smaller or equal as type(uint128).max (no overflow safeCastTo128).
        fee0 = bound(fee0, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // And: State is persisted.
        deal(address(aeroPool), address(wrappedAerodromeAM), balanceOf, true);
        wrappedAerodromeAM.setPoolState(address(aeroPool), poolState);
        (address token0, address token1) = aeroPool.tokens();
        wrappedAerodromeAM.setTokens(address(aeroPool), token0, token1);
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(aeroPool.token0(), aeroPool.poolFees(), fee0, true);
        deal(aeroPool.token1(), aeroPool.poolFees(), fee1, true);

        // When : Owner calls skim()
        vm.prank(users.owner);
        wrappedAerodromeAM.skim(address(aeroPool));

        // Then  Balance of the AM equals poolState.totalWrapped.
        assertEq(aeroPool.balanceOf(address(wrappedAerodromeAM)), poolState.totalWrapped);

        // And : Owner gets the excess aeroPool tokens.
        assertEq(aeroPool.balanceOf(users.owner), balanceOf - poolState.totalWrapped);

        // And : The fees are send to the AM.
        assertEq(ERC20(aeroPool.token0()).balanceOf(address(wrappedAerodromeAM)), fee0);
        assertEq(ERC20(aeroPool.token1()).balanceOf(address(wrappedAerodromeAM)), fee1);

        // And : Pool values should be updated correctly
        WrappedAerodromeAM.PoolState memory poolState_;
        (poolState_.fee0PerLiquidity, poolState_.fee1PerLiquidity, poolState_.totalWrapped) =
            wrappedAerodromeAM.poolState(address(aeroPool));

        uint128 fee0PerLiquidity;
        uint128 fee1PerLiquidity;
        unchecked {
            fee0PerLiquidity = poolState.fee0PerLiquidity + uint128(fee0.mulDivDown(1e18, poolState.totalWrapped));
            fee1PerLiquidity = poolState.fee1PerLiquidity + uint128(fee1.mulDivDown(1e18, poolState.totalWrapped));
        }
        assertEq(poolState_.fee0PerLiquidity, fee0PerLiquidity);
        assertEq(poolState_.fee1PerLiquidity, fee1PerLiquidity);
        assertEq(poolState_.totalWrapped, poolState.totalWrapped);
    }
}
