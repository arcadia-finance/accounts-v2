/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { ATokenMock } from "../../../../mockups/ATokenMock.sol";
import { OracleHub_UsdOnly } from "../../../../OracleHub_UsdOnly.sol";
import { RiskConstants } from "../../../../utils/RiskConstants.sol";
import { ATokenPricingModule_UsdOnly } from "../../../../pricing-modules/ATokenPricingModule_UsdOnly.sol";

/**
 * @notice Common logic needed by all "ATokenPricingModule" fuzz tests.
 */
abstract contract ATokenPricingModule_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    uint16 internal collateralFactor = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    uint16 internal liquidationFactor = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;

    ATokenMock public aToken1;

    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ATokenPricingModule_UsdOnly internal aTokenPricingModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.tokenCreatorAddress);
        aToken1 =
            new ATokenMock(address(mockERC20.token1), "Mocked AAVE Token 1", "maTOKEN1", mockERC20.token1.decimals());

        vm.startPrank(users.creatorAddress);
        aTokenPricingModule = new ATokenPricingModule_UsdOnly(
            address(mainRegistryExtension),
            address(oracleHub),
            0,address(erc20PricingModule)
        );
        mainRegistryExtension.addPricingModule(address(aTokenPricingModule));
        vm.stopPrank();
    }
}
