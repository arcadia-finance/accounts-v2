/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { ATokenMock } from "../../.././utils/mocks/ATokenMock.sol";
import { OracleHub } from "../../../../src/OracleHub.sol";
import { RiskConstants } from "../../../../src/libraries/RiskConstants.sol";
import { ATokenPricingModule } from "../../../../src/pricing-modules/ATokenPricingModule.sol";

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
    ATokenMock public aToken2;

    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ATokenPricingModule internal aTokenPricingModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.tokenCreatorAddress);
        aToken1 =
            new ATokenMock(address(mockERC20.token1), "Mocked AAVE Token 1", "maTOKEN1", mockERC20.token1.decimals());
        aToken2 =
            new ATokenMock(address(mockERC20.token2), "Mocked AAVE Token 2", "maTOKEN2", mockERC20.token2.decimals());
        vm.stopPrank();

        vm.startPrank(users.creatorAddress);
        aTokenPricingModule = new ATokenPricingModule(
            address(mainRegistryExtension),
            address(oracleHub),
            0,address(erc20PricingModule)
        );
        mainRegistryExtension.addPricingModule(address(aTokenPricingModule));
        aTokenPricingModule.addAsset(address(aToken1), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }
}
