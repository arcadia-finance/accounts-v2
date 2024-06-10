/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../../../lib/forge-std/src/Test.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC20Mock } from "../../mocks/tokens/ERC20Mock.sol";
import { Gauge } from "../../mocks/Aerodrome/AeroGaugeMock.sol";
import { Pool } from "../../mocks/Aerodrome/AeroPoolMock.sol";
import { PoolFactory } from "../../mocks/Aerodrome/AeroPoolFactoryMock.sol";
import { VoterMock } from "../../mocks/Aerodrome/VoterMock.sol";

contract AerodromeFixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;

    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    PoolFactory internal aeroPoolFactory;
    VoterMock internal voter;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function deployAerodromePeriphery() internal {
        // Deploy mock voter contract.
        voter = new VoterMock(address(0));

        // Create Aero.
        ERC20Mock rewardToken = new ERC20Mock("Aerodrome", "AERO", 18);
        vm.etch(AERO, address(rewardToken).code);
    }

    function deployAerodrome() internal {
        Pool implementation = new Pool();
        aeroPoolFactory = new PoolFactory(address(implementation));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function createPoolAerodrome(address token0, address token1, bool stable) internal returns (Pool pool) {
        pool = Pool(aeroPoolFactory.createPool(token0, token1, stable));
    }

    function createGaugeAerodrome(Pool pool, address rewardToken) internal returns (Gauge gauge) {
        gauge = new Gauge(msg.sender, address(pool), msg.sender, rewardToken, address(voter), false);

        voter.setGauge(address(gauge));
        voter.setAlive(address(gauge), true);
    }

    function addEmissionsToGauge(Gauge gauge, uint256 emissions) public {
        deal(AERO, address(voter), emissions);
        vm.startPrank(address(voter));
        ERC20(AERO).approve(address(gauge), emissions);
        gauge.notifyRewardAmount(emissions);
        vm.stopPrank();
    }
}
