/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StargateBase_Fork_Test } from "./StargateBase.fork.t.sol";

import { IPool } from "../../../../src/asset-modules/interfaces/stargate/IPool.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Fork tests for "StargateAssetModule - USDbC Pool".
 */
contract StargateAssetModuleUSDbC_Fork_Test is StargateBase_Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    ERC20 USDbC = ERC20(0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA);
    IPool pool = IPool(0x4c80E24119CFB836cdF0a6b53dc23F04F7e652CA);
    address oracleUSDC = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;

    uint256 poolId = 1;
    // https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
    uint256 routerPoolId = 1;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StargateBase_Fork_Test.setUp();

        vm.startPrank(users.creatorAddress);

        // Warp time to last update of oracle + 1 sec
        vm.warp(1_703_147_673 + 1);

        // Add USDbC and it's Chainlink oracle to the protocol.
        // Here we use USDC oracle as no available oracle for USDbC.
        uint256 oracleId = chainlinkOM.addOracle(oracleUSDC, "USDbC", "USD", 2 days);
        bool[] memory boolValues = new bool[](1);
        boolValues[0] = true;
        uint80[] memory uintValues = new uint80[](1);
        uintValues[0] = uint80(oracleId);
        bytes32 oracleSequence = BitPackingLib.pack(boolValues, uintValues);

        erc20AssetModule.addAsset(address(USDbC), oracleSequence);

        // Add the USDbC pool LP token to the StargateAssetModule.
        stargateAssetModule.addAsset(address(pool), poolId);
        vm.stopPrank();

        // Label contracts
        vm.label({ account: address(pool), newLabel: "StargateUSDCPool" });
        vm.label({ account: address(USDbC), newLabel: "USDbC" });
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFork_Success_StakeAndDepositInAccount() public {
        uint256 initBalance = 1000 * 10 ** USDbC.decimals();
        assert(pool.balanceOf(users.accountOwner) == 0);

        // Given : A user deposits in the Stargate USDbC pool, in exchange of an LP token.
        vm.startPrank(users.accountOwner);
        deal(address(USDbC), users.accountOwner, initBalance);

        USDbC.approve(address(router), initBalance);
        router.addLiquidity(routerPoolId, initBalance, users.accountOwner);
        assert(pool.balanceOf(users.accountOwner) > 0);

        // And : The user stakes the LP token via the StargateAssetModule
        uint256 stakedAmount = pool.balanceOf(users.accountOwner);
        pool.approve(address(stargateAssetModule), stakedAmount);
        uint256 tokenId = stargateAssetModule.mint(address(pool), uint128(stakedAmount));

        // The user deposits the position (ERC721 minted)  in it's Account.
        stargateAssetModule.approve(address(proxyAccount), 1);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(stargateAssetModule);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = tokenId;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        proxyAccount.deposit(assetAddresses, assetIds, assetAmounts);
        assert(stargateAssetModule.balanceOf(address(proxyAccount)) == 1);

        vm.stopPrank();
    }

    // On withdrawal of the ERC721 token, the corresponding asset (Stargate LP tokens) and accumulated rewards should be transfered to the user.
    function testFork_Success_Withdraw() public {
        // Given : Amount of underlying assets deposited in Stargate pool.
        uint256 amount1 = 1_000_000 * 10 ** USDbC.decimals();
        uint256 amount2 = 123_456 * 10 ** USDbC.decimals();

        // And : 2 users deploy a new Arcadia Account.
        address payable user1 = createUser("user1");
        address payable user2 = createUser("user2");

        vm.prank(user1);
        address arcadiaAccount1 = factory.createAccount(100, 0, address(0));

        vm.prank(user2);
        address arcadiaAccount2 = factory.createAccount(101, 0, address(0));

        // And : Stake Stargate Pool LP tokens in the Asset Modules and deposit minted ERC721 in Accounts.
        uint256 lpBalance1 = stakeInAssetModuleAndDepositInAccount(user1, arcadiaAccount1, USDbC, amount1, poolId, pool);
        (uint256 amBalanceInLpStaking,) = lpStakingTime.userInfo(poolId, address(stargateAssetModule));
        uint256 lpBalance2 = stakeInAssetModuleAndDepositInAccount(user2, arcadiaAccount2, USDbC, amount2, poolId, pool);

        (amBalanceInLpStaking,) = lpStakingTime.userInfo(poolId, address(stargateAssetModule));
        assert(lpBalance1 + lpBalance2 == amBalanceInLpStaking);

        // And : We let 30 days pass to accumulate rewards.
        vm.warp(block.timestamp + 30 days);

        // And : User1 withdraws 1/2 position.
        vm.prank(arcadiaAccount1);
        stargateAssetModule.decreaseLiquidity(1, uint128(lpBalance1 / 2));
        assert(lpStakingTime.eToken().balanceOf(arcadiaAccount1) > 0);

        // And : User2 withdraws fully
        vm.prank(arcadiaAccount2);
        stargateAssetModule.burn(2);
        assert(lpStakingTime.eToken().balanceOf(arcadiaAccount2) > 0);

        // And : User2 decides to stake again via the AM.
        lpBalance2 = stakeInAssetModuleAndDepositInAccount(user2, arcadiaAccount2, USDbC, amount2, poolId, pool);

        // And : We let 30 days pass to accumulate rewards.
        vm.warp(block.timestamp + 30 days);
        emit log_named_uint("pendingEmissions", lpStakingTime.pendingEmissionToken(1, address(stargateAssetModule)));

        // When : Both users withdraw fully (withdraw and claim rewards).
        vm.prank(arcadiaAccount2);
        stargateAssetModule.burn(3);

        (amBalanceInLpStaking,) = lpStakingTime.userInfo(poolId, address(stargateAssetModule));

        (,, uint128 totalStaked) = stargateAssetModule.assetState(address(pool));

        (, uint128 remainingBalanceAccount1,,) = stargateAssetModule.positionState(1);

        vm.prank(arcadiaAccount1);
        stargateAssetModule.burn(1);

        // Then : Values should be correct
        uint256 rewardsAccount1 = lpStakingTime.eToken().balanceOf(arcadiaAccount1);
        uint256 rewardsAccount2 = lpStakingTime.eToken().balanceOf(arcadiaAccount2);
        emit log_named_uint("STG rewards Account 1", rewardsAccount1);
        emit log_named_uint("STG rewards Account 2", rewardsAccount2);

        assert(rewardsAccount1 > rewardsAccount2);

        (, remainingBalanceAccount1,,) = stargateAssetModule.positionState(1);
        (, uint128 remainingBalanceAccount2,,) = stargateAssetModule.positionState(3);

        assert(remainingBalanceAccount1 == 0);
        assert(remainingBalanceAccount2 == 0);

        (,, totalStaked) = stargateAssetModule.assetState(address(pool));
        assert(totalStaked == 0);
    }
}
