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
    IPool public pool = IPool(0x4c80E24119CFB836cdF0a6b53dc23F04F7e652CA);
    address public oracleUSDC = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;

    // https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
    uint256 public poolId = 1;
    uint256 public initBalance = 1000 * 1e6;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StargateBase_Fork_Test.setUp();

        vm.startPrank(users.creatorAddress);

        // Add USDbC and it's Chainlink oracle to the protocol.
        uint256 oracleId = chainlinkOM.addOracle(oracleUSDC, "USDbC", "USD");

        bool[] memory boolValues = new bool[](1);
        boolValues[0] = true;
        uint80[] memory uintValues = new uint80[](1);
        uintValues[0] = uint80(oracleId);

        bytes32 oracleSequence = BitPackingLib.pack(boolValues, uintValues);
        erc20AssetModule.addAsset(address(USDbC), oracleSequence);

        // Add the USDbC pool LP token to the StargateAssetModule.
        stargateAssetModule.addNewStakingToken(address(pool), poolId);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFork_Success_StakeAndDepositInAccount() public {
        assert(pool.balanceOf(users.accountOwner) == 0);

        // A user deposits in the Stargate USDbC pool.
        vm.startPrank(users.accountOwner);
        deal(address(USDbC), users.accountOwner, initBalance);

        USDbC.approve(address(router), initBalance);
        router.addLiquidity(poolId, initBalance, users.accountOwner);
        assert(pool.balanceOf(users.accountOwner) > 0);

        // The user stakes the LP token via the StargateAssetModule
        uint256 stakedAmount = pool.balanceOf(users.accountOwner);
        pool.approve(address(stargateAssetModule), stakedAmount);
        stargateAssetModule.stake(1, uint128(stakedAmount));
        assert(stargateAssetModule.balanceOf(users.accountOwner, 1) == stakedAmount);

        // The user deposits the ERC1155 in it's Account.
        stargateAssetModule.setApprovalForAll(address(proxyAccount), true);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(stargateAssetModule);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = stakedAmount;

        proxyAccount.deposit(assetAddresses, assetIds, assetAmounts);

        vm.stopPrank();
    }
}
