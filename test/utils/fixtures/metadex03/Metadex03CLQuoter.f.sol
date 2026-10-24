/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Test } from "../../../../lib/forge-std/src/Test.sol";

import { ICLQuoter } from "../slipstream/interfaces/ICLQuoter.sol";
import { Utils } from "../../Utils.sol";

contract Metadex03CLQuoterFixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    // forge-lint: disable-next-line(mixed-case-variable)
    ICLQuoter internal metadex03CLQuoter;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function deployMetadex03Quoter(address factory_, address weth9_) public {
        // Get the bytecode of the Quoter.
        bytes memory args = abi.encode(factory_, weth9_);
        // forge-lint: disable-next-item(encode-packed-collision)
        bytes memory bytecode = abi.encodePacked(vm.getCode("Metadex03CLQuoterV2Extension.sol"), args);

        address quoter_ = Utils.deployBytecode(bytecode);
        metadex03CLQuoter = ICLQuoter(quoter_);
    }
}
