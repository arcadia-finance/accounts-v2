/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { MoonwellAM_Fork_Test, ERC20 } from "./_MoonwellAM.fork.t.sol";
import { IMErc20 } from "../../../../src/asset-modules/Moonwell/interfaces/IMErc20.sol";

/**
 * @notice Fork tests for "claimRewards" function of Moonwell AM.
 */
contract ClaimRewards_Fork_Test is MoonwellAM_Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    // Aerodrome USDC/AERO pool.
    address usdcFund = 0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAFb971d;

    // mToken for USDC market
    IMErc20 mTokenUsdc = IMErc20(0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22);

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        MoonwellAM_Fork_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFork_Success_ClaimRewards() public {
        // Given : Deposit in Moonwell USDC market
        vm.prank(usdcFund);
        USDC.transfer(address(moonwellAM), 100_000 * 1e6);

        vm.startPrank(address(moonwellAM));
        USDC.approve(address(mTokenUsdc), 100_000 * 1e6);
        mTokenUsdc.mint(99_000 * 1e6);

        // And : Time passes to accumulate rewards
        vm.warp(block.timestamp + 100_000);

        // And : Adding small part to position to trigger rewards accounting
        mTokenUsdc.mint(1000 * 1e6);

        assertEq(ERC20(WELL).balanceOf(address(moonwellAM)), 0);
        assertEq(USDC.balanceOf(address(moonwellAM)), 0);
        // When : Calling claimRewards() on moonwellAM
        address[] memory rewards;
        moonwellAM.claimRewards(address(mTokenUsdc), rewards);
        vm.stopPrank();

        // Then : It should have claimed both available rewards for USDC => WELL + USDC
        assert(ERC20(WELL).balanceOf(address(moonwellAM)) > 0);
        assert(USDC.balanceOf(address(moonwellAM)) > 0);
    }
}
