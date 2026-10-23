// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import { CLFactory } from "../../../../../lib/slipstream/contracts/core/CLFactory.sol";

contract SlipstreamCLFactoryExtension is CLFactory {
    constructor(
        address owner_,
        address swapFeeManager_,
        address unstakedFeeManager_,
        address voter_,
        address poolImplementation_
    ) CLFactory(owner_, swapFeeManager_, unstakedFeeManager_, voter_, poolImplementation_) { }
}
