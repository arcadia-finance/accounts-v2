// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import { QuoterV2 } from "../../../lib/slipstream/contracts/periphery/lens/QuoterV2.sol";

contract CLQuoterV2Extension is QuoterV2 {
    constructor(address factory_, address weth9_) QuoterV2(factory_, weth9_) { }
}
