/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AbstractStakingAM_Fuzz_Test } from "../AbstractStakingAM/_AbstractStakingAM.fuzz.t.sol";
import { AerodromeFixture } from "../../../utils/fixtures/aerodrome/AerodromeFixture.f.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";

import { AerodromePoolAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { Gauge } from "../../../utils/mocks/Aerodrome/AeroGaugeMock.sol";
import { Pool } from "../../../utils/mocks/Aerodrome/AeroPoolMock.sol";
import { StakedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";
import { StakedAerodromeAMExtension } from "../../../utils/extensions/StakedAerodromeAMExtension.sol";
import { StakingAM } from "../../../../src/asset-modules/abstracts/AbstractStakingAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Common logic needed by "StakedAerodromeAM" fuzz tests.
 */
abstract contract StakedAerodromeAM_Fuzz_Test is Fuzz_Test, AbstractStakingAM_Fuzz_Test, AerodromeFixture {
    using stdStorage for StdStorage;
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AerodromePoolAM internal aerodromePoolAM;
    Gauge internal aeroGauge;
    Pool internal aeroPool;
    StakedAerodromeAMExtension internal stakedAerodromeAM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, AbstractStakingAM_Fuzz_Test) {
        Fuzz_Test.setUp();

        deployAerodromePeriphery();
        deployAerodrome();
        rewardToken = ERC20Mock(AERO);

        // Add the reward token to the Registry
        addAssetToArcadia(AERO, int256(rates.token1ToUsd));

        // Deploy Aerodrome AM.
        vm.startPrank(users.owner);
        aerodromePoolAM = new AerodromePoolAM(address(registry), address(aeroPoolFactory));
        registry.addAssetModule(address(aerodromePoolAM));

        // Deploy StakedAerodromeAM.
        stakedAerodromeAM = new StakedAerodromeAMExtension(address(registry), address(voter), AERO);
        registry.addAssetModule(address(stakedAerodromeAM));
        stakedAerodromeAM.initialize();
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
    function setStakedAerodromeAMState(
        StakingAMStateForAsset memory stakingAMStateForAsset,
        StakingAM.PositionState memory stakingAMStateForPosition,
        address asset,
        uint96 id
    ) internal {
        stakedAerodromeAM.setTotalStaked(asset, stakingAMStateForAsset.totalStaked);
        stakedAerodromeAM.setLastRewardPosition(id, stakingAMStateForPosition.lastRewardPosition);
        stakedAerodromeAM.setLastRewardPerTokenPosition(id, stakingAMStateForPosition.lastRewardPerTokenPosition);
        stakedAerodromeAM.setLastRewardPerTokenGlobal(asset, stakingAMStateForAsset.lastRewardPerTokenGlobal);
        // Set current rewards earned in the aeroGauge
        stdstore.target(address(aeroGauge)).sig(aeroGauge.rewards.selector).with_key(address(stakedAerodromeAM))
            .checked_write(stakingAMStateForAsset.currentRewardGlobal);
        deal(AERO, address(aeroGauge), stakingAMStateForAsset.currentRewardGlobal);
        stakedAerodromeAM.setAmountStakedForPosition(id, stakingAMStateForPosition.amountStaked);
        stakingAMStateForPosition.asset = asset;
        stakedAerodromeAM.setAssetInPosition(asset, id);
    }
}
