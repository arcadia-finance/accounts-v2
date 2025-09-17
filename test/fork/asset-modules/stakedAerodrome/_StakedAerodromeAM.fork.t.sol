/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { AerodromePoolAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { Fork_Test } from "../../Fork.t.sol";
import { IAeroRouter } from "../../../utils/interfaces/IAeroRouter.sol";
import { IAeroFactory } from "../../../../src/asset-modules/Aerodrome-Finance/interfaces/IAeroFactory.sol";
import { StakedAerodromeAMExtension } from "../../../utils/extensions/StakedAerodromeAMExtension.sol";
/**
 * @notice Base test file for Aerodrome Asset-Module fork tests.
 */

contract StakedAerodromeAM_Fork_Test is Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    IAeroRouter internal constant ROUTER = IAeroRouter(0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43);
    IAeroFactory internal constant AERO_FACTORY = IAeroFactory(0x420DD381b31aEf6683db6B902084cB0FFECe40Da);

    // The AERO contract address on Base
    address internal constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    // The address of the Aerodrome Voter contract
    address internal constant AERO_VOTER = 0x16613524e02ad97eDfeF371bC883F2F5d6C480A5;
    // The address of the DAI/USDC Aerodrome Stable pool
    address internal constant STABLE_POOL = 0x67b00B46FA4f4F24c03855c5C8013C0B938B3eEc;
    // The gauge of the DAI/USDC Aerodrome Stable pool
    address internal constant STABLE_GAUGE = 0x640e9ef68e1353112fF18826c4eDa844E1dC5eD0;
    // The address of the WETH/USDC Aerodrome Volatile pool
    address internal constant VOLATILE_POOL = 0xcDAC0d6c6C59727a65F871236188350531885C43;
    // The gauge of the WETH/USDC Aerodrome Volatile pool
    address internal constant VOLATILE_GAUGE = 0x519BBD1Dd8C6A94C46080E24f316c14Ee758C025;

    address internal constant DOLA_USDC_POOL = 0xf213F2D02837012dC0236cC105061e121bB03e37;

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /// forge-lint: disable-start(mixed-case-variable)
    AerodromePoolAM internal aerodromePoolAM;
    StakedAerodromeAMExtension internal stakedAerodromeAM;
    /// forge-lint: disable-end(mixed-case-variable)

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Fork_Test.setUp();

        // Deploy a mock oracle for AERO
        vm.startPrank(users.owner);
        ArcadiaOracle aeroOracle = new ArcadiaOracle(18, "AERO / USD");
        aeroOracle.setOffchainTransmitter(users.transmitter);
        vm.stopPrank();

        vm.startPrank(users.transmitter);
        aeroOracle.transmit(1e18);

        // Add AERO and its oracle to the protocol.
        vm.startPrank(users.owner);
        uint256 oracleId = chainlinkOM.addOracle(address(aeroOracle), "AERO", "USD", 2 days);
        bool[] memory boolValues = new bool[](1);
        boolValues[0] = true;
        uint80[] memory uintValues = new uint80[](1);
        uintValues[0] = uint80(oracleId);
        bytes32 oracleSequence = BitPackingLib.pack(boolValues, uintValues);
        erc20AM.addAsset(AERO, oracleSequence);

        // Deploy Aerodrome Volatile and Stable pools.
        aerodromePoolAM = new AerodromePoolAM(users.owner, address(registry), address(AERO_FACTORY));
        registry.addAssetModule(address(aerodromePoolAM));

        // Deploy StakedAerodromeAM.
        stakedAerodromeAM = new StakedAerodromeAMExtension(users.owner, address(registry), AERO_VOTER, AERO);
        registry.addAssetModule(address(stakedAerodromeAM));
        stakedAerodromeAM.initialize();

        // Add STABLE_POOL to the AerodromePoolAM
        aerodromePoolAM.addAsset(STABLE_POOL);
        vm.stopPrank();

        // Label contracts
        vm.label({ account: address(ROUTER), newLabel: "Aerodrome Router" });
        vm.label({ account: address(AERO_FACTORY), newLabel: "Aerodrome Factory" });
        vm.label({ account: address(aerodromePoolAM), newLabel: "Aerodrome Volatile AM" });
        vm.label({ account: address(stakedAerodromeAM), newLabel: "Staked Aerodrome Asset Module" });
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    // Deal method does not work anymore with USDC.
    // We prank the DOLA/USDC pool to transfer USDC from it.
    function addLiquidityUsdc(
        ERC20 token0,
        ERC20 token1,
        bool stable,
        uint256 amount0,
        uint256 amount1,
        address user,
        address pool
    ) public returns (uint256 lpBalance) {
        // A user adds liquidity in the pool.
        vm.prank(DOLA_USDC_POOL);
        /// forge-lint: disable-next-line(erc20-unchecked-transfer)
        USDC.transfer(user, amount0);

        deal(address(token1), user, amount1);

        vm.startPrank(user);
        token0.approve(address(ROUTER), amount0);
        token1.approve(address(ROUTER), amount1);
        ROUTER.addLiquidity(address(token0), address(token1), stable, amount0, amount1, 0, 0, user, block.timestamp);
        vm.stopPrank();

        lpBalance = ERC20(pool).balanceOf(user);
    }

    function addLiquidity(
        ERC20 token0,
        ERC20 token1,
        bool stable,
        uint256 amount0,
        uint256 amount1,
        address user,
        address pool
    ) public returns (uint256 lpBalance) {
        // A user adds liquidity in the pool.
        deal(address(token0), user, amount0);
        deal(address(token1), user, amount1);

        vm.startPrank(user);
        token0.approve(address(ROUTER), amount0);
        token1.approve(address(ROUTER), amount1);
        ROUTER.addLiquidity(address(token0), address(token1), stable, amount0, amount1, 0, 0, user, block.timestamp);
        vm.stopPrank();

        lpBalance = ERC20(pool).balanceOf(user);
    }
}
