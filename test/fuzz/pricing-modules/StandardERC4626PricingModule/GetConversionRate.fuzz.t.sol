/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, StandardERC4626PricingModule_Fuzz_Test } from "./_StandardERC4626PricingModule.fuzz.t.sol";
import { IPricingModule_New } from "../../../../src/interfaces/IPricingModule_New.sol";
import { ERC4626Mock } from "../../.././utils/mocks/ERC4626Mock.sol";
import { ERC4626PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "_getConversionRate()" of contract "StandardERC4626PricingModule".
 */
contract GetConversionRate_StandardERC4626PricingModule_Fuzz_Test is StandardERC4626PricingModule_Fuzz_Test {
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

        erc4626PricingModuleExtension.addAsset(address(ybToken1), emptyRiskVarInput_New);
        erc4626PricingModuleExtension.addAsset(address(ybToken2), emptyRiskVarInput_New);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getConversionRate(uint128 depositAmount, uint96 yield) public {
        vm.assume(depositAmount > 0);
        // Mint tokens, do a deposit, an send tokens to vault (=yield)
        vm.startPrank(users.accountOwner);
        mockERC20.stable1.mint(users.accountOwner, uint256(depositAmount) + uint256(yield));
        mockERC20.stable1.transfer(address(ybToken2), yield);
        mockERC20.stable1.approve(address(ybToken2), depositAmount);
        ybToken2.deposit(depositAmount, users.accountOwner);
        vm.stopPrank();

        uint256 expectedConversionRate =
            ((uint256(depositAmount) + uint256(yield)) * 10 ** 6 / ybToken2.totalSupply()) * 10 ** 12;

        address[] memory emptyArray = new address[](1);
        uint256[] memory conversionRates =
            erc4626PricingModuleExtension.getConversionRates(address(ybToken2), emptyArray);

        // "conversionRate" will always return in 18 decimals, as underlying token has 6 decimals we could lose some precision in our calculation of "expectedConversionRate", thus we divide by 10 ** 12.
        assertEq(expectedConversionRate / 10e12, conversionRates[0] / 10e12);
        emit log_named_uint("expectedConversionRate", expectedConversionRate);
        emit log_named_uint("conversionRate", conversionRates[0]);
    }
}
