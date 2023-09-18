/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MultiCall_Fuzz_Test } from "./_MultiCall.fuzz.t.sol";

import "../../../../src/actions/utils/ActionData.sol";

/**
 * @notice Fuzz tests for the "executeAction" of contract "MultiCall".
 */
contract ExecuteAction_MultiCall_Fuzz_Test is MultiCall_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MultiCall_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_executeAction_lengthMismatch() public {
        ActionData memory assetData = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        ActionData memory fromOwner;

        assetData.assets[0] = address(mockERC20.token1);
        assetData.assetTypes[0] = 0;

        address[] memory to = new address[](2);
        bytes[] memory data = new bytes[](1);
        to[0] = address(this);
        to[1] = address(this);
        data[0] = abi.encodeWithSignature("returnFive()");

        bytes memory callData = abi.encode(assetData, assetData, fromOwner, to, data);

        vm.expectRevert("EA: Length mismatch");
        action.executeAction(callData);
    }

    function testFuzz_Success_executeAction_storeNumber(uint256 number) public {
        ActionData memory assetData = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        ActionData memory fromOwner;

        assetData.assets[0] = address(mockERC20.token1);
        assetData.assetTypes[0] = 0;

        address[] memory to = new address[](1);
        bytes[] memory data = new bytes[](1);
        to[0] = address(this);
        data[0] = abi.encodeWithSignature("setNumberStored(uint256)", number);

        bytes memory callData = abi.encode(assetData, assetData, fromOwner, to, data);

        action.executeAction(callData);

        assertEq(numberStored, number);
    }
}
