/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Metadex03CLAM_Fuzz_Test } from "./_Metadex03CLAM.fuzz.t.sol";
import { Metadex03CLAMExtension } from "../../../utils/extensions/Metadex03CLAMExtension.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "Metadex03CLAM".
 */
contract Constructor_Metadex03CLAM_Fuzz_Test is Metadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Metadex03CLAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_constructor(address owner_, address registry_) public {
        // Given: The protocol owner is the deployer.
        vm.prank(users.owner);

        // When: A Metadex03 CL Asset Module is deployed.
        // forge-lint: disable-next-line(mixed-case-variable)
        Metadex03CLAMExtension metadex03CLAM_ =
            new Metadex03CLAMExtension(owner_, registry_, address(metadex03PositionManager));

        // Then: The constructor arguments are stored.
        assertEq(metadex03CLAM_.owner(), owner_);
        assertEq(metadex03CLAM_.REGISTRY(), registry_);
        assertEq(metadex03CLAM_.ASSET_TYPE(), 2);
        assertEq(metadex03CLAM_.getNonfungiblePositionManager(), address(metadex03PositionManager));

        // And: The CL Factory of the NonfungiblePositionManager is stored.
        assertEq(metadex03CLAM_.getCLFactory(), address(metadex03CLFactory));
    }
}
