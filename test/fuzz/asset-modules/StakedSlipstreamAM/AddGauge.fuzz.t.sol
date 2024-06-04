/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";
import { Utils } from "../../../utils/Utils.sol";

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
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        deployPoolAndGauge(token0, token1, TickMath.getSqrtRatioAtTick(0), 300);
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_revert_addGauge_NotOwner(address unprivilegedAddress) public {
        // Given : unprivileged address is not the owner of the AM.
        vm.assume(unprivilegedAddress != users.creatorAddress);

        // When : Calling addGauge().
        // Then : It should revert.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        stakedSlipstreamAM.addGauge(address(gauge));
    }

    function testFuzz_revert_addGauge_NonGauge(address nonGauge) public {
        // Given : address is not a Gauge.
        vm.assume(nonGauge != address(gauge));

        // When : Calling addGauge().
        // Then : It should revert.
        vm.prank(users.creatorAddress);
        vm.expectRevert(StakedSlipstreamAM.GaugeNotValid.selector);
        stakedSlipstreamAM.addGauge(nonGauge);
    }

    function testFuzz_revert_addGauge_NonRewardToken(address nonRewardToken) public {
        // Given : Reward token is aero.
        vm.assume(nonRewardToken != AERO);

        // Overwrite AERO address.
        stdstore.target(address(gauge)).sig(gauge.rewardToken.selector).checked_write(nonRewardToken);

        // When : Calling addGauge().
        // Then : It should revert.
        vm.prank(users.creatorAddress);
        vm.expectRevert(StakedSlipstreamAM.RewardTokenNotValid.selector);
        stakedSlipstreamAM.addGauge(address(gauge));
    }

    function testFuzz_revert_addGauge_Token0NotAllowed() public {
        // Given : Token0 is not allowed.
        assertFalse(registryExtension.isAllowed(address(token0), 0));

        // When : Calling addGauge().
        // Then : It should revert.
        vm.prank(users.creatorAddress);
        vm.expectRevert(StakedSlipstreamAM.AssetNotAllowed.selector);
        stakedSlipstreamAM.addGauge(address(gauge));
    }

    function testFuzz_revert_addGauge_Token1NotAllowed() public {
        // Given : Token0 is allowed.
        addUnderlyingTokenToArcadia(address(token0), 1e18);

        // And : Token1 is not allowed.
        assertFalse(registryExtension.isAllowed(address(token1), 0));

        // When : Calling addGauge().
        // Then : It should revert.
        vm.prank(users.creatorAddress);
        vm.expectRevert(StakedSlipstreamAM.AssetNotAllowed.selector);
        stakedSlipstreamAM.addGauge(address(gauge));
    }

    function testFuzz_success_addGauge() public {
        // Given : Token0 is allowed.
        addUnderlyingTokenToArcadia(address(token0), 1e18);

        // And : Token1 is allowed.
        addUnderlyingTokenToArcadia(address(token1), 1e18);

        // When : Calling addGauge().
        vm.prank(users.creatorAddress);
        stakedSlipstreamAM.addGauge(address(gauge));

        // Then : the gauge is added.
        assertEq(stakedSlipstreamAM.poolToGauge(address(pool)), address(gauge));
    }
}
