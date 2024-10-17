/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Test } from "../lib/forge-std/src/Test.sol";

import { AerodromePoolAM } from "../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { ArcadiaContracts } from "./utils/Constants.sol";
import { ChainlinkOM } from "../src/oracle-modules/ChainlinkOM.sol";
import { ERC20PrimaryAM } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { Factory } from "../src/Factory.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { Registry } from "../src/Registry.sol";
import { SafeTransactionBuilder } from "./utils/SafeTransactionBuilder.sol";
import { SlipstreamAM } from "../src/asset-modules/Slipstream/SlipstreamAM.sol";
import { StakedAerodromeAM } from "../src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";
import { StakedSlipstreamAM } from "../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { WrappedAerodromeAM } from "../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

abstract contract Base_Script is Test, SafeTransactionBuilder {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");

    bool[] internal BA_TO_QA_SINGLE = new bool[](1);
    bool[] internal BA_TO_QA_DOUBLE = new bool[](2);

    AerodromePoolAM internal aerodromePoolAM = AerodromePoolAM(ArcadiaContracts.AERO_POOL_AM);
    ChainlinkOM internal chainlinkOM = ChainlinkOM(ArcadiaContracts.CHAINLINK_OM);
    ERC20PrimaryAM internal erc20PrimaryAM = ERC20PrimaryAM(ArcadiaContracts.ERC20_PRIMARY_AM);
    Factory internal factory = Factory(ArcadiaContracts.FACTORY);
    ILendingPool internal cbbtcLendingPool = ILendingPool(ArcadiaContracts.LENDINGPOOL_CBBTC);
    ILendingPool internal usdcLendingPool = ILendingPool(ArcadiaContracts.LENDINGPOOL_USDC);
    ILendingPool internal wethLendingPool = ILendingPool(ArcadiaContracts.LENDINGPOOL_WETH);
    Registry internal registry = Registry(ArcadiaContracts.REGISTRY);
    SlipstreamAM internal slipstreamAM = SlipstreamAM(ArcadiaContracts.SLIPSTREAM_AM);
    StakedAerodromeAM internal stakedAerodromeAM = StakedAerodromeAM(ArcadiaContracts.STAKED_AERO_AM);
    StakedSlipstreamAM internal stakedSlipstreamAM = StakedSlipstreamAM(ArcadiaContracts.STAKED_SLIPSTREAM_AM);
    WrappedAerodromeAM internal wrappedAerodromeAM = WrappedAerodromeAM(ArcadiaContracts.WRAPPED_AERO_AM);

    constructor() {
        BA_TO_QA_SINGLE[0] = true;
        BA_TO_QA_DOUBLE[0] = true;
        BA_TO_QA_DOUBLE[1] = true;
    }
}
