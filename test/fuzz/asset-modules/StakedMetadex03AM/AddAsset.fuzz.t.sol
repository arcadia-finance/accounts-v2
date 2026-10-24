/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { IFactoryRegistry } from "../../../../src/asset-modules/Metadex03/interfaces/IFactoryRegistry.sol";
import { IMetadex03V2Gauge } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Gauge.sol";
import { StakedMetadex03AM } from "../../../../src/asset-modules/Metadex03/StakedMetadex03AM.sol";
import { StakedMetadex03AM_Fuzz_Test } from "./_StakedMetadex03AM.fuzz.t.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the "addAsset" function of contract "StakedMetadex03AM".
 */
contract AddAsset_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    using stdStorage for StdStorage;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_addAsset_GaugeNotValid_NotRegistered(bool stable) public {
        // Given: A valid metadex03Pool.
        metadex03Pool = createPoolMetadex03(address(mockERC20.stable1), address(mockERC20.token1), stable);

        // And: A gauge created by the real factory but never recorded in the FactoryRegistry.
        vm.prank(metadex03GaugeManager);
        (address gauge_,) =
            (stable ? metadex03StableGaugeFactory : metadex03GaugeFactory).createGauge(address(metadex03Pool), "");
        metadex03Gauge = IMetadex03V2Gauge(gauge_);

        // When: Calling addAsset().
        // Then: It should revert.
        vm.expectRevert(StakedMetadex03AM.GaugeNotValid.selector);
        stakedMetadex03AM.addAsset(address(metadex03Gauge));
    }

    function testFuzz_Revert_addAsset_GaugeNotValid_WrongPool(bool stable, address otherPool) public {
        // Given: A valid metadex03Pool.
        metadex03Pool = createPoolMetadex03(address(mockERC20.stable1), address(mockERC20.token1), stable);

        // And: A registered gauge whose staking token no longer matches its recorded target.
        vm.assume(otherPool != address(metadex03Pool));
        metadex03Gauge = createGaugeMetadex03(address(metadex03Pool));
        vm.mockCall(address(metadex03Gauge), abi.encodeWithSignature("stakingToken()"), abi.encode(otherPool));

        // When: Calling addAsset().
        // Then: It should revert.
        vm.expectRevert(StakedMetadex03AM.GaugeNotValid.selector);
        stakedMetadex03AM.addAsset(address(metadex03Gauge));
    }

    function testFuzz_Revert_addAsset_GaugeNotValid_ForeignGaugeFactory(bool stable, address foreignGaugeFactory)
        public
    {
        // Given: A valid, registered gauge.
        metadex03Pool = createPoolMetadex03(address(mockERC20.stable1), address(mockERC20.token1), stable);
        metadex03Gauge = createGaugeMetadex03(address(metadex03Pool));

        // And: The FactoryRegistry records it against a GaugeFactory this Asset Module does not know.
        vm.assume(foreignGaugeFactory != address(metadex03StableGaugeFactory));
        vm.assume(foreignGaugeFactory != address(metadex03GaugeFactory));
        vm.mockCall(
            address(factoryRegistryMetadex03),
            abi.encodeWithSelector(IFactoryRegistry.gaugeToFactory.selector, address(metadex03Gauge)),
            abi.encode(foreignGaugeFactory)
        );

        // When: Calling addAsset().
        // Then: It should revert.
        vm.expectRevert(StakedMetadex03AM.GaugeNotValid.selector);
        stakedMetadex03AM.addAsset(address(metadex03Gauge));
    }

    function testFuzz_Revert_addAsset_PoolNotAllowed(bool stable) public {
        // Given: A valid metadex03Pool, which was never allowed in the Registry.
        metadex03Pool = createPoolMetadex03(address(mockERC20.stable1), address(mockERC20.token1), stable);

        // And: A valid metadex03Gauge.
        metadex03Gauge = createGaugeMetadex03(address(metadex03Pool));

        // When: Calling addAsset().
        // Then: It should revert.
        vm.expectRevert(StakedMetadex03AM.PoolNotAllowed.selector);
        stakedMetadex03AM.addAsset(address(metadex03Gauge));
    }

    function testFuzz_Revert_addAsset_AssetAlreadySet(bool stable) public {
        // Given: The metadex03Pool is allowed in the Registry.
        metadex03Pool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), stable);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        // And: A valid metadex03Gauge.
        metadex03Gauge = createGaugeMetadex03(address(metadex03Pool));

        // And: The metadex03Pool is already added to the Asset Module.
        stakedMetadex03AM.setAllowed(address(metadex03Pool), true);

        // When: Calling addAsset().
        // Then: It should revert.
        vm.expectRevert(StakedMetadex03AM.AssetAlreadySet.selector);
        stakedMetadex03AM.addAsset(address(metadex03Gauge));
    }

    function testFuzz_Success_addAsset(bool stable) public {
        // Given: The metadex03Pool is allowed in the Registry.
        metadex03Pool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), stable);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        // And: A valid metadex03Gauge.
        metadex03Gauge = createGaugeMetadex03(address(metadex03Pool));

        // When: Calling addAsset().
        stakedMetadex03AM.addAsset(address(metadex03Gauge));

        // Then: Asset and metadex03Gauge info should be updated.
        assertEq(stakedMetadex03AM.assetToGauge(address(metadex03Pool)), address(metadex03Gauge));
        (,, bool allowed) = stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(allowed, true);
    }

    function testFuzz_Success_addAsset_PenaltyActive(uint256 minStakeBlocks, uint256 penaltyRate) public {
        // Given: The metadex03Pool is allowed in the Registry.
        metadex03Pool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        // And: A valid metadex03Gauge.
        metadex03Gauge = createGaugeMetadex03(address(metadex03Pool));

        // And: A non-zero penalty rate is active for the gauge.
        minStakeBlocks = bound(minStakeBlocks, 0, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        setPenaltyConfig(address(metadex03Gauge), minStakeBlocks, penaltyRate);

        // When: Calling addAsset().
        stakedMetadex03AM.addAsset(address(metadex03Gauge));

        // Then: The gauge is onboarded, the penalty is priced through the net earned().
        assertEq(stakedMetadex03AM.assetToGauge(address(metadex03Pool)), address(metadex03Gauge));
    }
}
