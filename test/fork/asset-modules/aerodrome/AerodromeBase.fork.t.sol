/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { Fork_Test } from "../../Fork.t.sol";

import { AccountV1 } from "../../../../src/accounts/AccountV1.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { IAeroPool } from "../../../../src/asset-modules/Aerodrome-Finance/interfaces/IAeroPool.sol";
import { IAeroRouter } from "../../../../src/asset-modules/Aerodrome-Finance/interfaces/IAeroRouter.sol";
import { IAeroFactory } from "../../../../src/asset-modules/Aerodrome-Finance/interfaces/IAeroFactory.sol";
import { AerodromeVolatileAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeVolatileAM.sol";
import { AerodromeStableAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeStableAM.sol";
import { StakedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";
import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";

/**
 * @notice Base test file for Aerodrome Asset-Module fork tests.
 */
contract AerodromeBase_Fork_Test is Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    IAeroRouter public router = IAeroRouter(0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43);
    IAeroFactory public aeroFactory = IAeroFactory(0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6);
    address AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;

    AerodromeVolatileAM public aerodromeVolatileAM;
    AerodromeStableAM public aerodromeStableAM;
    StakedAerodromeAM public stakedAerodromeAM;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Fork_Test.setUp();

        // Deploy a mock oracle for AERO
        vm.startPrank(users.creatorAddress);
        ArcadiaOracle aeroOracle = new ArcadiaOracle(18, "AERO / USD", AERO);
        aeroOracle.setOffchainTransmitter(users.defaultTransmitter);
        vm.stopPrank();

        vm.startPrank(users.defaultTransmitter);
        aeroOracle.transmit(1e18);

        // Add AERO and its oracle to the protocol.
        vm.startPrank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(aeroOracle), "AERO", "USD", 2 days);
        bool[] memory boolValues = new bool[](1);
        boolValues[0] = true;
        uint80[] memory uintValues = new uint80[](1);
        uintValues[0] = uint80(oracleId);
        bytes32 oracleSequence = BitPackingLib.pack(boolValues, uintValues);
        erc20AssetModule.addAsset(AERO, oracleSequence);

        // Deploy Aerodrome Volatile and Stable pools.
        aerodromeVolatileAM = new AerodromeVolatileAM(address(registryExtension), address(aeroFactory));
        registryExtension.addAssetModule(address(aerodromeVolatileAM));

        aerodromeStableAM = new AerodromeStableAM(address(registryExtension), address(aeroFactory));
        registryExtension.addAssetModule(address(aerodromeStableAM));

        // Deploy StakedAerodromeAM.
        stakedAerodromeAM = new StakedAerodromeAM(address(registryExtension));
        registryExtension.addAssetModule(address(stakedAerodromeAM));
        stakedAerodromeAM.initialize();

        // Label contracts
        vm.label({ account: address(router), newLabel: "Aerodrome Router" });
        vm.label({ account: address(aeroFactory), newLabel: "Aerodrome Factory" });
        vm.label({ account: address(aerodromeVolatileAM), newLabel: "Aerodrome Volatile AM" });
        vm.label({ account: address(aerodromeStableAM), newLabel: "Aerodrome Stable AM" });
        vm.label({ account: address(stakedAerodromeAM), newLabel: "Staked Aerodrome Asset Module" });

        vm.stopPrank();
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function stakeInAssetModuleAndDepositInAccount(
        address account,
        ERC20 token0,
        ERC20 token1,
        bool stable,
        uint256 amount0,
        uint256 amount1,
        address user,
        IAeroPool pool
    ) public returns (uint256 lpBalance) {
        // A user deposits in the Stargate USDbC pool.
        vm.startPrank(user);
        deal(address(token0), user, amount0);
        deal(address(token1), user, amount1);

        token0.approve(address(router), amount0);
        token1.approve(address(router), amount1);
        router.addLiquidity(address(token0), address(token1), stable, amount0, amount1, 0, 0, user, block.timestamp);

        // The user stakes the LP token via the Staked Aerodrome Asset Module
        lpBalance = ERC20(address(pool)).balanceOf(user);
        ERC20(address(pool)).approve(address(stakedAerodromeAM), lpBalance);

        uint256 tokenId = stakedAerodromeAM.mint(address(pool), uint128(lpBalance));

        // The user deposits the ERC721 in its Account.
        stakedAerodromeAM.approve(account, tokenId);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(stakedAerodromeAM);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = tokenId;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        AccountV1(account).deposit(assetAddresses, assetIds, assetAmounts);

        vm.stopPrank();
    }
}
