/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../../../lib/forge-std/src/Test.sol";

import { ICLQuoter } from "./interfaces/ICLQuoter.sol";
import { Utils } from "../../../utils/Utils.sol";

contract CLQuoterFixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ICLQuoter internal clQuoter;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function deployQuoter(address factory_, address weth9_) public {
        // Get the bytecode of the Quoter.
        bytes memory args = abi.encode(factory_, weth9_);
        bytes memory bytecode = abi.encodePacked(vm.getCode("CLQuoterV2Extension.sol"), args);

        address quoter_ = Utils.deployBytecode(bytecode);
        clQuoter = ICLQuoter(quoter_);
    }
}
