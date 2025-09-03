/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

library AccountLogic {
    address internal constant V1 = 0xbea2B6d45ACaF62385877D835970a0788719cAe1;
    address internal constant V2 = 0xd8AF1F1dEe6EA38f9c08b5cfa31e01ad2Bfbef28; // Spot account.
    address internal constant V3 = 0x78Db6a136EdD0F70bEd7a6eb5ca2fDF6eE16E8D6;
    address internal constant V4 = 0xe976BFb44f9322164ca6fdA6C5B84fBb6163D442;
}

library ArcadiaAccounts {
    address internal constant ACCOUNTS_GUARD = 0x2529AE4a3c9d3285DD06CaDfc8516D3faBD6240b;
    address internal constant FACTORY = 0xDa14Fdd72345c4d2511357214c5B89A919768e59;
    address internal constant REGISTRY = 0xd0690557600eb8Be8391D1d97346e2aab5300d5f;
    address internal constant UNISWAPV4_HOOKS_REGISTRY = 0x8B0fd5352caE4E7c86632CA791229d132Fef5D3C;
}

library AssetModules {
    address internal constant AERO_POOL = 0xfe0FA1FD8F8E889062F03e2f126Fc7B9DE6091A5;
    address internal constant ALIEN_BASE = 0x79dD8b8d4abB5dEEA986DB1BF0a02E4CA42ae416;
    address internal constant DEFAULT_UNISWAPV4 = 0xb808971ea73341b0d7286B3D67F08De321f80465;
    address internal constant ERC20_PRIMARY = 0xfBecEaFC96ed6fc800753d3eE6782b6F9a60Eed7;
    address internal constant SLIPSTREAM = 0xd3A7055bBcDA4F8F49e5c5dE7E83B09a33633F44;
    address internal constant STAKED_AERO = 0x9f42361B7602Df1A8Ae28Bf63E6cb1883CD44C27;
    address internal constant STAKED_STARGATE = 0xae909e19fd13C01c28d5Ee439D403920CF7f9Eea;
    address internal constant STAKED_SLIPSTREAM = 0x1Dc7A0f5336F52724B650E39174cfcbbEdD67bF1;
    address internal constant STARGATE = 0x20f7903290bF98716B62Dc1c9DA634291b8cfeD4;
    address internal constant UNISWAPV3 = 0x21bd524cC54CA78A7c48254d4676184f781667dC;
    address internal constant WRAPPED_AERO = 0x17B5826382e3a5257b829cF0546A08Bd77409270;
}

library Deployers {
    address constant ARCADIA = 0x0f518becFC14125F23b8422849f6393D59627ddB;
}

library OracleModules {
    address internal constant CHAINLINK = 0x6a5485E3ce6913890ae5e8bDc08a868D432eEB31;
}

struct Asset {
    address asset;
    uint8 decimals;
}

struct Oracle {
    address oracle;
    bytes16 baseAsset;
    bytes16 quoteAsset;
    uint32 cutOffTime;
    uint80 id;
}
