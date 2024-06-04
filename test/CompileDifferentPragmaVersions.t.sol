/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import { Test } from "../lib/forge-std/src/Test.sol";

import { CLFactory } from "../lib/slipstream/contracts/core/CLFactory.sol";
import { CLPool } from "../lib/slipstream/contracts/core/CLPool.sol";
import { CLGauge } from "../lib/slipstream/contracts/gauge/CLGauge.sol";
import { CLGaugeFactory } from "../lib/slipstream/contracts/gauge/CLGaugeFactory.sol";
import { NonfungiblePositionManager } from "../lib/slipstream/contracts/periphery/NonfungiblePositionManager.sol";
import { NonfungiblePositionManagerExtension } from
    "./utils/fixtures/uniswap-v3/extensions/NonfungiblePositionManagerExtension.sol";
import { UniswapV3FactoryExtension } from "./utils/fixtures/uniswap-v3/extensions/UniswapV3FactoryExtension.sol";
import { UniswapV3PoolExtension } from "./utils/fixtures/uniswap-v3/extensions/UniswapV3PoolExtension.sol";

contract RewardOf_StakedSlipstreamAM_Fuzz_Test is Test {
    function test() public { }
}
