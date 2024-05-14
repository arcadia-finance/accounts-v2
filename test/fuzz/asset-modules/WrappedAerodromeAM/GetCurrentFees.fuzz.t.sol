/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { Pool } from "../../../utils/fixtures/aerodrome/AeroPoolFixture.f.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

/**
 * @notice Fuzz tests for the function "_getCurrentFees" of contract "WrappedAerodromeAM".
 */
contract GetCurrentFees_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    struct PoolFeeState {
        uint256 index0;
        uint256 index1;
        uint256 supplyIndex0;
        uint256 supplyIndex1;
        uint256 claimable0;
        uint256 claimable1;
        uint256 balanceOf;
    }

    function givenValidPoolFeeState(PoolFeeState memory poolFeeState) public view returns (PoolFeeState memory) {
        poolFeeState.supplyIndex0 = bound(poolFeeState.supplyIndex0, 0, poolFeeState.index0);
        poolFeeState.supplyIndex1 = bound(poolFeeState.supplyIndex1, 0, poolFeeState.index1);
        uint256 delta0 = poolFeeState.index0 - poolFeeState.supplyIndex0;
        uint256 delta1 = poolFeeState.index1 - poolFeeState.supplyIndex1;

        if (delta0 > 0) poolFeeState.balanceOf = bound(poolFeeState.balanceOf, 0, type(uint256).max / delta0);
        if (delta1 > 0) poolFeeState.balanceOf = bound(poolFeeState.balanceOf, 0, type(uint256).max / delta1);
        uint256 share0 = poolFeeState.balanceOf * delta0 / 1e18;
        uint256 share1 = poolFeeState.balanceOf * delta1 / 1e18;

        poolFeeState.claimable0 = bound(poolFeeState.claimable0, 0, type(uint256).max - share0);
        poolFeeState.claimable1 = bound(poolFeeState.claimable1, 0, type(uint256).max - share1);

        return poolFeeState;
    }

    function setPoolFeeState(PoolFeeState memory poolFeeState) public {
        pool.setPoolFeeState(
            address(wrappedAerodromeAM),
            poolFeeState.index0,
            poolFeeState.index1,
            poolFeeState.supplyIndex0,
            poolFeeState.supplyIndex1,
            poolFeeState.claimable0,
            poolFeeState.claimable1,
            poolFeeState.balanceOf
        );
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_totalWrapped_NonZeroWrapped_ExcessBalanceOf(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        PoolFeeState memory poolFeeState
    ) public {
        // Given : Valid pool.
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));

        // And : Valid pool fees.
        poolFeeState = givenValidPoolFeeState(poolFeeState);

        // And : totalWrapped is bigger than 0.
        // And : totalWrapped is smaller or equal than balanceOf (invariant).
        vm.assume(poolFeeState.balanceOf > 0);
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, poolFeeState.balanceOf));

        // And : State is persisted.
        setPoolFeeState(poolFeeState);
        wrappedAerodromeAM.setPoolState(address(pool), poolState);

        // When : Calling _getCurrentFees.
        (uint256 fee0, uint256 fee1) = wrappedAerodromeAM.getCurrentFees(address(pool));

        // Then : Correct fee amounts are returned.
        uint256 fee0_ =
            poolFeeState.claimable0 + poolState.totalWrapped * (poolFeeState.index0 - poolFeeState.supplyIndex0) / 1e18;
        uint256 fee1_ =
            poolFeeState.claimable1 + poolState.totalWrapped * (poolFeeState.index1 - poolFeeState.supplyIndex1) / 1e18;
        assertEq(fee0, fee0_);
        assertEq(fee1, fee1_);

        // And : this is equal or smaller than the actual returned fees.
        deal(pool.token0(), pool.poolFees(), type(uint256).max, true);
        deal(pool.token1(), pool.poolFees(), type(uint256).max, true);
        (uint256 fee0__, uint256 fee1__) = wrappedAerodromeAM.claimFees(address(pool));
        assertLe(fee0, fee0__);
        assertLe(fee1, fee1__);
    }

    function testFuzz_Success_totalWrapped_NonZeroWrapped_ExactBalanceOf(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        PoolFeeState memory poolFeeState
    ) public {
        // Given : Valid pool.
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));

        // And : Valid pool fees.
        poolFeeState = givenValidPoolFeeState(poolFeeState);

        // And : totalWrapped is bigger than 0.
        // And : totalWrapped is equal to balanceOf.
        vm.assume(poolFeeState.balanceOf > 0);
        poolFeeState.balanceOf = bound(poolFeeState.balanceOf, 1, type(uint128).max);
        poolState.totalWrapped = uint128(poolFeeState.balanceOf);

        // And : State is persisted.
        setPoolFeeState(poolFeeState);
        wrappedAerodromeAM.setPoolState(address(pool), poolState);

        // When : Calling _getCurrentFees.
        (uint256 fee0, uint256 fee1) = wrappedAerodromeAM.getCurrentFees(address(pool));

        // Then : Correct fee amounts are returned.
        uint256 fee0_ =
            poolFeeState.claimable0 + poolState.totalWrapped * (poolFeeState.index0 - poolFeeState.supplyIndex0) / 1e18;
        uint256 fee1_ =
            poolFeeState.claimable1 + poolState.totalWrapped * (poolFeeState.index1 - poolFeeState.supplyIndex1) / 1e18;
        assertEq(fee0, fee0_);
        assertEq(fee1, fee1_);

        // And : this is equal or smaller than the actual returned fees.
        deal(pool.token0(), pool.poolFees(), type(uint256).max, true);
        deal(pool.token1(), pool.poolFees(), type(uint256).max, true);
        (uint256 fee0__, uint256 fee1__) = wrappedAerodromeAM.claimFees(address(pool));
        assertEq(fee0, fee0__);
        assertEq(fee1, fee1__);
    }

    function testFuzz_Success_totalWrapped_ZeroWrapped(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        PoolFeeState memory poolFeeState
    ) public {
        // Given : Valid pool.
        pool = Pool(poolFactory.createPool(address(asset0), address(asset1), stable));

        // And : Valid pool fees.
        poolFeeState = givenValidPoolFeeState(poolFeeState);

        // And : totalWrapped is 0.
        poolState.totalWrapped = 0;

        // And : State is persisted.
        setPoolFeeState(poolFeeState);
        wrappedAerodromeAM.setPoolState(address(pool), poolState);

        // When : Calling _getCurrentFees.
        (uint256 fee0, uint256 fee1) = wrappedAerodromeAM.getCurrentFees(address(pool));

        // Then : Correct fee amounts are returned.
        assertEq(fee0, 0);
        assertEq(fee1, 0);

        // And : this is equal or smaller than the actual returned fees.
        deal(pool.token0(), pool.poolFees(), type(uint256).max, true);
        deal(pool.token1(), pool.poolFees(), type(uint256).max, true);
        (uint256 fee0__, uint256 fee1__) = wrappedAerodromeAM.claimFees(address(pool));
        assertLe(fee0, fee0__);
        assertLe(fee1, fee1__);
    }
}
