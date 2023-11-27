/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { ERC4626Mock } from "../../../utils/mocks/ERC4626Mock.sol";
import { ERC4626AssetModuleExtension } from "../../../utils/Extensions.sol";
import { AssetModule } from "../../../../src/asset-modules/AbstractAssetModule.sol";
import { StandardERC4626AssetModule } from "../../../../src/asset-modules/StandardERC4626AssetModule.sol";

/**
 * @notice Common logic needed by all "StandardERC4626AssetModule" fuzz tests.
 */
abstract contract StandardERC4626AssetModule_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    ERC4626Mock public ybToken1;

    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ERC4626AssetModuleExtension internal erc4626AssetModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.tokenCreatorAddress);
        ybToken1 = new ERC4626Mock(mockERC20.token1, "Mocked Yield Bearing Token 1", "mybTOKEN1");

        vm.startPrank(users.creatorAddress);
        erc4626AssetModule = new ERC4626AssetModuleExtension(address(registryExtension));
        registryExtension.addAssetModule(address(erc4626AssetModule));
        vm.stopPrank();
    }
}
