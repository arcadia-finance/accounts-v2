// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import { CLFactory } from "../../../../../lib/metadex-slipstream/contracts/core/CLFactory.sol";

contract Metadex03CLFactoryExtension is CLFactory {
    constructor(ConstructorParams memory params) CLFactory(params) { }
}
