/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { ERC4626Mock } from "../../../utils/mocks/ERC4626Mock.sol";
import { ERC4626PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Common logic needed by all "StandardERC4626PricingModule" fuzz tests.
 */
abstract contract StandardERC4626PricingModule_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    ERC4626Mock public ybToken1;

    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ERC4626PricingModuleExtension internal erc4626PricingModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.tokenCreatorAddress);
        ybToken1 = new ERC4626Mock(mockERC20.token1, "Mocked Yield Bearing Token 1", "mybTOKEN1");

        vm.startPrank(users.creatorAddress);
        erc4626PricingModule = new ERC4626PricingModuleExtension(
            address(mainRegistryExtension)
        );
        mainRegistryExtension.addPricingModule(address(erc4626PricingModule));
        vm.stopPrank();
    }
}
