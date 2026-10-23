// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import { CLGaugeFactory } from "../../../../../lib/metadex-slipstream/contracts/gauge/CLGaugeFactory.sol";

contract Metadex03CLGaugeFactoryExtension is CLGaugeFactory {
    constructor(
        address leafVoter_,
        address gaugeManager_,
        address votingRewardsFactory_,
        address nft_,
        RoleAddresses memory roles,
        CapConfig memory capConfig
    ) CLGaugeFactory(leafVoter_, gaugeManager_, votingRewardsFactory_, nft_, roles, capConfig) { }
}
