/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { ERC4626Mock } from "../../../utils/mocks/tokens/ERC4626Mock.sol";
import { ERC4626AMExtension } from "../../../utils/Extensions.sol";
import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { StandardERC4626AM } from "../../../utils/mocks/asset-modules/StandardERC4626AM.sol";

/**
 * @notice Common logic needed by all "StandardERC4626AM" fuzz tests.
 */
abstract contract StandardERC4626AM_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    ERC4626Mock public ybToken1;

    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ERC4626AMExtension internal erc4626AM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.tokenCreatorAddress);
        ybToken1 = new ERC4626Mock(mockERC20.token1, "Mocked Yield Bearing Token 1", "mybTOKEN1");

        vm.startPrank(users.creatorAddress);
        erc4626AM = new ERC4626AMExtension(address(registryExtension));
        registryExtension.addAssetModule(address(erc4626AM));
        vm.stopPrank();
    }
}
