/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import {
    INonfungiblePositionManagerExtension
} from "../../../utils/fixtures/slipstream/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "mint" of contract "StakedMetadex03CLAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract Mint_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_mint_InvalidId(uint256 assetId, address sender) public {
        // Given: The asset id does not fit the uint96 the asset key packs it into.
        assetId = bound(assetId, uint256(type(uint96).max) + 1, type(uint256).max);

        // When: The sender mints the position.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert(StakedSlipstreamAM.InvalidId.selector);
        stakedMetadex03CLAM.mint(assetId);
    }

    function testFuzz_Revert_mint_TransferFromFailed(uint96 assetId, address sender) public {
        // Given: The asset id is not minted by the Position Manager.

        // When: The sender mints the position.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert("ERC721: operator query for nonexistent token");
        stakedMetadex03CLAM.mint(assetId);
    }

    function testFuzz_Revert_mint_ZeroLiquidity(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: A gauge on a pool.
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);

        // And: A valid position of the liquidity provider.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And: All liquidity is removed from the position.
        (,,,,,,, uint128 liquidity,,,,) = metadex03PositionManager.positions(assetId);
        vm.prank(users.liquidityProvider);
        metadex03PositionManager.decreaseLiquidity(
            INonfungiblePositionManagerExtension.DecreaseLiquidityParams({
                tokenId: assetId, liquidity: liquidity, amount0Min: 0, amount1Min: 0, deadline: type(uint256).max
            })
        );

        // And: The Asset Module is approved to transfer the position.
        vm.prank(users.liquidityProvider);
        metadex03PositionManager.approve(address(stakedMetadex03CLAM), assetId);

        // When: The liquidity provider mints the position.
        // Then: It reverts.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(StakedSlipstreamAM.ZeroLiquidity.selector);
        stakedMetadex03CLAM.mint(assetId);
    }

    function testFuzz_Revert_mint_NoGaugeSet(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: A gauge on a pool.
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);

        // And: A valid position of the liquidity provider.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And: The pool has no gauge in the Asset Module.
        stakedMetadex03CLAM.setPoolToGauge(address(pool), address(0));

        // And: The Asset Module is approved to transfer the position.
        vm.prank(users.liquidityProvider);
        metadex03PositionManager.approve(address(stakedMetadex03CLAM), assetId);

        // When: The liquidity provider mints the position.
        // Then: It reverts.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(StakedSlipstreamAM.GaugeNotValid.selector);
        stakedMetadex03CLAM.mint(assetId);
    }

    function testFuzz_Revert_mint_GaugeTapeGasLimit(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address gaugeTape
    ) public {
        // Given: A staked position with earned emissions.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        position = _givenPositionStakedTwice(position);
        _initStakedPositionWithEarned(position, emissions, tick);

        // And: A second position of the liquidity provider, approved to the Asset Module.
        uint256 assetId = addLiquidity(position);
        vm.prank(users.liquidityProvider);
        metadex03PositionManager.approve(address(stakedMetadex03CLAM), assetId);

        // And: A gauge tape whose gas limit exceeds the gas left in the call.
        vm.assume(gaugeTape != address(0));
        metadex03CLGaugeFactory.setClGaugeTape(gaugeTape, type(uint32).max);

        // When: The liquidity provider mints the position.
        // Then: It reverts.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(bytes("GL"));
        stakedMetadex03CLAM.mint{ gas: 10_000_000 }(assetId);
    }

    function testFuzz_Success_mint_Leaf(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: A gauge on a pool.
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);

        // And: A valid position of the liquidity provider.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And: The Asset Module is approved to transfer the position.
        vm.prank(users.liquidityProvider);
        metadex03PositionManager.approve(address(stakedMetadex03CLAM), assetId);

        // When: The liquidity provider mints the position.
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.mint(assetId);

        // Then: The position is minted to the liquidity provider.
        assertEq(stakedMetadex03CLAM.ownerOf(assetId), users.liquidityProvider);

        // And: The position state is stored.
        (int24 tickLower, int24 tickUpper, uint128 liquidity, address gauge_) =
            stakedMetadex03CLAM.positionState(assetId);
        assertEq(tickLower, position.tickLower);
        assertEq(tickUpper, position.tickUpper);
        assertEq(liquidity, getActualLiquidity(position));
        assertEq(gauge_, address(gauge));

        // And: Both pool tokens and the ReceiptToken are the underlying assets.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(assetId), address(stakedMetadex03CLAM)));
        bytes32[] memory underlyingAssetKeys = stakedMetadex03CLAM.getUnderlyingAssets(assetKey);
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(token0))));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(token1))));
        assertEq(underlyingAssetKeys[2], bytes32(abi.encodePacked(uint96(0), receiptToken)));
    }

    function testFuzz_Success_mint_Root(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: The protocol is staged on the root chain.
        _stageRoot();

        // And: A valid position of the liquidity provider, with the pool in range.
        position = givenValidPosition(position, 1);
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);
        uint256 assetId = addLiquidity(position);

        // And: The Asset Module is approved to transfer the position.
        vm.prank(users.liquidityProvider);
        metadex03PositionManager.approve(address(stakedMetadex03CLAM), assetId);

        // When: The liquidity provider mints the position.
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.mint(assetId);

        // Then: The position is minted to the liquidity provider and staked in the gauge.
        assertEq(stakedMetadex03CLAM.ownerOf(assetId), users.liquidityProvider);
        assertEq(metadex03PositionManager.ownerOf(assetId), address(gauge));

        // And: The reward is tracked as the Token of the redeem path, not the ReceiptToken.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(assetId), address(stakedMetadex03CLAM)));
        bytes32[] memory underlyingAssetKeys = stakedMetadex03CLAM.getUnderlyingAssets(assetKey);
        assertEq(underlyingAssetKeys[2], bytes32(abi.encodePacked(uint96(0), rootToken)));
    }

    function testFuzz_Success_mint_Leaf_GaugeNotActivated(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A gauge on a pool, registered in the LeafVoter but never activated.
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick, false);

        // And: A valid position of the liquidity provider.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And: The Asset Module is approved to transfer the position.
        vm.prank(users.liquidityProvider);
        metadex03PositionManager.approve(address(stakedMetadex03CLAM), assetId);

        // When: The liquidity provider mints the position.
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.mint(assetId);

        // Then: The position is minted to the liquidity provider and staked in the gauge.
        assertEq(stakedMetadex03CLAM.ownerOf(assetId), users.liquidityProvider);
        assertEq(metadex03PositionManager.ownerOf(assetId), address(gauge));

        // And: The gauge accrues emissions over a block.
        emissions = bound(emissions, 0, MAX_BASE_RATE);
        addEmissionsToGauge(address(gauge), emissions);
        vm.warp(block.timestamp + 1);

        // Then: The position earns nothing while the gauge is not activated.
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), 0);
    }

    function testFuzz_Success_mint_SurplusSurvivesMint(
        StakedSlipstreamAM.PositionState memory position,
        StakedSlipstreamAM.PositionState memory positionOther,
        uint128 donation,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A staked position and reward tokens resting in the Asset Module.
        position = _givenPositionStakedTwice(position);
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);
        _stakePosition(position);
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(rewardToken, address(stakedMetadex03CLAM), donation);

        // And: Another user holds a Liquidity Position of the same pool, approved to the Asset Module.
        positionOther = _givenPositionStakedTwice(positionOther);
        positionOther.tickLower = position.tickLower;
        positionOther.tickUpper = position.tickUpper;
        uint256 assetId = addLiquidityAs(positionOther, users.accountOwner);

        // When: That user mints.
        vm.startPrank(users.accountOwner);
        metadex03PositionManager.approve(address(stakedMetadex03CLAM), assetId);
        stakedMetadex03CLAM.mint(assetId);
        vm.stopPrank();

        // Then: The minter received none of it, it stays claimable for the recipient.
        assertEq(ERC20(rewardToken).balanceOf(users.accountOwner), 0);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), donation);
    }

    function testFuzz_Success_mint_SurplusSurvivesMint_RewardTokenInPool(
        StakedSlipstreamAM.PositionState memory position,
        uint128 donation,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A gauge of a pool of which one token is the Reward Token.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK + 1, TickMath.MAX_TICK - 1));
        deployAndAddGaugeWithRewardToken(tick);

        // And: Reward tokens are resting in the Asset Module.
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(rewardToken, address(stakedMetadex03CLAM), donation);

        // And: A user holds a Liquidity Position of that pool, approved to the Asset Module.
        position = givenValidPosition(position);
        uint256 assetId = addLiquidityAs(position, users.accountOwner);
        uint256 balanceBefore = ERC20(rewardToken).balanceOf(users.accountOwner);

        // When: That user mints.
        vm.startPrank(users.accountOwner);
        metadex03PositionManager.approve(address(stakedMetadex03CLAM), assetId);
        stakedMetadex03CLAM.mint(assetId);
        vm.stopPrank();

        // Then: The minter received none of it, it stays claimable for the recipient.
        assertEq(ERC20(rewardToken).balanceOf(users.accountOwner), balanceBefore);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), donation);
    }
}
