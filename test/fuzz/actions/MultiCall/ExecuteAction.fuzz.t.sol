/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { MultiCall_Fuzz_Test } from "./_MultiCall.fuzz.t.sol";

import { IActionBase, ActionData } from "../../../../src/interfaces/IActionBase.sol";
import "../../../../src/interfaces/IPermit2.sol";

/**
 * @notice Fuzz tests for the function "executeAction" of contract "MultiCall".
 */
contract ExecuteAction_MultiCall_Fuzz_Test is MultiCall_Fuzz_Test {
    address[] mintedAssets;
    uint256[] mintedIds;

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
            assetTypes: new uint256[](1)
        });

        ActionData memory fromOwner;
        assetData.assets[0] = address(mockERC20.token1);
        assetData.assetTypes[0] = 0;

        address[] memory to = new address[](2);
        bytes[] memory data = new bytes[](1);
        to[0] = address(this);
        to[1] = address(this);
        data[0] = abi.encodeWithSignature("returnFive()");

        vm.expectRevert(LengthMismatch.selector);
        action.executeAction(fromOwner, to, data);
    }

    function testFuzz_Success_executeAction_storeNumber(uint256 number) public {
        ActionData memory assetData = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1)
        });

        ActionData memory fromOwner;
        assetData.assets[0] = address(mockERC20.token1);
        assetData.assetTypes[0] = 0;

        address[] memory to = new address[](1);
        bytes[] memory data = new bytes[](1);
        to[0] = address(this);
        data[0] = abi.encodeWithSignature("setNumberStored(uint256)", number);

        action.executeAction(fromOwner, to, data);

        assertEq(numberStored, number);
    }

    function createRandomDepositData(address[15] memory assets)
        public
        returns (ActionData memory, address[] memory, uint256[] memory)
    {
        uint256[] memory types = new uint256[](assets.length);
        uint256[] memory ids = new uint256[](assets.length);
        uint256[] memory amounts = new uint256[](assets.length);
        address[] memory assets_ = new address[](assets.length);

        // create semi random ids
        // create semi random alternation of amount == 0 or 1
        for (uint256 i; i < assets.length; i++) {
            types[i] = 1;
            ids[i] = uint256(uint160(assets[i]));
            amounts[i] = bound(ids[i] % 4, 0, 1);
            assets_[i] = assets[i];
        }

        // all entries with amount == 0 must go to the minted arrays
        for (uint256 i; i < assets.length; i++) {
            if (amounts[i] == 0) {
                mintedAssets.push(assets[i]);
                mintedIds.push(ids[i]);
            }
        }

        ActionData memory depositData =
            ActionData({ assets: assets_, assetIds: ids, assetAmounts: amounts, assetTypes: types });

        address[] memory mintedAssets_ = mintedAssets;
        uint256[] memory mintedIds_ = mintedIds;

        return (depositData, mintedAssets_, mintedIds_);
    }

    function testFuzz_Success_executeAction_storeMintedLPs(address[15] memory assets) public {
        (ActionData memory depositData, address[] memory mintedAssets_, uint256[] memory mintedIds_) =
            createRandomDepositData(assets);

        action.setMintedAssets(mintedAssets_);
        action.setMintedIds(mintedIds_);

        ActionData memory returnData = action.executeAction(depositData, new address[](0), new bytes[](0));

        assertEq(returnData.assets.length, depositData.assets.length);

        // check that all addresses are returned with their correct ID
        for (uint256 i; i < depositData.assets.length; i++) {
            address depositAddress = depositData.assets[i];
            uint256 depositId = depositData.assetIds[i];
            for (uint256 y; y < returnData.assets.length; y++) {
                address returnAddress = returnData.assets[y];
                uint256 returnId = returnData.assetIds[y];
                if (depositAddress == returnAddress && depositId == returnId) {
                    break;
                }
                if (y == returnData.assets.length - 1) {
                    fail("asset not found in returnData.assets");
                }
            }
        }
    }
}
