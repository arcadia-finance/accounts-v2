/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StargateBase_Fork_Test } from "./StargateBase.fork.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Fork tests for "StargateAssetModule - USDbC Pool".
 */
contract StargateAssetModuleUSDC_Fork_Test is StargateBase_Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    ERC20 USDbC = ERC20(0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA);
    address public oracleUSDC = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StargateBase_Fork_Test.setUp();

        vm.startPrank(users.creatorAddress);

        uint256 oracleId = chainlinkOM.addOracle(oracleUSDC, "USDbC", "USD");

        bool[] memory boolValues = new bool[](1);
        boolValues[0] = true;
        uint80[] memory uintValues = new uint80[](1);
        uintValues[0] = uint80(oracleId);

        bytes32 oracleSequence = BitPackingLib.pack(boolValues, uintValues);
        erc20AssetModule.addAsset(address(USDbC), oracleSequence);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFork_Success() public {
        // User deposits and receive LP

        // User stakes LP via StargateAssetModule

        // User deposits
    }
}
