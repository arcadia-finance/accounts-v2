/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";

/**
 * @notice Fuzz tests for the function "_stake" of contract "StakedMetadex03CLAM".
 */
contract Stake_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function transferToAssetModule(uint256 assetId) internal {
        vm.prank(users.liquidityProvider);
        metadex03PositionManager.safeTransferFrom(users.liquidityProvider, address(stakedMetadex03CLAM), assetId);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_stake_GaugeNotValid(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: A Liquidity Position held by the Asset Module.
        position = givenValidPosition(position, 1);
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);
        uint256 assetId = addLiquidity(position);
        transferToAssetModule(assetId);

        // When: Calling _stake() with the zero address as gauge.
        // Then: It reverts.
        vm.expectRevert(StakedSlipstreamAM.GaugeNotValid.selector);
        stakedMetadex03CLAM.stake(address(0), assetId);
    }

    function testFuzz_Success_stake_Leaf(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: A Liquidity Position held and approved by the Asset Module.
        position = givenValidPosition(position, 1);
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);
        uint256 assetId = addLiquidity(position);
        transferToAssetModule(assetId);
        stakedMetadex03CLAM.approvePosition(address(gauge), assetId);

        // When: Calling _stake().
        stakedMetadex03CLAM.stake(address(gauge), assetId);

        // Then: The gauge holds the Liquidity Position, staked for the Asset Module.
        assertEq(metadex03PositionManager.ownerOf(assetId), address(gauge));
        assertEq(gauge.earned(address(stakedMetadex03CLAM), stakedMetadex03CLAM.asSingleton(assetId)), 0);
    }

    function testFuzz_Success_stake_Root(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: The protocol is staged on the root chain.
        _stageRoot();

        // And: A Liquidity Position held and approved by the Asset Module.
        position = givenValidPosition(position, 1);
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);
        uint256 assetId = addLiquidity(position);
        transferToAssetModule(assetId);
        stakedMetadex03CLAM.approvePosition(address(gauge), assetId);

        // When: Calling _stake().
        stakedMetadex03CLAM.stake(address(gauge), assetId);

        // Then: The gauge holds the Liquidity Position, staked for the Asset Module.
        assertEq(metadex03PositionManager.ownerOf(assetId), address(gauge));
    }
}
