/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";

import { AerodromePoolAM } from "../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { ArcadiaContracts } from "./utils/Constants.sol";
import { ChainlinkOM } from "../src/oracle-modules/ChainlinkOM.sol";
import { ERC20PrimaryAM } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { Registry } from "../src/Registry.sol";
import { SafeTransactionBuilder } from "./utils/SafeTransactionBuilder.sol";
import { SlipstreamAM } from "../src/asset-modules/Slipstream/SlipstreamAM.sol";
import { StakedAerodromeAM } from "../src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";
import { WrappedAerodromeAM } from "../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

abstract contract Base_Script is Test, SafeTransactionBuilder {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");

    bool[] internal BA_TO_QA_SINGLE = new bool[](1);
    bool[] internal BA_TO_QA_DOUBLE = new bool[](2);

    AerodromePoolAM internal aerodromePoolAM = AerodromePoolAM(ArcadiaContracts.aerodromePoolAM);
    ChainlinkOM internal chainlinkOM = ChainlinkOM(ArcadiaContracts.chainlinkOM);
    ERC20PrimaryAM internal erc20PrimaryAM = ERC20PrimaryAM(ArcadiaContracts.erc20PrimaryAM);
    ILendingPool internal usdcLendingPool = ILendingPool(ArcadiaContracts.usdcLendingPool);
    ILendingPool internal wethLendingPool = ILendingPool(ArcadiaContracts.wethLendingPool);
    Registry internal registry = Registry(ArcadiaContracts.registry);
    SlipstreamAM internal slipstreamAM = SlipstreamAM(ArcadiaContracts.slipstreamAM);
    StakedAerodromeAM internal stakedAerodromeAM = StakedAerodromeAM(ArcadiaContracts.stakedAerodromeAM);
    WrappedAerodromeAM internal wrappedAerodromeAM = WrappedAerodromeAM(ArcadiaContracts.wrappedAerodromeAM);

    constructor() {
        BA_TO_QA_SINGLE[0] = true;
        BA_TO_QA_DOUBLE[0] = true;
        BA_TO_QA_DOUBLE[1] = true;
    }
}
