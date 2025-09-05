/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Asset, Oracle } from "./Shared.sol";

library AerodromeGauges { }

library AerodromePools { }

library Assets {
    function OP() internal pure returns (Asset memory) {
        return Asset({ asset: 0x4200000000000000000000000000000000000042, decimals: 18 });
    }

    function USDC() internal pure returns (Asset memory) {
        return Asset({ asset: 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85, decimals: 6 });
    }

    function VELO() internal pure returns (Asset memory) {
        return Asset({ asset: 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db, decimals: 18 });
    }

    function WETH() internal pure returns (Asset memory) {
        return Asset({ asset: 0x4200000000000000000000000000000000000006, decimals: 18 });
    }
}

library ExternalContracts {
    address internal constant SEQUENCER_UPTIME_ORACLE = 0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389;
    address internal constant SLIPSTREAM_POS_MNGR = 0x416b433906b1B72FA758e166e239c43d68dC6F29;
    address internal constant STARGATE_FACTORY = 0xE3B53AF74a4BF62Ae5511055290838050bf764Df;
    address internal constant STARGATE_LP_STAKING = 0x4DeA9e918c6289a52cd469cAC652727B7b412Cd2;
    address internal constant VELO_FACTORY = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;
    address internal constant VELO_VOTER = 0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C;
    address internal constant UNISWAPV3_POS_MNGR = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address internal constant UNISWAPV4_POS_MNGR = 0x3C3Ea4B57a46241e54610e5f022E5c45859A1017;
}

library MerkleRoots {
    bytes32 internal constant V1 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;
    bytes32 internal constant V2 = 0xad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5;
}

library Oracles {
    function ETH_USD() internal pure returns (Oracle memory) {
        return Oracle({ oracle: address(0), baseAsset: "ETH", quoteAsset: "USD", cutOffTime: 1 hours, id: 2 });
    }

    function OP_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x0D276FC14719f9292D5C1eA2198673d1f4269246,
            baseAsset: "OP",
            quoteAsset: "USD",
            cutOffTime: 1 hours,
            id: 0
        });
    }

    function VELO_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x0f2Ed59657e391746C1a097BDa98F2aBb94b1120,
            baseAsset: "VELO",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 1
        });
    }

    function USDC_USD() internal pure returns (Oracle memory) {
        return Oracle({ oracle: address(0), baseAsset: "USDC", quoteAsset: "USD", cutOffTime: 25 hours, id: 3 });
    }
}

library Safes {
    address internal constant GUARDIAN = 0xEdD41f9740b06eCBfe1CE9194Ce2715C28263187;
    address internal constant OWNER = 0xb4d72B1c91e640e4ED7d7397F3244De4D8ACc50B;
    address internal constant RISK_MANAGER = 0xD5FA6C6e284007743d4263255385eDA78dDa268c;
    address internal constant TREASURY = 0xFd6db26eDc581D8F381f46eF4a6396A762b66E95;
}
