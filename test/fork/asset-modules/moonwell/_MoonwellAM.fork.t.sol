/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { Fork_Test } from "../../Fork.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { MoonwellAMExtension } from "../../../utils/extensions/MoonwellAMExtension.sol";

/**
 * @notice Base test file for Moonwell Asset-Module fork tests.
 */
contract MoonwellAM_Fork_Test is Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    MoonwellAMExtension public moonwellAM;
    address WELL = 0xA88594D404727625A9437C3f886C7643872296AE;
    address MOONWELL_VIEWS = 0x6834770ABA6c2028f448E3259DDEE4BCB879d459;
    address COMPTROLLER = 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Fork_Test.setUp();

        // Deploy moonwellAM
        vm.startPrank(users.creatorAddress);
        moonwellAM = new MoonwellAMExtension(
            address(registryExtension), "Arcadia Moonwell AM", "AMA", MOONWELL_VIEWS, COMPTROLLER
        );
        vm.stopPrank();

        // Label contracts
        vm.label({ account: address(moonwellAM), newLabel: "Moonwell AM" });
    }
}
