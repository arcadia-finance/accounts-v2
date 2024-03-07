/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { Fork_Test } from "../../Fork.t.sol";

import { AccountV1 } from "../../../../src/accounts/AccountV1.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ILpStakingTime } from "../../../../src/asset-modules/Stargate-Finance/interfaces/ILpStakingTime.sol";
import { IPool } from "../../../../src/asset-modules/Stargate-Finance/interfaces/IPool.sol";
import { IRouter } from "../../../../src/asset-modules/Stargate-Finance/interfaces/IRouter.sol";
import { ISGFactory } from "../../../../src/asset-modules/Stargate-Finance/interfaces/ISGFactory.sol";
import { StargateAM } from "../../../../src/asset-modules/Stargate-Finance/StargateAM.sol";
import { StakedStargateAM } from "../../../../src/asset-modules/Stargate-Finance/StakedStargateAM.sol";

/**
 * @notice Base test file for Stargate Asset-Module fork tests.
 */
contract StargateBase_Fork_Test is Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    IRouter public router = IRouter(0x45f1A95A4D3f3836523F5c83673c797f4d4d263B);
    ILpStakingTime public lpStakingTime = ILpStakingTime(0x06Eb48763f117c7Be887296CDcdfad2E4092739C);
    ISGFactory public sgFactory = ISGFactory(0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6);
    address oracleSTG = 0x63Af8341b62E683B87bB540896bF283D96B4D385;

    StargateAM public stargateAssetModule;
    StakedStargateAM public stakedStargateAM;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Fork_Test.setUp();

        // Add STG and it's Chainlink oracle to the protocol.
        vm.startPrank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(oracleSTG, "STG", "USD", 2 days);
        bool[] memory boolValues = new bool[](1);
        boolValues[0] = true;
        uint80[] memory uintValues = new uint80[](1);
        uintValues[0] = uint80(oracleId);
        bytes32 oracleSequence = BitPackingLib.pack(boolValues, uintValues);
        erc20AssetModule.addAsset(address(lpStakingTime.eToken()), oracleSequence);
        vm.stopPrank();

        vm.startPrank(users.creatorAddress);
        // Deploy StargateAssetModule.
        stargateAssetModule = new StargateAM(address(registryExtension), address(sgFactory));
        registryExtension.addAssetModule(address(stargateAssetModule));

        // Deploy StakedStargateAssetModule.
        stakedStargateAM = new StakedStargateAM(address(registryExtension), address(lpStakingTime));
        registryExtension.addAssetModule(address(stakedStargateAM));
        stakedStargateAM.initialize();

        // Label contracts
        vm.label({ account: address(router), newLabel: "Stargate Router" });
        vm.label({ account: address(lpStakingTime), newLabel: "Stargate Lp Staking" });
        vm.label({ account: address(sgFactory), newLabel: "Stargate Factory" });
        vm.label({ account: address(stargateAssetModule), newLabel: "Stargate Asset Module" });
        vm.label({ account: address(stakedStargateAM), newLabel: "Staked Stargate Asset Module" });
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function stakeInAssetModuleAndDepositInAccount(
        address user,
        address account,
        ERC20 underlyingAsset,
        uint256 amount,
        uint256 poolId,
        IPool pool
    ) public returns (uint256 lpBalance) {
        // A user deposits in the Stargate USDbC pool.
        vm.startPrank(user);
        deal(address(underlyingAsset), user, amount);

        underlyingAsset.approve(address(router), amount);
        router.addLiquidity(poolId, amount, user);

        // The user stakes the LP token via the StargateAssetModule
        lpBalance = ERC20(address(pool)).balanceOf(user);
        ERC20(address(pool)).approve(address(stakedStargateAM), lpBalance);

        uint256 tokenId = stakedStargateAM.mint(address(pool), uint128(lpBalance));

        // The user deposits the ERC1155 in it's Account.
        stakedStargateAM.approve(account, tokenId);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(stakedStargateAM);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = tokenId;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        AccountV1(account).deposit(assetAddresses, assetIds, assetAmounts);

        vm.stopPrank();
    }
}
