/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { StandardERC20PricingModule_Fuzz_Test } from "./_StandardERC20PricingModule.fuzz.t.sol";

import { ArcadiaOracle } from "../../../utils/mocks/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

import { Constants } from "../../../utils/Constants.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";
import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";
import {
    PrimaryPricingModule,
    StandardERC20PricingModule
} from "../../../../src/pricing-modules/StandardERC20PricingModule.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "StandardERC20PricingModule".
 */
contract AddAsset_StandardERC20PricingModule_Fuzz_Test is StandardERC20PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC20PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.prank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        erc20PricingModule.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);
    }

    function testFuzz_Revert_addAsset_BadOracleSequence() public {
        bool[] memory badDirection = new bool[](1);
        badDirection[0] = false;
        uint80[] memory oracleToken4ToUsdArr = new uint80[](1);
        oracleToken4ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token4ToUsd)));
        bytes32 badSequence = BitPackingLib.pack(badDirection, oracleToken4ToUsdArr);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PM20_AA: Bad Sequence");
        erc20PricingModule.addAsset(address(mockERC20.token4), badSequence);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(users.creatorAddress);
        erc20PricingModule.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);
        vm.expectRevert("MR_AA: Asset already in mainreg");
        erc20PricingModule.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_MoreThan18Decimals() public {
        ArcadiaOracle oracle = initMockedOracle(0, "ASSET / USD");
        vm.startPrank(users.tokenCreatorAddress);
        ERC20Mock asset = new ERC20Mock("ASSET", "ASSET", 19);
        chainlinkOM.addOracle(address(oracle), "ASSET", "USD");
        vm.stopPrank();

        uint80[] memory oracleAssetToUsdArr = new uint80[](1);
        oracleAssetToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(oracle)));

        vm.prank(users.creatorAddress);
        vm.expectRevert("PM20_AA: Maximal 18 decimals");
        erc20PricingModule.addAsset(address(asset), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAssetToUsdArr));
    }

    function testFuzz_Success_addAsset() public {
        vm.prank(users.creatorAddress);
        erc20PricingModule.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);

        assertTrue(erc20PricingModule.inPricingModule(address(mockERC20.token4)));
        assertTrue(erc20PricingModule.isAllowed(address(mockERC20.token4), 0));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token4)));
        (uint64 assetUnit, bytes32 oracles) = erc20PricingModule.assetToInformation(assetKey);
        assertEq(assetUnit, 10 ** Constants.tokenDecimals);
        assertEq(oracles, oraclesToken4ToUsd);

        assertTrue(mainRegistryExtension.inMainRegistry(address(mockERC20.token4)));
        (uint96 assetType_, address pricingModule) =
            mainRegistryExtension.assetToAssetInformation(address(mockERC20.token4));
        assertEq(assetType_, 0);
        assertEq(pricingModule, address(erc20PricingModule));
    }
}
