// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import { CLGaugeFactory } from "../../../../../lib/slipstream/contracts/gauge/CLGaugeFactory.sol";

contract SlipstreamCLGaugeFactoryExtension is CLGaugeFactory {
    constructor(address notifyAdmin_, address voter_, address nft_, address implementation_)
        CLGaugeFactory(notifyAdmin_, voter_, nft_, implementation_)
    { }
}
