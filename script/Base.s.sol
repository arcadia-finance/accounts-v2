/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AerodromePoolAM } from "../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { ArcadiaAccounts, AssetModules, OracleModules } from "./utils/constants/Shared.sol";
import { BitPackingLib } from "../src/libraries/BitPackingLib.sol";
import { ChainlinkOM } from "../src/oracle-modules/ChainlinkOM.sol";
import { ERC20PrimaryAM } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { Factory } from "../src/Factory.sol";
import { Asset, Oracle } from "./utils/constants/Shared.sol";
import { RegistryL2 } from "../src/registries/RegistryL2.sol";
import { SafeTransactionBuilder } from "./utils/SafeTransactionBuilder.sol";
import { SlipstreamAM } from "../src/asset-modules/Slipstream/SlipstreamAM.sol";
import { StakedAerodromeAM } from "../src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";
import { StakedSlipstreamAM } from "../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { Test } from "../lib/forge-std/src/Test.sol";
import { WrappedAerodromeAM } from "../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

abstract contract Base_Script is Test, SafeTransactionBuilder {
    uint256 internal deployer = vm.envUint("PRIVATE_KEY_DEPLOYER");

    /// forge-lint: disable-start(mixed-case-variable)
    bool[] internal BA_TO_QA_SINGLE = new bool[](1);
    bool[] internal BA_TO_QA_DOUBLE = new bool[](2);

    AerodromePoolAM internal aerodromePoolAM = AerodromePoolAM(AssetModules.AERO_POOL);
    ChainlinkOM internal chainlinkOM = ChainlinkOM(OracleModules.CHAINLINK);
    ERC20PrimaryAM internal erc20PrimaryAM = ERC20PrimaryAM(AssetModules.ERC20_PRIMARY);
    Factory internal factory = Factory(ArcadiaAccounts.FACTORY);
    RegistryL2 internal registry = RegistryL2(ArcadiaAccounts.REGISTRY);
    SlipstreamAM internal slipstreamAM = SlipstreamAM(AssetModules.SLIPSTREAM);
    StakedAerodromeAM internal stakedAerodromeAM = StakedAerodromeAM(AssetModules.STAKED_AERO);
    StakedSlipstreamAM internal stakedSlipstreamAM = StakedSlipstreamAM(AssetModules.STAKED_SLIPSTREAM);
    WrappedAerodromeAM internal wrappedAerodromeAM = WrappedAerodromeAM(AssetModules.WRAPPED_AERO);
    /// forge-lint: disable-end(mixed-case-variable)

    constructor() {
        BA_TO_QA_SINGLE[0] = true;
        BA_TO_QA_DOUBLE[0] = true;
        BA_TO_QA_DOUBLE[1] = true;
    }

    function addOracle(Oracle memory oracle) internal pure returns (bytes memory calldata_) {
        calldata_ = abi.encodeCall(
            ChainlinkOM.addOracle, (oracle.oracle, oracle.baseAsset, oracle.quoteAsset, oracle.cutOffTime)
        );
    }

    function addAsset(Asset memory asset, Oracle memory oracle) internal view returns (bytes memory calldata_) {
        uint80[] memory oracles = new uint80[](1);
        oracles[0] = oracle.id;
        calldata_ = abi.encodeCall(ERC20PrimaryAM.addAsset, (asset.asset, BitPackingLib.pack(BA_TO_QA_SINGLE, oracles)));
    }

    function addAsset(Asset memory asset, Oracle memory oracle1, Oracle memory oracle2)
        internal
        view
        returns (bytes memory calldata_)
    {
        uint80[] memory oracles = new uint80[](2);
        oracles[0] = oracle1.id;
        oracles[1] = oracle2.id;
        calldata_ = abi.encodeCall(ERC20PrimaryAM.addAsset, (asset.asset, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracles)));
    }
}
