/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.36;

// forge-lint: disable-start(unused-import)
import { ArbGaugeFactory } from "../lib/metadex/V3/src/factories/extensions/ArbGaugeFactory.sol";
import { CustomFeeModule } from "../lib/metadex/V3/src/fees/CustomFeeModule.sol";
import { FactoryRegistry } from "../lib/metadex/V3/src/factories/FactoryRegistry.sol";
import { FlatFeeQuoter } from "../lib/metadex/V3/src/fees/FlatFeeQuoter.sol";
import { GaugeFactory } from "../lib/metadex/V3/src/factories/GaugeFactory.sol";
import { LeafEmissionsHandler } from "../lib/metadex/V3/src/handlers/LeafEmissionsHandler.sol";
import { LeafMessageOrchestrator } from "../lib/metadex/V3/src/bridge/LeafMessageOrchestrator.sol";
import { LeafVoter } from "../lib/metadex/V3/src/voter/LeafVoter.sol";
import { Minter } from "../lib/metadex/V3/src/minter/Minter.sol";
import { PoolTape } from "../lib/metadex/V3/src/pools/tape/PoolTape.sol";
import { ReceiptToken } from "../lib/metadex/V3/src/token/ReceiptToken.sol";
import { RootEmissionsHandler } from "../lib/metadex/V3/src/handlers/RootEmissionsHandler.sol";
import { RootLocalAdapter } from "../lib/metadex/V3/src/bridge/RootLocalAdapter.sol";
import { RootMessageOrchestrator } from "../lib/metadex/V3/src/bridge/RootMessageOrchestrator.sol";
import { StablePool } from "../lib/metadex/V3/src/pools/StablePool.sol";
import { StablePoolFactory } from "../lib/metadex/V3/src/factories/StablePoolFactory.sol";
import { Test } from "../lib/forge-std-v1.13/src/Test.sol";
import { Token } from "../lib/metadex/V3/src/token/Token.sol";
import { V2Gauge } from "../lib/metadex/V3/src/gauges/V2Gauge.sol";
import { VolatilePool } from "../lib/metadex/V3/src/pools/VolatilePool.sol";
import { VolatilePoolFactory } from "../lib/metadex/V3/src/factories/VolatilePoolFactory.sol";
import { Voter } from "../lib/metadex/V3/src/voter/Voter.sol";
import { VotingRewardsFactory } from "../lib/metadex/V3/src/rewards/VotingRewardsFactory.sol";
// forge-lint: disable-end(unused-import)

contract CompilePragma8Dot36 is Test {
    // forge-lint: disable-next-item(empty-block)
    function test() public { }
}
