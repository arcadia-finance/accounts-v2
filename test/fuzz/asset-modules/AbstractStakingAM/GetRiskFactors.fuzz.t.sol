/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test, ERC20Mock } from "./_AbstractStakingAM.fuzz.t.sol";
import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "StakingAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract GetRiskFactors_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getRiskFactors(
        uint16 riskFactor,
        uint16 collateralFactor,
        uint16 liquidationFactor,
        address creditor,
        uint128 amount,
        uint128 reward
    ) public {
        // Given: Risk factors are below the maximum, and equal for both Underlying Assets.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        collateralFactor = uint16(bound(collateralFactor, 0, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, collateralFactor, AssetValuationLib.ONE_4));

        // And: A staked position, with an amount that is non-zero as mint reverts otherwise.
        amount = uint128(bound(amount, 1, type(uint128).max));

        // And: Both Underlying Assets are priced in the Registry.
        address asset = address(mockERC20.stable1);
        stakingAM.addAsset(asset);
        addAssetToArcadia(address(stakingAM.REWARD_TOKEN()), 1e18);
        address user = address(0x1);
        deal(asset, user, amount, true);
        vm.startPrank(user);
        ERC20Mock(asset).approve(address(stakingAM), amount);
        uint256 positionId = stakingAM.mint(asset, amount);
        vm.stopPrank();
        stakingAM.setActualRewardBalance(asset, reward);

        // And: The risk factors of the Asset Module and of both Underlying Assets are set.
        vm.startPrank(address(registry));
        stakingAM.setRiskParameters(creditor, 0, riskFactor);
        erc20AM.setRiskParameters(creditor, asset, 0, type(uint112).max, collateralFactor, liquidationFactor);
        erc20AM.setRiskParameters(
            creditor, address(stakingAM.REWARD_TOKEN()), 0, type(uint112).max, collateralFactor, liquidationFactor
        );
        vm.stopPrank();

        // When: getRiskFactors is called.
        (uint256 collateralFactor_, uint256 liquidationFactor_) =
            stakingAM.getRiskFactors(creditor, address(stakingAM), positionId);

        // Then: Both factors are scaled by the risk factor of the Asset Module.
        assertEq(collateralFactor_, uint256(collateralFactor) * riskFactor / AssetValuationLib.ONE_4);
        assertEq(liquidationFactor_, uint256(liquidationFactor) * riskFactor / AssetValuationLib.ONE_4);
    }
}
