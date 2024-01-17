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
contract StargateAssetModuleETH_Fork_Test is StargateBase_Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    ERC20 SGETH = ERC20(0x224D8Fd7aB6AD4c6eb4611Ce56EF35Dec2277F03);
    IPool pool = IPool(0x28fc411f9e1c480AD312b3d9C60c22b965015c6B);
    address oracleETH = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;

    uint256 poolId = 0;
    // https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
    uint256 routerPoolId = 13;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StargateBase_Fork_Test.setUp();

        vm.startPrank(users.creatorAddress);

        // Warp time to last update of oracle + 1 sec
        vm.warp(1_703_149_989 + 1);

        // Add SGETH and it's Chainlink oracle to the protocol.
        // Here we use USDC oracle as no available oracle for USDbC.
        uint256 oracleId = chainlinkOM.addOracle(oracleETH, "ETH", "USD", 2 days);
        bool[] memory boolValues = new bool[](1);
        boolValues[0] = true;
        uint80[] memory uintValues = new uint80[](1);
        uintValues[0] = uint80(oracleId);
        bytes32 oracleSequence = BitPackingLib.pack(boolValues, uintValues);

        erc20AssetModule.addAsset(address(SGETH), oracleSequence);

        // Add the ETH pool LP token to the StargateAssetModule.
        stargateAssetModule.addAsset(address(pool), poolId);
        vm.stopPrank();

        // Label contracts
        vm.label({ account: address(pool), newLabel: "StargateETHPool" });
        vm.label({ account: address(SGETH), newLabel: "SGETH" });
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFork_Success_StakeAndDepositInAccount() public {
        uint256 initBalance = 1000 * 10 ** SGETH.decimals();
        assert(pool.balanceOf(users.accountOwner) == 0);

        // Given : A user deposits in the Stargate ETH pool, in exchange of an LP token.
        vm.startPrank(users.accountOwner);
        deal(address(SGETH), users.accountOwner, initBalance);

        SGETH.approve(address(router), initBalance);
        router.addLiquidity(routerPoolId, initBalance, users.accountOwner);
        assert(pool.balanceOf(users.accountOwner) > 0);

        // And : The user stakes the LP token via the StargateAssetModule
        uint256 stakedAmount = pool.balanceOf(users.accountOwner);
        pool.approve(address(stargateAssetModule), stakedAmount);
        uint256 tokenId = stargateAssetModule.mint(address(pool), uint128(stakedAmount));

        // The user deposits the newly minted position (ERC721) in its Account.
        stargateAssetModule.approve(address(proxyAccount), tokenId);

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

    // On withdrawal, the corresponding asset (Stargate LP tokens) and accumulated rewards should be transfered to the user.
    function testFork_Success_Withdraw() public {
        // Given : Amount of underlying assets deposited in Stargate pool.
        uint256 amount1 = 1000 * 10 ** SGETH.decimals();
        uint256 amount2 = 123 * 10 ** SGETH.decimals();

        // And : 2 users deploy a new Arcadia Account.
        address payable user1 = createUser("user1");
        address payable user2 = createUser("user2");

        vm.prank(user1);
        address arcadiaAccount1 = factory.createAccount(100, 0, address(0));

        vm.prank(user2);
        address arcadiaAccount2 = factory.createAccount(101, 0, address(0));

        // And : Stake Stargate Pool LP tokens in the Asset Modules and deposit minted positions (ERC721) in Accounts.
        uint256 lpBalance1 =
            stakeInAssetModuleAndDepositInAccount(user1, arcadiaAccount1, SGETH, amount1, routerPoolId, pool);
        (uint256 amBalanceInLpStaking,) = lpStakingTime.userInfo(poolId, address(stargateAssetModule));
        uint256 lpBalance2 =
            stakeInAssetModuleAndDepositInAccount(user2, arcadiaAccount2, SGETH, amount2, routerPoolId, pool);

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
        lpBalance2 = stakeInAssetModuleAndDepositInAccount(user2, arcadiaAccount2, SGETH, amount2, routerPoolId, pool);

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
