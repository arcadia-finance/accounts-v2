/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "addGauge" of contract "StakedSlipstreamAM".
 */
contract AddGauge_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
        ERC20Mock tokenA = new ERC20Mock("Token A", "TOKENA", 18);
        ERC20Mock tokenB = new ERC20Mock("Token B", "TOKENB", 18);
        (token0, token1) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_addGauge_NotOwner(address unprivilegedAddress, address gaugeToAdd) public {
        // Given: The unprivileged address is not the owner.
        vm.assume(unprivilegedAddress != users.owner);

        // When: The unprivileged address adds a gauge.
        // Then: It reverts.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        stakedSlipstreamAM.addGauge(gaugeToAdd);
    }

    function testFuzz_Revert_addGauge_NonGauge(address nonGauge, int24 tick) public {
        // Given: A gauge on a pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        pool = createPoolCL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeCL(pool);

        // And: The address that is added is not that gauge.
        vm.assume(nonGauge != address(gauge));

        // When: The owner adds the address.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.GaugeNotValid.selector);
        stakedSlipstreamAM.addGauge(nonGauge);
    }

    function testFuzz_Revert_addGauge_NonRewardToken(address nonRewardToken, int24 tick) public {
        // Given: A gauge on a pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        pool = createPoolCL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeCL(pool);

        // And: The reward token of the gauge is not the reward token of the Asset Module.
        vm.assume(nonRewardToken != AERO);
        stdstore.target(address(gauge)).sig(gauge.rewardToken.selector).checked_write(nonRewardToken);

        // When: The owner adds the gauge.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.RewardTokenNotValid.selector);
        stakedSlipstreamAM.addGauge(address(gauge));
    }

    function testFuzz_Revert_addGauge_Token0NotAllowed(bool token1Allowed, int24 tick) public {
        // Given: A gauge on a pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        pool = createPoolCL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeCL(pool);

        // And: Token1 may or may not be allowed, token0 is checked first.
        if (token1Allowed) addAssetToArcadia(address(token1), 1e18);

        // And: Token0 is not allowed.
        assertFalse(registry.isAllowed(address(token0), 0));

        // When: The owner adds the gauge.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.AssetNotAllowed.selector);
        stakedSlipstreamAM.addGauge(address(gauge));
    }

    function testFuzz_Revert_addGauge_Token1NotAllowed(int24 tick) public {
        // Given: A gauge on a pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        pool = createPoolCL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeCL(pool);

        // And: Token0 is allowed.
        addAssetToArcadia(address(token0), 1e18);

        // And: Token1 is not allowed.
        assertFalse(registry.isAllowed(address(token1), 0));

        // When: The owner adds the gauge.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.AssetNotAllowed.selector);
        stakedSlipstreamAM.addGauge(address(gauge));
    }

    function testFuzz_Success_addGauge(int24 tick) public {
        // Given: A gauge on a pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        pool = createPoolCL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeCL(pool);

        // And: Both pool tokens are allowed.
        addAssetToArcadia(address(token0), 1e18);
        addAssetToArcadia(address(token1), 1e18);

        // When: The owner adds the gauge.
        vm.prank(users.owner);
        stakedSlipstreamAM.addGauge(address(gauge));

        // Then: The gauge is mapped to its pool.
        assertEq(stakedSlipstreamAM.poolToGauge(address(pool)), address(gauge));
    }
}
