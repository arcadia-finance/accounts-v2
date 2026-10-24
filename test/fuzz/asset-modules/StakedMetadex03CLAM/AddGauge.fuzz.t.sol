/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { IFactoryRegistry } from "../../../../src/asset-modules/Metadex03/interfaces/IFactoryRegistry.sol";
import { IMetadex03CLGauge } from "../../../../src/asset-modules/Metadex03/interfaces/IMetadex03CLGauge.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "addGauge" of contract "StakedMetadex03CLAM".
 */
contract AddGauge_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
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
        stakedMetadex03CLAM.addGauge(gaugeToAdd);
    }

    function testFuzz_Revert_addGauge_GaugeNotValid_NotRegistered(int24 tick) public {
        // Given: A pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        pool = createPoolMetadex03CL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);

        // And: A gauge created by the real factory but never recorded in the FactoryRegistry.
        vm.prank(metadex03GaugeManager);
        (address gauge_,) = metadex03CLGaugeFactory.createGauge(address(pool), "");
        gauge = IMetadex03CLGauge(gauge_);

        // When: The owner adds the gauge.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.GaugeNotValid.selector);
        stakedMetadex03CLAM.addGauge(address(gauge));
    }

    function testFuzz_Revert_addGauge_GaugeNotValid_ForeignGaugeFactory(address foreignGaugeFactory, int24 tick)
        public
    {
        // Given: A valid, registered gauge on a pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);

        // And: The FactoryRegistry records it against a GaugeFactory this Asset Module does not know.
        vm.assume(foreignGaugeFactory != address(metadex03CLGaugeFactory));
        vm.mockCall(
            address(factoryRegistryMetadex03),
            abi.encodeWithSelector(IFactoryRegistry.gaugeToFactory.selector, address(gauge)),
            abi.encode(foreignGaugeFactory)
        );

        // When: The owner adds the gauge.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.GaugeNotValid.selector);
        stakedMetadex03CLAM.addGauge(address(gauge));
    }

    function testFuzz_Revert_addGauge_GaugeNotValid_WrongGauge(address otherGauge, int24 tick) public {
        // Given: A registered gauge on a pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        pool = createPoolMetadex03CL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeMetadex03CL(pool);

        // And: The gauge of the pool is not the gauge that is added.
        vm.assume(otherGauge != address(gauge));
        stdstore.target(address(pool)).sig("gauge()").checked_write(otherGauge);

        // When: The owner adds the gauge.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.GaugeNotValid.selector);
        stakedMetadex03CLAM.addGauge(address(gauge));
    }

    function testFuzz_Revert_addGauge_Token0NotAllowed(bool token1Allowed, int24 tick) public {
        // Given: A registered gauge on a pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        pool = createPoolMetadex03CL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeMetadex03CL(pool);

        // And: Token1 may or may not be allowed, token0 is checked first.
        if (token1Allowed) addAssetToArcadia(address(token1), 1e18);

        // And: Token0 is not allowed.
        assertFalse(registry.isAllowed(address(token0), 0));

        // When: The owner adds the gauge.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.AssetNotAllowed.selector);
        stakedMetadex03CLAM.addGauge(address(gauge));
    }

    function testFuzz_Revert_addGauge_Token1NotAllowed(int24 tick) public {
        // Given: A registered gauge on a pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        pool = createPoolMetadex03CL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeMetadex03CL(pool);

        // And: Token0 is allowed.
        addAssetToArcadia(address(token0), 1e18);

        // And: Token1 is not allowed.
        assertFalse(registry.isAllowed(address(token1), 0));

        // When: The owner adds the gauge.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.AssetNotAllowed.selector);
        stakedMetadex03CLAM.addGauge(address(gauge));
    }

    function testFuzz_Success_addGauge(int24 tick) public {
        // Given: A registered gauge on a pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        pool = createPoolMetadex03CL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeMetadex03CL(pool);

        // And: Both pool tokens are allowed.
        addAssetToArcadia(address(token0), 1e18);
        addAssetToArcadia(address(token1), 1e18);

        // When: The owner adds the gauge.
        vm.prank(users.owner);
        stakedMetadex03CLAM.addGauge(address(gauge));

        // Then: The gauge is mapped to its pool.
        assertEq(stakedMetadex03CLAM.poolToGauge(address(pool)), address(gauge));
    }

    function testFuzz_Success_addGauge_RewardTokenInPool(bool asToken0, int24 tick) public {
        // Given: A pool of which one token is the Reward Token.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        ERC20Mock other = new ERC20Mock("Token A", "TOKENA", 18);
        addAssetToArcadia(address(other), 1e18);
        (address token0_, address token1_) = asToken0 ? (rewardToken, address(other)) : (address(other), rewardToken);
        pool = createPoolMetadex03CL(token0_, token1_, 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeMetadex03CL(pool);

        // When: The Owner adds the gauge.
        vm.prank(users.owner);
        stakedMetadex03CLAM.addGauge(address(gauge));

        // Then: The gauge is mapped to its pool.
        assertEq(stakedMetadex03CLAM.poolToGauge(address(pool)), address(gauge));
    }
}
