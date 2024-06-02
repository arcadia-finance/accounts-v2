/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StakedSlipstreamAM } from "../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";

contract StakedSlipstreamAMExtension is StakedSlipstreamAM {
    constructor(address registry_, address nonfungiblePositionManager, address aerodromeVoter, address rewardToken)
        StakedSlipstreamAM(registry_, nonfungiblePositionManager, aerodromeVoter, rewardToken)
    { }
}
