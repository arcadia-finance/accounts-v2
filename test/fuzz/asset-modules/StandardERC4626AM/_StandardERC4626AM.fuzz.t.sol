/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { ERC4626Mock } from "../../../utils/mocks/tokens/ERC4626Mock.sol";
import { ERC4626AMExtension } from "../../../utils/extensions/ERC4626AMExtension.sol";

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

    /// forge-lint: disable-next-line(mixed-case-variable)
    ERC4626AMExtension internal erc4626AM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.tokenCreator);
        ybToken1 = new ERC4626Mock(mockERC20.token1, "Mocked Yield Bearing Token 1", "mybTOKEN1");

        vm.startPrank(users.owner);
        erc4626AM = new ERC4626AMExtension(users.owner, address(registry));
        registry.addAssetModule(address(erc4626AM));
        vm.stopPrank();
    }
}
