/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StargateBase_Fork_Test } from "./StargateBase.fork.t.sol";

import { IPool } from "../../../../src/asset-modules/Stargate-Finance/interfaces/IPool.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Fork tests for "StargateAssetModule - USDbC Pool".
 */
contract StargateAM_USDbC_Fork_Test is StargateBase_Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    ERC20 USDbC = ERC20(0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA);
    IPool pool = IPool(0x4c80E24119CFB836cdF0a6b53dc23F04F7e652CA);
    address oracleUSDC = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;

    uint256 pid = 1;
    // https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
    uint256 poolId = 1;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StargateBase_Fork_Test.setUp();

        vm.startPrank(users.creatorAddress);

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
        stargateAssetModule.addAsset(poolId);

        // Add the staked USDbC pool LP token to the StakedStargateAssetModule.
        stakedStargateAM.addAsset(pid);
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
        assert(ERC20(address(pool)).balanceOf(users.accountOwner) == 0);

        // Given : A user deposits in the Stargate USDbC pool, in exchange of an LP token.
        vm.startPrank(users.accountOwner);
        deal(address(USDbC), users.accountOwner, initBalance);

        USDbC.approve(address(router), initBalance);
        router.addLiquidity(poolId, initBalance, users.accountOwner);
        assert(ERC20(address(pool)).balanceOf(users.accountOwner) > 0);

        // And : The user stakes the LP token via the StargateAssetModule
        uint256 stakedAmount = ERC20(address(pool)).balanceOf(users.accountOwner);
        ERC20(address(pool)).approve(address(stakedStargateAM), stakedAmount);
        uint256 tokenId = stakedStargateAM.mint(address(pool), uint128(stakedAmount));

        // The user deposits the position (ERC721 minted) in its Account.
        stakedStargateAM.approve(address(proxyAccount), 1);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(stakedStargateAM);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = tokenId;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        proxyAccount.deposit(assetAddresses, assetIds, assetAmounts);
        assert(stakedStargateAM.balanceOf(address(proxyAccount)) == 1);

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
        uint256 lpBalance1 = stakeInAssetModuleAndDepositInAccount(user1, arcadiaAccount1, USDbC, amount1, pid, pool);
        uint256 lpBalance2 = stakeInAssetModuleAndDepositInAccount(user2, arcadiaAccount2, USDbC, amount2, pid, pool);

        (uint256 amBalanceInLpStaking,) = lpStakingTime.userInfo(pid, address(stakedStargateAM));
        assert(lpBalance1 + lpBalance2 == amBalanceInLpStaking);

        // And : We let 30 days pass to accumulate rewards.
        vm.warp(block.timestamp + 30 days);

        // And : User1 withdraws 1/2 position.
        vm.prank(arcadiaAccount1);
        stakedStargateAM.decreaseLiquidity(1, uint128(lpBalance1 / 2));
        assert(lpStakingTime.eToken().balanceOf(arcadiaAccount1) > 0);

        // And : User2 withdraws fully
        vm.prank(arcadiaAccount2);
        stakedStargateAM.burn(2);
        assert(lpStakingTime.eToken().balanceOf(arcadiaAccount2) > 0);

        // And : User2 decides to stake again via the AM.
        lpBalance2 = stakeInAssetModuleAndDepositInAccount(user2, arcadiaAccount2, USDbC, amount2, pid, pool);

        // And : We let 30 days pass to accumulate rewards.
        vm.warp(block.timestamp + 30 days);
        emit log_named_uint("pendingEmissions", lpStakingTime.pendingEmissionToken(1, address(stakedStargateAM)));

        // When : Both users withdraw fully (withdraw and claim rewards).
        vm.prank(arcadiaAccount2);
        stakedStargateAM.burn(3);

        (amBalanceInLpStaking,) = lpStakingTime.userInfo(pid, address(stakedStargateAM));

        (,,, uint128 totalStaked) = stakedStargateAM.assetState(address(pool));

        (, uint128 remainingBalanceAccount1,,) = stakedStargateAM.positionState(1);

        vm.prank(arcadiaAccount1);
        stakedStargateAM.burn(1);

        // Then : Values should be correct
        uint256 rewardsAccount1 = lpStakingTime.eToken().balanceOf(arcadiaAccount1);
        uint256 rewardsAccount2 = lpStakingTime.eToken().balanceOf(arcadiaAccount2);
        emit log_named_uint("STG rewards Account 1", rewardsAccount1);
        emit log_named_uint("STG rewards Account 2", rewardsAccount2);

        assert(rewardsAccount1 > rewardsAccount2);

        (, remainingBalanceAccount1,,) = stakedStargateAM.positionState(1);
        (, uint128 remainingBalanceAccount2,,) = stakedStargateAM.positionState(3);

        assert(remainingBalanceAccount1 == 0);
        assert(remainingBalanceAccount2 == 0);

        (,,, totalStaked) = stakedStargateAM.assetState(address(pool));
        assert(totalStaked == 0);
    }

    // The withdrawal of a zero amount should trigger the claim of the rewards
    function testFork_Success_claimReward() public {
        uint256 initBalance = 1000 * 10 ** USDbC.decimals();
        assert(ERC20(address(pool)).balanceOf(users.accountOwner) == 0);

        // Given : A user deposits in the Stargate USDbC pool, in exchange of an LP token.
        vm.startPrank(users.accountOwner);
        deal(address(USDbC), users.accountOwner, initBalance);

        USDbC.approve(address(router), initBalance);
        router.addLiquidity(poolId, initBalance, users.accountOwner);
        assert(ERC20(address(pool)).balanceOf(users.accountOwner) > 0);

        // And : The user stakes the LP token via the StargateAssetModule
        uint256 stakedAmount = ERC20(address(pool)).balanceOf(users.accountOwner);
        ERC20(address(pool)).approve(address(stakedStargateAM), stakedAmount);
        uint256 tokenId = stakedStargateAM.mint(address(pool), uint128(stakedAmount));

        // And : We let 30 days pass to accumulate rewards.
        vm.warp(block.timestamp + 30 days);

        assert(lpStakingTime.eToken().balanceOf(users.accountOwner) == 0);

        // When : We claim rewards for the position
        stakedStargateAM.claimReward(tokenId);

        // Then : Reward should have been received
        assert(lpStakingTime.eToken().balanceOf(users.accountOwner) > 0);

        vm.stopPrank();
    }
}
