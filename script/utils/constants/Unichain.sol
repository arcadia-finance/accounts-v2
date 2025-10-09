/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Asset, Oracle, OracleProvider } from "./Shared.sol";

library AerodromeGauges { }

library AerodromePools { }

/// forge-lint: disable-next-item(mixed-case-function)
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

library Merkl {
    address internal constant DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
}

library MerkleRoots {
    bytes32 internal constant V1 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;
    bytes32 internal constant V2 = 0xad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5;
    bytes32 internal constant V4 = 0x03a8115b458ca7ccb57dc8120b852092dd652c46642e100d332bdf624cd1eaf1;
}

/// forge-lint: disable-next-item(mixed-case-function)
library Oracles {
    function ETH_USD() internal pure returns (Oracle memory) {
        return Oracle({
            provider: OracleProvider.REDSTONE,
            oracle: 0xe8D9FbC10e00ecc9f0694617075fDAF657a76FB2,
            baseAsset: "ETH",
            quoteAsset: "USD",
            cutOffTime: 7 hours,
            id: 0
        });
    }

    function USDC_USD() internal pure returns (Oracle memory) {
        return Oracle({
            provider: OracleProvider.REDSTONE,
            oracle: 0xD15862FC3D5407A03B696548b6902D6464A69b8c,
            baseAsset: "USDC",
            quoteAsset: "USD",
            cutOffTime: 4 hours,
            id: 1
        });
    }
}
