/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Asset, Oracle } from "./Shared.sol";

library AerodromeGauges { }

library AerodromePools { }

library Assets {
    function USDC() internal pure returns (Asset memory) {
        return Asset({ asset: 0x078D782b760474a361dDA0AF3839290b0EF57AD6, decimals: 6 });
    }

    function WETH() internal pure returns (Asset memory) {
        return Asset({ asset: 0x4200000000000000000000000000000000000006, decimals: 18 });
    }

    function XVELO() internal pure returns (Asset memory) {
        return Asset({ asset: 0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81, decimals: 18 });
    }
}

library ExternalContracts {
    address internal constant SLIPSTREAM_POS_MNGR = 0x991d5546C4B442B4c5fdc4c8B8b8d131DEB24702;
    address internal constant VELO_FACTORY = 0x31832f2a97Fd20664D76Cc421207669b55CE4BC0;
    address internal constant VELO_VOTER = 0x97cDBCe21B6fd0585d29E539B1B99dAd328a1123;
    address internal constant UNISWAPV3_POS_MNGR = 0x943e6e07a7E8E791dAFC44083e54041D743C46E9;
    address internal constant UNISWAPV4_POS_MNGR = 0x4529A01c7A0410167c5740C487A8DE60232617bf;
}

library MerkleRoots {
    bytes32 internal constant V1 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;
    bytes32 internal constant V2 = 0xad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5;
}

library Oracles { }

library Safes {
    address internal constant GUARDIAN = 0xEdD41f9740b06eCBfe1CE9194Ce2715C28263187;
    address internal constant OWNER = 0xb4d72B1c91e640e4ED7d7397F3244De4D8ACc50B;
    address internal constant RISK_MANAGER = 0xD5FA6C6e284007743d4263255385eDA78dDa268c;
    address internal constant TREASURY = 0xFd6db26eDc581D8F381f46eF4a6396A762b66E95;
}
