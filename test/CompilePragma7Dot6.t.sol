/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

// forge-lint: disable-start(unused-import)
import { CLFactory } from "../lib/slipstream/contracts/core/CLFactory.sol";
import { CLPoolExtension } from "./utils/fixtures/slipstream/extensions/CLPoolExtension.sol";
import { CLGauge } from "../lib/slipstream/contracts/gauge/CLGauge.sol";
import { CLGaugeFactory } from "../lib/slipstream/contracts/gauge/CLGaugeFactory.sol";
import { NonfungiblePositionManager } from "../lib/slipstream/contracts/periphery/NonfungiblePositionManager.sol";
import {
    NonfungiblePositionManagerExtension
} from "./utils/fixtures/uniswap-v3/extensions/NonfungiblePositionManagerExtension.sol";
import { Test } from "../lib/forge-std/src/Test.sol";
import { UniswapV3FactoryExtension } from "./utils/fixtures/uniswap-v3/extensions/UniswapV3FactoryExtension.sol";
import { UniswapV3PoolExtension } from "./utils/fixtures/uniswap-v3/extensions/UniswapV3PoolExtension.sol";
// forge-lint: disable-end(unused-import)

contract CompilePragma7Dot6 is Test {
    function test() public { }
}
