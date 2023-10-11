/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, StandardERC4626PricingModule_Fuzz_Test } from "./_StandardERC4626PricingModule.fuzz.t.sol";
import { IPricingModule } from "../../../../src/interfaces/IPricingModule.sol";
import { ERC4626Mock } from "../../.././utils/mocks/ERC4626Mock.sol";
import { ERC4626PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "_getUnderlyingAssetsAmounts()" of contract "StandardERC4626PricingModule".
 */
contract GetUnderlyingAssetsAmounts_StandardERC4626PricingModule_Fuzz_Test is StandardERC4626PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    ERC4626Mock public ybToken2;

    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ERC4626PricingModuleExtension public erc4626PricingModuleExtension;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626PricingModule_Fuzz_Test.setUp();

        vm.prank(users.tokenCreatorAddress);
        ybToken2 = new ERC4626Mock(mockERC20.stable1, "Mocked Yield Bearing Token 2", "ybTOKEN2");

        vm.startPrank(users.creatorAddress);
        erc4626PricingModuleExtension = new ERC4626PricingModuleExtension(
            address(mainRegistryExtension),
            address(oracleHub),
            0,address(erc20PricingModule)
        );
        mainRegistryExtension.addPricingModule(address(erc4626PricingModuleExtension));

        erc4626PricingModuleExtension.addAsset(address(ybToken1), emptyRiskVarInput);
        erc4626PricingModuleExtension.addAsset(address(ybToken2), emptyRiskVarInput);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getUnderlyingAssetsAmounts(
        uint128 initialAssets,
        uint128 depositAmount,
        uint96 assetId,
        uint128 yield
    ) public {
        // Given: "initialAssets" is non-zero.
        initialAssets = uint128(bound(initialAssets, 1, type(uint128).max));

        // And: asset <-> share conversions do not overflow.
        yield = uint128(bound(yield, 0, type(uint128).max - initialAssets));

        // And: "depositAmount" is less than the accountOwner's balance.
        depositAmount = uint128(bound(depositAmount, 0, initialAssets));

        // Mint tokens, do a deposit, and send tokens to vault (=yield)
        vm.startPrank(users.accountOwner);
        mockERC20.stable1.mint(users.accountOwner, uint256(initialAssets) + uint256(yield));
        mockERC20.stable1.approve(address(ybToken2), initialAssets);
        ybToken2.deposit(initialAssets, users.accountOwner);
        mockERC20.stable1.transfer(address(ybToken2), yield);
        vm.stopPrank();

        uint256 expectedConversionRate = depositAmount * (uint256(initialAssets) + yield) / initialAssets;

        bytes32 assetKey = bytes32(abi.encodePacked(assetId, address(ybToken2)));
        bytes32[] memory emptyArray = new bytes32[](1);
        uint256[] memory exposureAssetToUnderlyingAssets =
            erc4626PricingModuleExtension.getUnderlyingAssetsAmounts(assetKey, depositAmount, emptyArray);

        assertEq(expectedConversionRate, exposureAssetToUnderlyingAssets[0]);
    }
}
