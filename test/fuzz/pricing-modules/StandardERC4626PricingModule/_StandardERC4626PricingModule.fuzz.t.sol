/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { ERC4626Mock } from "../../.././utils/mocks/ERC4626Mock.sol";
import { OracleHub } from "../../../../src/OracleHub.sol";
import { RiskConstants } from "../../../../src/libraries/RiskConstants.sol";
import { StandardERC4626PricingModule } from "../../../../src/pricing-modules/StandardERC4626PricingModule.sol";

/**
 * @notice Common logic needed by all "StandardERC4626PricingModule" fuzz tests.
 */
abstract contract StandardERC4626PricingModule_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    uint16 internal collateralFactor = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    uint16 internal liquidationFactor = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;

    ERC4626Mock public ybToken1;

    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    StandardERC4626PricingModule internal erc4626PricingModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.tokenCreatorAddress);
        ybToken1 = new ERC4626Mock(mockERC20.token1, "Mocked Yield Bearing Token 1", "mybTOKEN1");

        vm.startPrank(users.creatorAddress);
        erc4626PricingModule = new StandardERC4626PricingModule(
            address(mainRegistryExtension),
            address(oracleHub),
            0,address(erc20PricingModule)
        );
        mainRegistryExtension.addPricingModule(address(erc4626PricingModule));
        vm.stopPrank();
    }
}
