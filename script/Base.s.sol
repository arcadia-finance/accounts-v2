/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";

import { ArcadiaContracts } from "./utils/Constants.sol";
import { ChainlinkOM } from "../src/oracle-modules/ChainlinkOM.sol";
import { ERC20PrimaryAM } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { Registry } from "../src/Registry.sol";

abstract contract Base_Script is Test {
    ChainlinkOM internal chainlinkOM = ChainlinkOM(ArcadiaContracts.chainlinkOM);
    ERC20PrimaryAM internal erc20PrimaryAM = ERC20PrimaryAM(ArcadiaContracts.erc20PrimaryAM);
    ILendingPool internal usdcLendingPool = ILendingPool(ArcadiaContracts.usdcLendingPool);
    ILendingPool internal wethLendingPool = ILendingPool(ArcadiaContracts.wethLendingPool);
    Registry internal registry = Registry(ArcadiaContracts.registry);

    bool[] internal BA_TO_QA_SINGLE = new bool[](1);
    bool[] internal BA_TO_QA_DOUBLE = new bool[](2);

    constructor() {
        BA_TO_QA_SINGLE[0] = true;
        BA_TO_QA_DOUBLE[0] = true;
        BA_TO_QA_DOUBLE[1] = true;
    }
}
