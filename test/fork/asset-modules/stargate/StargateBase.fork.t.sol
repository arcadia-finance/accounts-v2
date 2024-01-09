/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { Fork_Test } from "../../Fork.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { AccountV1 } from "../../../../src/accounts/AccountV1.sol";
import { ILpStakingTime } from "../../../../src/asset-modules/interfaces/stargate/ILpStakingTime.sol";
import { IRouter } from "../../../../src/asset-modules/interfaces/stargate/IRouter.sol";
import { IPool } from "../../../../src/asset-modules/interfaces/stargate/IPool.sol";
import { StargateAssetModule } from "../../../../src/asset-modules/StargateAssetModule.sol";

/**
 * @notice Base test file for Stargate Asset-Module fork tests.
 */
contract StargateBase_Fork_Test is Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    IRouter public router = IRouter(0x45f1A95A4D3f3836523F5c83673c797f4d4d263B);
    ILpStakingTime public lpStakingTime = ILpStakingTime(0x06Eb48763f117c7Be887296CDcdfad2E4092739C);

    StargateAssetModule public stargateAssetModule;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Fork_Test.setUp();

        // Deploy StargateAssetModule.
        vm.startPrank(users.creatorAddress);
        stargateAssetModule = new StargateAssetModule(address(registryExtension), address(lpStakingTime));

        // Add Asset-Module to the registry and initialize.
        registryExtension.addAssetModule(address(stargateAssetModule));
        vm.stopPrank();

        // Label contracts
        vm.label({ account: address(router), newLabel: "StargateRouter" });
        vm.label({ account: address(lpStakingTime), newLabel: "StargateLpStaking" });
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
        lpBalance = pool.balanceOf(user);
        pool.approve(address(stargateAssetModule), lpBalance);

        uint256 tokenId = stargateAssetModule.stake(0, address(pool), uint128(lpBalance), msg.sender);

        // The user deposits the ERC1155 in it's Account.
        stargateAssetModule.approve(account, tokenId);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(stargateAssetModule);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = tokenId;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        AccountV1(account).deposit(assetAddresses, assetIds, assetAmounts);

        vm.stopPrank();
    }
}
