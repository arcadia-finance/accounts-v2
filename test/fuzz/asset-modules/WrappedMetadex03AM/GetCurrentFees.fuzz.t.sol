/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getCurrentFees" of contract "WrappedMetadex03AM".
 */
contract GetCurrentFees_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    using stdStorage for StdStorage;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
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

    function givenValidPoolFeeState(PoolFeeState memory poolFeeState) public pure returns (PoolFeeState memory) {
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
        deal(address(metadex03Pool), address(wrappedMetadex03AM), poolFeeState.balanceOf, true);
        stdstore.target(address(metadex03Pool)).sig(metadex03Pool.index0.selector).checked_write(poolFeeState.index0);
        stdstore.target(address(metadex03Pool)).sig(metadex03Pool.index1.selector).checked_write(poolFeeState.index1);
        stdstore.target(address(metadex03Pool))
            .sig(metadex03Pool.supplyIndex0.selector)
            .with_key(address(wrappedMetadex03AM))
            .checked_write(poolFeeState.supplyIndex0);
        stdstore.target(address(metadex03Pool))
            .sig(metadex03Pool.supplyIndex1.selector)
            .with_key(address(wrappedMetadex03AM))
            .checked_write(poolFeeState.supplyIndex1);
        setClaimables(metadex03Pool, address(wrappedMetadex03AM), poolFeeState.claimable0, poolFeeState.claimable1);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_getCurrentFees_NonZeroWrapped_ExcessBalanceOf(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        PoolFeeState memory poolFeeState
    ) public {
        // Given: A pool with a valid fee state.
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        poolFeeState = givenValidPoolFeeState(poolFeeState);

        // And: The wrapped total is non-zero and below the pool balance of the Asset Module.
        vm.assume(poolFeeState.balanceOf != 0);
        uint256 maxWrapped = poolFeeState.balanceOf < type(uint128).max ? poolFeeState.balanceOf : type(uint128).max;
        // forge-lint: disable-next-item(unsafe-typecast)
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, maxWrapped));

        // And: That state is persisted.
        setPoolFeeState(poolFeeState);
        wrappedMetadex03AM.setPoolState(address(metadex03Pool), poolState);

        // When: The current fees of the pool are read.
        (uint256 fee0, uint256 fee1) = wrappedMetadex03AM.getCurrentFees(address(metadex03Pool));

        // Then: The fees are the claimable balance plus the index growth over the wrapped total.
        uint256 expectedFee0 =
            poolFeeState.claimable0 + poolState.totalWrapped * (poolFeeState.index0 - poolFeeState.supplyIndex0) / 1e18;
        uint256 expectedFee1 =
            poolFeeState.claimable1 + poolState.totalWrapped * (poolFeeState.index1 - poolFeeState.supplyIndex1) / 1e18;
        assertEq(fee0, expectedFee0);
        assertEq(fee1, expectedFee1);

        // And: They never exceed what the pool actually pays out.
        deal(metadex03Pool.token0(), metadex03Pool.poolFees(), type(uint256).max, true);
        deal(metadex03Pool.token1(), metadex03Pool.poolFees(), type(uint256).max, true);
        (uint256 claimedFee0, uint256 claimedFee1) = wrappedMetadex03AM.claimFees(address(metadex03Pool));
        assertLe(fee0, claimedFee0);
        assertLe(fee1, claimedFee1);
    }

    function testFuzz_Success_getCurrentFees_NonZeroWrapped_ExactBalanceOf(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        PoolFeeState memory poolFeeState
    ) public {
        // Given: A pool with a valid fee state.
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        poolFeeState = givenValidPoolFeeState(poolFeeState);

        // And: The wrapped total equals the pool balance of the Asset Module.
        vm.assume(poolFeeState.balanceOf != 0);
        poolFeeState.balanceOf = bound(poolFeeState.balanceOf, 1, type(uint128).max);
        // forge-lint: disable-next-item(unsafe-typecast)
        poolState.totalWrapped = uint128(poolFeeState.balanceOf);

        // And: That state is persisted.
        setPoolFeeState(poolFeeState);
        wrappedMetadex03AM.setPoolState(address(metadex03Pool), poolState);

        // When: The current fees of the pool are read.
        (uint256 fee0, uint256 fee1) = wrappedMetadex03AM.getCurrentFees(address(metadex03Pool));

        // Then: The fees are the claimable balance plus the index growth over the wrapped total.
        uint256 expectedFee0 =
            poolFeeState.claimable0 + poolState.totalWrapped * (poolFeeState.index0 - poolFeeState.supplyIndex0) / 1e18;
        uint256 expectedFee1 =
            poolFeeState.claimable1 + poolState.totalWrapped * (poolFeeState.index1 - poolFeeState.supplyIndex1) / 1e18;
        assertEq(fee0, expectedFee0);
        assertEq(fee1, expectedFee1);

        // And: They equal what the pool actually pays out.
        deal(metadex03Pool.token0(), metadex03Pool.poolFees(), type(uint256).max, true);
        deal(metadex03Pool.token1(), metadex03Pool.poolFees(), type(uint256).max, true);
        (uint256 claimedFee0, uint256 claimedFee1) = wrappedMetadex03AM.claimFees(address(metadex03Pool));
        assertEq(fee0, claimedFee0);
        assertEq(fee1, claimedFee1);
    }

    function testFuzz_Success_getCurrentFees_MatchesPendingFees(
        bool stable,
        uint256 reserve0,
        uint256 swapAmount0,
        uint256 swapAmount1,
        uint128 wrapped
    ) public {
        // Given: A pool with liquidity.
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        reserve0 = bound(reserve0, 1e18, 1e26);
        deal(address(asset0), address(metadex03Pool), reserve0);
        deal(address(asset1), address(metadex03Pool), reserve0);
        metadex03Pool.mint(users.liquidityProvider);

        // And: The Asset Module holds wrapped liquidity.
        // forge-lint: disable-next-item(unsafe-typecast)
        wrapped = uint128(bound(wrapped, 1, type(uint112).max));
        deal(address(metadex03Pool), address(wrappedMetadex03AM), wrapped, true);
        wrappedMetadex03AM.setPoolState(
            address(metadex03Pool),
            WrappedAerodromeAM.PoolState({ fee0PerLiquidity: 0, fee1PerLiquidity: 0, totalWrapped: wrapped })
        );
        (address token0, address token1) = metadex03Pool.tokens();
        wrappedMetadex03AM.setTokens(address(metadex03Pool), token0, token1);

        // And: Swaps in both directions accrued fees to the pool.
        swapAmount0 = bound(swapAmount0, reserve0 / 1000, reserve0 / 10);
        swapAmount1 = bound(swapAmount1, reserve0 / 1000, reserve0 / 10);
        deal(token0, users.tokenCreator, swapAmount0);
        vm.startPrank(users.tokenCreator);
        uint256 amountOut = metadex03Pool.getAmountOut(swapAmount0, token0);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        ERC20Mock(token0).transfer(address(metadex03Pool), swapAmount0);
        metadex03Pool.swap(0, amountOut, users.tokenCreator, "");
        vm.stopPrank();
        deal(token1, users.tokenCreator, swapAmount1);
        vm.startPrank(users.tokenCreator);
        amountOut = metadex03Pool.getAmountOut(swapAmount1, token1);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        ERC20Mock(token1).transfer(address(metadex03Pool), swapAmount1);
        metadex03Pool.swap(amountOut, 0, users.tokenCreator, "");
        vm.stopPrank();

        // When: The current fees of the pool are read.
        (uint256 fee0, uint256 fee1) = wrappedMetadex03AM.getCurrentFees(address(metadex03Pool));

        // Then: They match the pending fees the pool itself reports.
        (uint256 pendingFee0, uint256 pendingFee1) = metadex03Pool.pendingFees(address(wrappedMetadex03AM));
        assertEq(fee0, pendingFee0);
        assertEq(fee1, pendingFee1);
    }

    function testFuzz_Success_getCurrentFees_ZeroWrapped(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        PoolFeeState memory poolFeeState
    ) public {
        // Given: A pool with a valid fee state.
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        poolFeeState = givenValidPoolFeeState(poolFeeState);

        // And: Nothing is wrapped.
        poolState.totalWrapped = 0;

        // And: That state is persisted.
        setPoolFeeState(poolFeeState);
        wrappedMetadex03AM.setPoolState(address(metadex03Pool), poolState);

        // When: The current fees of the pool are read.
        (uint256 fee0, uint256 fee1) = wrappedMetadex03AM.getCurrentFees(address(metadex03Pool));

        // Then: No fees are accounted for.
        assertEq(fee0, 0);
        assertEq(fee1, 0);

        // And: They never exceed what the pool actually pays out.
        deal(metadex03Pool.token0(), metadex03Pool.poolFees(), type(uint256).max, true);
        deal(metadex03Pool.token1(), metadex03Pool.poolFees(), type(uint256).max, true);
        (uint256 claimedFee0, uint256 claimedFee1) = wrappedMetadex03AM.claimFees(address(metadex03Pool));
        assertLe(fee0, claimedFee0);
        assertLe(fee1, claimedFee1);
    }
}
