/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { AccountExtension } from "../../../utils/Extensions.sol";
import { ActionMultiCallV2 } from "../../../../src/actions/MultiCallV2.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";
import { MultiActionMock } from "../../../utils/mocks/MultiActionMock.sol";

/**
 * @notice Common logic needed by all "MultiCall" fuzz tests.
 */
abstract contract MultiCall_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    uint256 internal numberStored;

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ActionMultiCallV2 internal action;
    MultiActionMock internal multiActionMock;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        action = new ActionMultiCallV2();
    }

    /* ///////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
    function setNumberStored(uint256 number) public {
        numberStored = number;
    }
}
