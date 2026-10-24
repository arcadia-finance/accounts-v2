/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { SlipstreamAM_Fuzz_Test } from "./_SlipstreamAM.fuzz.t.sol";
import { SlipstreamAMExtension } from "../../../utils/extensions/SlipstreamAMExtension.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "SlipstreamAM".
 */
contract Constructor_SlipstreamAM_Fuzz_Test is SlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        SlipstreamAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_constructor(address owner_, address registry_) public {
        // Given: The protocol owner is the deployer.
        vm.prank(users.owner);

        // When: A Slipstream Asset Module is deployed.
        // forge-lint: disable-next-line(mixed-case-variable)
        SlipstreamAMExtension slipstreamAM_ =
            new SlipstreamAMExtension(owner_, registry_, address(slipstreamPositionManager));

        // Then: The constructor arguments are stored.
        assertEq(slipstreamAM_.owner(), owner_);
        assertEq(slipstreamAM_.REGISTRY(), registry_);
        assertEq(slipstreamAM_.ASSET_TYPE(), 2);
        assertEq(slipstreamAM_.getNonFungiblePositionManager(), address(slipstreamPositionManager));

        // And: The CL Factory of the NonfungiblePositionManager is stored.
        assertEq(slipstreamAM_.getUniswapV3Factory(), address(cLFactory));
    }
}
