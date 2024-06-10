/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants, ERC20Mock, ArcadiaOracle, BitPackingLib } from "../../Fuzz.t.sol";

import { AerodromePoolAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { StakedAerodromeAM, ERC20 } from "../../../../src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";
import { StakedAerodromeAMExtension } from "../../../utils/extensions/StakedAerodromeAMExtension.sol";
import { VoterMock } from "../../../utils/mocks/Aerodrome/VoterMock.sol";
import { Pool } from "../../../utils/fixtures/aerodrome/AeroPoolFixture.f.sol";
import { PoolFactory } from "../../../utils/fixtures/aerodrome/AeroPoolFactoryFixture.f.sol";
import { Gauge } from "../../../utils/fixtures/aerodrome/AeroGaugeFixture.f.sol";
import { AbstractStakingAM_Fuzz_Test, StakingAM, ERC20Mock } from "../AbstractStakingAM/_AbstractStakingAM.fuzz.t.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Common logic needed by "StakedAerodromeAM" fuzz tests.
 */
abstract contract StakedAerodromeAM_Fuzz_Test is Fuzz_Test, AbstractStakingAM_Fuzz_Test {
    using stdStorage for StdStorage;
    /*////////////////////////////////////////////////////////////////
                            CONSTANTS
    /////////////////////////////////////////////////////////////// */

    address AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;

    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AerodromePoolAM internal aerodromePoolAM;
    StakedAerodromeAMExtension internal stakedAerodromeAM;
    VoterMock internal voter;
    Pool internal pool;
    Pool internal implementation;
    PoolFactory internal poolFactory;
    Gauge internal gauge;
    ArcadiaOracle internal aeroOracle;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, AbstractStakingAM_Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.owner);
        // Deploy implementation of Aerodrome pool contract
        implementation = new Pool();

        // Deploy Aerodrome pool factory contract
        poolFactory = new PoolFactory(address(implementation));

        // Deploy mock voter contract
        voter = new VoterMock(address(0));

        // Deploy Aerodrome AM.
        aerodromePoolAM = new AerodromePoolAM(address(registry), address(poolFactory));
        registry.addAssetModule(address(aerodromePoolAM));

        // Deploy StakedAerodromeAM.
        // First we need to add the reward token to the Registry
        rewardToken = new ERC20Mock("Aerodrome", "AERO", 18);
        vm.etch(AERO, address(rewardToken).code);
        aeroOracle = initMockedOracle(8, "AERO / USD", rates.token1ToUsd);

        // Add AERO to the ERC20PrimaryAM.
        vm.startPrank(users.owner);
        chainlinkOM.addOracle(address(aeroOracle), "AERO", "USD", 2 days);
        uint80[] memory oracleAeroToUsdArr = new uint80[](1);
        oracleAeroToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(aeroOracle)));
        erc20AM.addAsset(AERO, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAeroToUsdArr));

        // Deploy StakedAerodromeAM.
        stakedAerodromeAM = new StakedAerodromeAMExtension(address(registry), address(voter));
        registry.addAssetModule(address(stakedAerodromeAM));
        stakedAerodromeAM.initialize();

        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
    function deployAerodromePoolFixture(address token0, address token1, bool stable) public {
        address newPool = poolFactory.createPool(token0, token1, stable);
        pool = Pool(newPool);

        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(pool));
    }

    function deployAerodromeGaugeFixture(address stakingToken, address rewardToken_) public {
        gauge = new Gauge(msg.sender, stakingToken, msg.sender, rewardToken_, address(voter), false);

        voter.setGauge(address(gauge));
        voter.setAlive(address(gauge), true);
    }

    function addEmissionsToGauge(uint256 emissions) public {
        // Given : In order to avoid earned() to overflow we limit emissions to uint128.max.
        // Such an amount should never be distributed to a specific gauge.
        emissions = bound(emissions, 1e18, type(uint128).max);
        vm.startPrank(address(voter));
        deal(AERO, address(voter), emissions);
        ERC20(AERO).approve(address(gauge), emissions);
        gauge.notifyRewardAmount(emissions);
        vm.stopPrank();
    }

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
        // Set current rewards earned in the gauge
        stdstore.target(address(gauge)).sig(gauge.rewards.selector).with_key(address(stakedAerodromeAM)).checked_write(
            stakingAMStateForAsset.currentRewardGlobal
        );
        deal(AERO, address(gauge), stakingAMStateForAsset.currentRewardGlobal);
        stakedAerodromeAM.setAmountStakedForPosition(id, stakingAMStateForPosition.amountStaked);
        stakingAMStateForPosition.asset = asset;
        stakedAerodromeAM.setAssetInPosition(asset, id);
    }
}
