/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

library AccountLogic {
    address internal constant V1 = address(0xbea2B6d45ACaF62385877D835970a0788719cAe1);
    address internal constant V2 = address(0xd8AF1F1dEe6EA38f9c08b5cfa31e01ad2Bfbef28); // Spot account.
}

library ArcadiaContracts {
    address internal constant AERO_POOL_AM = address(0xfe0FA1FD8F8E889062F03e2f126Fc7B9DE6091A5);
    address internal constant ALIEN_BASE_AM = address(0x79dD8b8d4abB5dEEA986DB1BF0a02E4CA42ae416);
    address internal constant CHAINLINK_OM = address(0x6a5485E3ce6913890ae5e8bDc08a868D432eEB31);
    address internal constant DEFAULT_UNISWAPV4_AM = address(0xb808971ea73341b0d7286B3D67F08De321f80465);
    address internal constant ERC20_PRIMARY_AM = address(0xfBecEaFC96ed6fc800753d3eE6782b6F9a60Eed7);
    address internal constant FACTORY = address(0xDa14Fdd72345c4d2511357214c5B89A919768e59);
    address internal constant LENDINGPOOL_CBBTC = address(0xa37E9b4369dc20940009030BfbC2088F09645e3B);
    address internal constant LENDINGPOOL_USDC = address(0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1);
    address internal constant LENDINGPOOL_WETH = address(0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2);
    address internal constant REGISTRY = address(0xd0690557600eb8Be8391D1d97346e2aab5300d5f);
    address internal constant SLIPSTREAM_AM = address(0xd3A7055bBcDA4F8F49e5c5dE7E83B09a33633F44);
    address internal constant STAKED_AERO_AM = address(0x9f42361B7602Df1A8Ae28Bf63E6cb1883CD44C27);
    address internal constant STAKED_STARGATE_AM = address(0xae909e19fd13C01c28d5Ee439D403920CF7f9Eea);
    address internal constant STAKED_SLIPSTREAM_AM = address(0x1Dc7A0f5336F52724B650E39174cfcbbEdD67bF1);
    address internal constant STARGATE_AM = address(0x20f7903290bF98716B62Dc1c9DA634291b8cfeD4);
    address internal constant UNISWAPV3_AM = address(0x21bd524cC54CA78A7c48254d4676184f781667dC);
    address internal constant UNISWAPV4_HOOKS_REGISTRY = address(0x8B0fd5352caE4E7c86632CA791229d132Fef5D3C);
    address internal constant WRAPPED_AERO_AM = address(0x17B5826382e3a5257b829cF0546A08Bd77409270);
}

library ArcadiaSafes {
    address internal constant GUARDIAN = address(0xEdD41f9740b06eCBfe1CE9194Ce2715C28263187);
    address internal constant OWNER = address(0xb4d72B1c91e640e4ED7d7397F3244De4D8ACc50B);
    address internal constant RISK_MANAGER = address(0xD5FA6C6e284007743d4263255385eDA78dDa268c);
}

library MerkleRoots {
    bytes32 internal constant V1 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;
    bytes32 internal constant V2 = 0xad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5;
}

library PrimaryAssets {
    address internal constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address internal constant AXL = 0x23ee2343B892b1BB63503a4FAbc840E0e2C6810f;
    address internal constant AXLDAI = 0x5C7e299CF531eb66f2A1dF637d37AbB78e6200C7;
    address internal constant AXLUSDC = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;
    address internal constant AXLUSDT = 0x7f5373AE26c3E8FfC4c77b7255DF7eC1A9aF52a6;
    address internal constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant CBETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address internal constant COMP = 0x9e1028F5F1D5eDE59748FFceE5532509976840E0;
    address internal constant CRV = 0x8Ee73c484A26e0A5df2Ee2a4960B789967dd0415;
    address internal constant CRVUSD = 0x417Ac0e078398C154EdFadD9Ef675d30Be60Af93;
    address internal constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address internal constant DEGEN = 0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed;
    address internal constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address internal constant EZETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address internal constant RDNT = 0xd722E55C1d9D9fA0021A5215Cbb904b92B3dC5d4;
    address internal constant RETH = 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c;
    address internal constant STG = 0xE3B53AF74a4BF62Ae5511055290838050bf764Df;
    address internal constant SUSHI = 0x7D49a065D17d6d4a55dc13649901fdBB98B2AFBA;
    address internal constant TBTC = 0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b;
    address internal constant TRUMP = 0xc27468b12ffA6d714B1b5fBC87eF403F38b82AD4;
    address internal constant USDBC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant USDS = 0x820C137fa70C8691f0e44Dc420a5e53c168921Dc;
    address internal constant USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
    address internal constant USDZ = 0x04D5ddf5f3a8939889F11E97f8c4BB48317F1938;
    address internal constant VIRTUAL = 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b;
    address internal constant WEETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant WRSETH = 0xEDfa23602D0EC14714057867A78d01e94176BEA0;
    address internal constant WSTETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
}

library Decimals {
    uint8 internal constant AERO = 18;
    uint8 internal constant AXL = 6;
    uint8 internal constant AXLDAI = 18;
    uint8 internal constant AXLUSDC = 6;
    uint8 internal constant AXLUSDT = 6;
    uint8 internal constant CBBTC = 8;
    uint8 internal constant CBETH = 18;
    uint8 internal constant COMP = 18;
    uint8 internal constant CRV = 18;
    uint8 internal constant CRVUSD = 18;
    uint8 internal constant DAI = 18;
    uint8 internal constant DEGEN = 18;
    uint8 internal constant EZETH = 18;
    uint8 internal constant EURC = 6;
    uint8 internal constant RDNT = 18;
    uint8 internal constant RETH = 18;
    uint8 internal constant STG = 18;
    uint8 internal constant SUSHI = 18;
    uint8 internal constant TBTC = 18;
    uint8 internal constant TRUMP = 18;
    uint8 internal constant USDBC = 6;
    uint8 internal constant USDC = 6;
    uint8 internal constant USDS = 18;
    uint8 internal constant USDT = 6;
    uint8 internal constant USDZ = 18;
    uint8 internal constant VIRTUAL = 18;
    uint8 internal constant WEETH = 18;
    uint8 internal constant WETH = 18;
    uint8 internal constant WRSETH = 18;
    uint8 internal constant WSTETH = 18;
}

library Oracles {
    address internal constant AERO_USD = 0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0;
    address internal constant CBBTC_USD = 0x07DA0E54543a844a80ABE69c8A12F22B3aA59f9D;
    address internal constant CBETH_USD = 0xd7818272B9e248357d13057AAb0B417aF31E817d;
    address internal constant COMP_USD = 0x9DDa783DE64A9d1A60c49ca761EbE528C35BA428;
    address internal constant DAI_USD = 0x591e79239a7d679378eC8c847e5038150364C78F;
    address internal constant DEGEN_USD = 0xE62BcE5D7CB9d16AB8b4D622538bc0A50A5799c2;
    address internal constant ETH_USD = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address internal constant EURC_USD = 0xDAe398520e2B67cd3f27aeF9Cf14D93D927f8250;
    address internal constant EZETH_ETH = 0x960BDD1dFD20d7c98fa482D793C3dedD73A113a3;
    address internal constant RDNT_USD = 0xEf2E24ba6def99B5e0b71F6CDeaF294b02163094;
    address internal constant RETH_ETH = 0xf397bF97280B488cA19ee3093E81C0a77F02e9a5;
    address internal constant STG_USD = 0x63Af8341b62E683B87bB540896bF283D96B4D385;
    address internal constant TBTC_USD = 0x6D75BFB5A5885f841b132198C9f0bE8c872057BF;
    address internal constant TRUMP_USD = 0x7bAfa1Af54f17cC0775a1Cf813B9fF5dED2C51E5;
    address internal constant USDBC_USD = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address internal constant USDC_USD = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address internal constant USDS_USD = 0x2330aaE3bca5F05169d5f4597964D44522F62930;
    address internal constant USDT_USD = 0xf19d560eB8d2ADf07BD6D13ed03e1D11215721F9;
    address internal constant USDZ_USD = 0xe25969e2Fa633a0C027fAB8F30Fc9C6A90D60B48;
    address internal constant VIRTUAL_USD = 0xEaf310161c9eF7c813A14f8FEF6Fb271434019F7;
    address internal constant WBTC_USD = 0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E;
    address internal constant WEETH_ETH = 0xFC1415403EbB0c693f9a7844b92aD2Ff24775C65;
    address internal constant WRSETH_ETH = 0xe8dD07CCf5BC4922424140E44Eb970F5950725ef;
    address internal constant WSTETH_ETH = 0xa669E5272E60f78299F4824495cE01a3923f4380;
}

library OracleIds {
    uint80 internal constant AERO_USD = 8;
    uint80 internal constant CBBTC_USD = 15;
    uint80 internal constant CBETH_USD = 4;
    uint80 internal constant COMP_USD = 0;
    uint80 internal constant DAI_USD = 1;
    uint80 internal constant DEGEN_USD = 9;
    uint80 internal constant ETH_USD = 2;
    uint80 internal constant EURC_USD = 16;
    uint80 internal constant EZETH_ETH = 10;
    uint80 internal constant RDNT_USD = 13;
    uint80 internal constant RETH_USD = 5;
    uint80 internal constant STG_USD = 6;
    uint80 internal constant TBTC_USD = 14;
    uint80 internal constant TRUMP_USD = 20;
    uint80 internal constant USDC_USD = 3;
    uint80 internal constant USDS_USD = 19;
    uint80 internal constant USDT_USD = 12;
    uint80 internal constant USDZ_USD = 17;
    uint80 internal constant VIRTUAL_USD = 21;
    uint80 internal constant WEETH_ETH = 11;
    uint80 internal constant WRSETH_ETH = 18;
    uint80 internal constant WSTETH_ETH = 7;
}

library CutOffTimes {
    uint32 internal constant AERO_USD = 25 hours;
    uint32 internal constant CBBTC_USD = 25 hours;
    uint32 internal constant CBETH_USD = 1 hours;
    uint32 internal constant COMP_USD = 25 hours;
    uint32 internal constant DAI_USD = 25 hours;
    uint32 internal constant DEGEN_USD = 25 hours;
    uint32 internal constant ETH_USD = 1 hours;
    uint32 internal constant EURC_USD = 25 hours;
    uint32 internal constant EZETH_ETH = 25 hours;
    uint32 internal constant RDNT_USD = 25 hours;
    uint32 internal constant RETH_ETH = 25 hours;
    uint32 internal constant STG_USD = 25 hours;
    uint32 internal constant TBTC_USD = 25 hours;
    uint32 internal constant TRUMP_USD = 25 hours;
    uint32 internal constant VIRTUAL_USD = 25 hours;
    uint32 internal constant USDC_USD = 25 hours;
    uint32 internal constant USDS_USD = 25 hours;
    uint32 internal constant USDT_USD = 25 hours;
    uint32 internal constant USDZ_USD = 25 hours;
    uint32 internal constant WEETH_ETH = 25 hours;
    uint32 internal constant WRSETH_ETH = 25 hours;
    uint32 internal constant WSTETH_ETH = 25 hours;
}

library RiskParameters {
    // AERO
    uint16 internal constant COL_FAC_AERO_CBBTC = 7200;
    uint16 internal constant COL_FAC_AERO_WETH = 7700;
    uint16 internal constant COL_FAC_AERO_USDC = 7100;
    uint16 internal constant LIQ_FAC_AERO_CBBTC = 8625;
    uint16 internal constant LIQ_FAC_AERO_WETH = 8950;
    uint16 internal constant LIQ_FAC_AERO_USDC = 8500;
    uint112 internal constant EXPOSURE_AERO_CBBTC = uint112(3e6 * 10 ** Decimals.AERO);
    uint112 internal constant EXPOSURE_AERO_WETH = uint112(3e6 * 10 ** Decimals.AERO);
    uint112 internal constant EXPOSURE_AERO_USDC = uint112(3e6 * 10 ** Decimals.AERO);

    // cbBTC
    uint16 internal constant COL_FAC_CBBTC_CBBTC = 9225;
    uint16 internal constant COL_FAC_CBBTC_WETH = 8500;
    uint16 internal constant COL_FAC_CBBTC_USDC = 7200;
    uint16 internal constant LIQ_FAC_CBBTC_CBBTC = 9750;
    uint16 internal constant LIQ_FAC_CBBTC_WETH = 9600;
    uint16 internal constant LIQ_FAC_CBBTC_USDC = 8750;
    uint112 internal constant EXPOSURE_CBBTC_CBBTC = uint112(50 * 10 ** Decimals.CBBTC);
    uint112 internal constant EXPOSURE_CBBTC_WETH = uint112(20 * 10 ** Decimals.CBBTC);
    uint112 internal constant EXPOSURE_CBBTC_USDC = uint112(20 * 10 ** Decimals.CBBTC);

    // cbETH
    uint16 internal constant COL_FAC_CBETH_WETH = 9325;
    uint16 internal constant COL_FAC_CBETH_USDC = 8500;
    uint16 internal constant LIQ_FAC_CBETH_WETH = 9750;
    uint16 internal constant LIQ_FAC_CBETH_USDC = 9300;
    uint112 internal constant EXPOSURE_CBETH_WETH = uint112(400 * 10 ** Decimals.CBETH);
    uint112 internal constant EXPOSURE_CBETH_USDC = uint112(300 * 10 ** Decimals.CBETH);

    // COMP
    uint16 internal constant COL_FAC_COMP_WETH = 7000;
    uint16 internal constant COL_FAC_COMP_USDC = 6500;
    uint16 internal constant LIQ_FAC_COMP_WETH = 7700;
    uint16 internal constant LIQ_FAC_COMP_USDC = 7200;
    uint112 internal constant EXPOSURE_COMP_WETH = 0;
    uint112 internal constant EXPOSURE_COMP_USDC = 0;

    // DAI
    uint16 internal constant COL_FAC_DAI_WETH = 0;
    uint16 internal constant COL_FAC_DAI_USDC = 8300;
    uint16 internal constant LIQ_FAC_DAI_WETH = 0;
    uint16 internal constant LIQ_FAC_DAI_USDC = 8700;
    uint112 internal constant EXPOSURE_DAI_WETH = 0;
    uint112 internal constant EXPOSURE_DAI_USDC = uint112(200 * 10 ** Decimals.DAI);

    // DEGEN
    uint16 internal constant COL_FAC_DEGEN_WETH = 6400;
    uint16 internal constant COL_FAC_DEGEN_USDC = 6000;
    uint16 internal constant LIQ_FAC_DEGEN_WETH = 8000;
    uint16 internal constant LIQ_FAC_DEGEN_USDC = 7800;
    uint112 internal constant EXPOSURE_DEGEN_WETH = uint112(75_000_000 * 10 ** Decimals.DEGEN);
    uint112 internal constant EXPOSURE_DEGEN_USDC = uint112(75_000_000 * 10 ** Decimals.DEGEN);

    // EURC
    uint16 internal constant COL_FAC_EURC_CBBTC = 8200;
    uint16 internal constant COL_FAC_EURC_USDC = 8950;
    uint16 internal constant COL_FAC_EURC_WETH = 8750;
    uint16 internal constant LIQ_FAC_EURC_CBBTC = 9250;
    uint16 internal constant LIQ_FAC_EURC_USDC = 9675;
    uint16 internal constant LIQ_FAC_EURC_WETH = 9475;
    uint112 internal constant EXPOSURE_EURC_CBBTC = uint112(1_000_000 * 10 ** Decimals.EURC);
    uint112 internal constant EXPOSURE_EURC_USDC = uint112(3_000_000 * 10 ** Decimals.EURC);
    uint112 internal constant EXPOSURE_EURC_WETH = uint112(2_000_000 * 10 ** Decimals.EURC);

    // ezETH
    uint16 internal constant COL_FAC_EZETH_WETH = 8800;
    uint16 internal constant COL_FAC_EZETH_USDC = 7800;
    uint16 internal constant LIQ_FAC_EZETH_WETH = 9600;
    uint16 internal constant LIQ_FAC_EZETH_USDC = 8700;
    uint112 internal constant EXPOSURE_EZETH_WETH = uint112(250 * 10 ** Decimals.EZETH);
    uint112 internal constant EXPOSURE_EZETH_USDC = uint112(175 * 10 ** Decimals.EZETH);

    // RDNT
    uint16 internal constant COL_FAC_RDNT_WETH = 0;
    uint16 internal constant COL_FAC_RDNT_USDC = 0;
    uint16 internal constant LIQ_FAC_RDNT_WETH = 7500;
    uint16 internal constant LIQ_FAC_RDNT_USDC = 7500;
    uint112 internal constant EXPOSURE_RDNT_WETH = uint112(0 * 10 ** Decimals.RDNT);
    uint112 internal constant EXPOSURE_RDNT_USDC = uint112(0 * 10 ** Decimals.RDNT);

    // RETH
    uint16 internal constant COL_FAC_RETH_WETH = 8900;
    uint16 internal constant COL_FAC_RETH_USDC = 8350;
    uint16 internal constant LIQ_FAC_RETH_WETH = 9650;
    uint16 internal constant LIQ_FAC_RETH_USDC = 9200;
    uint112 internal constant EXPOSURE_RETH_WETH = uint112(210 * 10 ** Decimals.RETH);
    uint112 internal constant EXPOSURE_RETH_USDC = uint112(200 * 10 ** Decimals.RETH);

    // STG
    uint16 internal constant COL_FAC_STG_WETH = 6000;
    uint16 internal constant COL_FAC_STG_USDC = 5500;
    uint16 internal constant LIQ_FAC_STG_WETH = 7200;
    uint16 internal constant LIQ_FAC_STG_USDC = 7000;
    uint112 internal constant EXPOSURE_STG_WETH = 1;
    uint112 internal constant EXPOSURE_STG_USDC = 1;

    // TBTC
    uint16 internal constant COL_FAC_TBTC_CBBTC = 8625;
    uint16 internal constant COL_FAC_TBTC_WETH = 8500;
    uint16 internal constant COL_FAC_TBTC_USDC = 7200;
    uint16 internal constant LIQ_FAC_TBTC_CBBTC = 9675;
    uint16 internal constant LIQ_FAC_TBTC_WETH = 9600;
    uint16 internal constant LIQ_FAC_TBTC_USDC = 8750;
    uint112 internal constant EXPOSURE_TBTC_CBBTC = uint112(5 * 10 ** Decimals.TBTC);
    uint112 internal constant EXPOSURE_TBTC_WETH = uint112(10 * 10 ** Decimals.TBTC);
    uint112 internal constant EXPOSURE_TBTC_USDC = uint112(8 * 10 ** Decimals.TBTC);

    // TRUMP
    uint16 internal constant COL_FAC_TRUMP_WETH = 5650;
    uint16 internal constant COL_FAC_TRUMP_USDC = 5650;
    uint16 internal constant LIQ_FAC_TRUMP_WETH = 7200;
    uint16 internal constant LIQ_FAC_TRUMP_USDC = 7200;
    uint112 internal constant EXPOSURE_TRUMP_WETH = uint112(3500 * 10 ** Decimals.TRUMP);
    uint112 internal constant EXPOSURE_TRUMP_USDC = uint112(4000 * 10 ** Decimals.TRUMP);

    // USDBC
    uint16 internal constant COL_FAC_USDBC_WETH = 8850;
    uint16 internal constant COL_FAC_USDBC_USDC = 9250;
    uint16 internal constant LIQ_FAC_USDBC_WETH = 9475;
    uint16 internal constant LIQ_FAC_USDBC_USDC = 9675;
    uint112 internal constant EXPOSURE_USDBC_WETH = uint112(750_000 * 10 ** Decimals.USDBC);
    uint112 internal constant EXPOSURE_USDBC_USDC = uint112(1_000_000 * 10 ** Decimals.USDBC);

    // USDC
    uint16 internal constant COL_FAC_USDC_CBBTC = 7200;
    uint16 internal constant COL_FAC_USDC_WETH = 8850;
    uint16 internal constant COL_FAC_USDC_USDC = 9325;
    uint16 internal constant LIQ_FAC_USDC_CBBTC = 8750;
    uint16 internal constant LIQ_FAC_USDC_WETH = 9475;
    uint16 internal constant LIQ_FAC_USDC_USDC = 9750;
    uint112 internal constant EXPOSURE_USDC_CBBTC = uint112(1_000_000 * 10 ** Decimals.USDC);
    uint112 internal constant EXPOSURE_USDC_WETH = uint112(1_500_000 * 10 ** Decimals.USDC);
    uint112 internal constant EXPOSURE_USDC_USDC = uint112(3_500_000 * 10 ** Decimals.USDC);

    // USDS
    uint16 internal constant COL_FAC_USDS_CBBTC = 7200;
    uint16 internal constant COL_FAC_USDS_USDC = 9200;
    uint16 internal constant COL_FAC_USDS_WETH = 8800;
    uint16 internal constant LIQ_FAC_USDS_CBBTC = 8750;
    uint16 internal constant LIQ_FAC_USDS_USDC = 9659;
    uint16 internal constant LIQ_FAC_USDS_WETH = 9450;
    uint112 internal constant EXPOSURE_USDS_CBBTC = uint112(0 * 10 ** Decimals.USDS);
    uint112 internal constant EXPOSURE_USDS_USDC = uint112(150_000 * 10 ** Decimals.USDS);
    uint112 internal constant EXPOSURE_USDS_WETH = uint112(100_000 * 10 ** Decimals.USDS);

    // USDT
    uint16 internal constant COL_FAC_USDT_WETH = 8850;
    uint16 internal constant COL_FAC_USDT_USDC = 9325;
    uint16 internal constant LIQ_FAC_USDT_WETH = 9475;
    uint16 internal constant LIQ_FAC_USDT_USDC = 9750;
    uint112 internal constant EXPOSURE_USDT_WETH = uint112(800_000 * 10 ** Decimals.USDT);
    uint112 internal constant EXPOSURE_USDT_USDC = uint112(1_000_000 * 10 ** Decimals.USDT);

    // USDZ
    uint16 internal constant COL_FAC_USDZ_CBBTC = 6800;
    uint16 internal constant COL_FAC_USDZ_WETH = 8550;
    uint16 internal constant COL_FAC_USDZ_USDC = 9000;
    uint16 internal constant LIQ_FAC_USDZ_CBBTC = 8525;
    uint16 internal constant LIQ_FAC_USDZ_WETH = 9225;
    uint16 internal constant LIQ_FAC_USDZ_USDC = 9500;
    uint112 internal constant EXPOSURE_USDZ_CBBTC = uint112(0 * 10 ** Decimals.USDZ);
    uint112 internal constant EXPOSURE_USDZ_WETH = uint112(0 * 10 ** Decimals.USDZ);
    uint112 internal constant EXPOSURE_USDZ_USDC = uint112(0 * 10 ** Decimals.USDZ);

    // VIRTUAL
    uint16 internal constant COL_FAC_VIRTUAL_CBBTC = 6900;
    uint16 internal constant COL_FAC_VIRTUAL_USDC = 6600;
    uint16 internal constant COL_FAC_VIRTUAL_WETH = 7200;
    uint16 internal constant LIQ_FAC_VIRTUAL_CBBTC = 8000;
    uint16 internal constant LIQ_FAC_VIRTUAL_USDC = 7800;
    uint16 internal constant LIQ_FAC_VIRTUAL_WETH = 8000;
    uint112 internal constant EXPOSURE_VIRTUAL_CBBTC = uint112(250_000 * 10 ** Decimals.VIRTUAL);
    uint112 internal constant EXPOSURE_VIRTUAL_WETH = uint112(350_000 * 10 ** Decimals.VIRTUAL);
    uint112 internal constant EXPOSURE_VIRTUAL_USDC = uint112(350_000 * 10 ** Decimals.VIRTUAL);

    // WEETH
    uint16 internal constant COL_FAC_WEETH_WETH = 9125;
    uint16 internal constant COL_FAC_WEETH_USDC = 8000;
    uint16 internal constant LIQ_FAC_WEETH_WETH = 9750;
    uint16 internal constant LIQ_FAC_WEETH_USDC = 8800;
    uint112 internal constant EXPOSURE_WEETH_WETH = uint112(500 * 10 ** Decimals.WEETH);
    uint112 internal constant EXPOSURE_WEETH_USDC = uint112(400 * 10 ** Decimals.WEETH);

    // WETH
    uint16 internal constant COL_FAC_WETH_CBBTC = 8500;
    uint16 internal constant COL_FAC_WETH_WETH = 9325;
    uint16 internal constant COL_FAC_WETH_USDC = 8850;
    uint16 internal constant LIQ_FAC_WETH_CBBTC = 9600;
    uint16 internal constant LIQ_FAC_WETH_WETH = 9750;
    uint16 internal constant LIQ_FAC_WETH_USDC = 9475;
    uint112 internal constant EXPOSURE_WETH_CBBTC = uint112(650 * 10 ** Decimals.WETH);
    uint112 internal constant EXPOSURE_WETH_WETH = uint112(1500 * 10 ** Decimals.WETH);
    uint112 internal constant EXPOSURE_WETH_USDC = uint112(1200 * 10 ** Decimals.WETH);

    // wrsETH
    uint16 internal constant COL_FAC_WRSETH_WETH = 8875;
    uint16 internal constant COL_FAC_WRSETH_USDC = 8275;
    uint16 internal constant LIQ_FAC_WRSETH_WETH = 9550;
    uint16 internal constant LIQ_FAC_WRSETH_USDC = 9100;
    uint112 internal constant EXPOSURE_WRSETH_WETH = uint112(200 * 10 ** Decimals.WRSETH);
    uint112 internal constant EXPOSURE_WRSETH_USDC = uint112(280 * 10 ** Decimals.WRSETH);

    // wstETH
    uint16 internal constant COL_FAC_WSTETH_WETH = 9325;
    uint16 internal constant COL_FAC_WSTETH_USDC = 8500;
    uint16 internal constant LIQ_FAC_WSTETH_WETH = 9750;
    uint16 internal constant LIQ_FAC_WSTETH_USDC = 9300;
    uint112 internal constant EXPOSURE_WSTETH_WETH = uint112(400 * 10 ** Decimals.WSTETH);
    uint112 internal constant EXPOSURE_WSTETH_USDC = uint112(300 * 10 ** Decimals.WSTETH);

    // Aerodrome Pool Asset Module
    uint16 internal constant RISK_FAC_AERO_POOL_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_AERO_POOL_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_AERO_POOL_AM_WETH = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_AERO_POOL_AM_USDC = uint112(2_000_000 * 1e18);

    // Alien Base Asset Module
    uint16 internal constant RISK_FAC_ALIEN_BASE_AM_CBBTC = 9800;
    uint16 internal constant RISK_FAC_ALIEN_BASE_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_ALIEN_BASE_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_ALIEN_BASE_AM_CBBTC = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_ALIEN_BASE_AM_WETH = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_ALIEN_BASE_AM_USDC = uint112(2_000_000 * 1e18);

    // Default UniswapV4 Asset Module
    uint16 internal constant RISK_FAC_DEFAULT_UNISWAPV4_AM_CBBTC = 9800;
    uint16 internal constant RISK_FAC_DEFAULT_UNISWAPV4_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_DEFAULT_UNISWAPV4_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_DEFAULT_UNISWAPV4_AM_CBBTC = uint112(5_000_000 * 1e18);
    uint112 internal constant EXPOSURE_DEFAULT_UNISWAPV4_AM_WETH = uint112(5_000_000 * 1e18);
    uint112 internal constant EXPOSURE_DEFAULT_UNISWAPV4_AM_USDC = uint112(5_000_000 * 1e18);

    // Slipstream Asset Module
    uint16 internal constant RISK_FAC_SLIPSTREAM_CBBTC = 9800;
    uint16 internal constant RISK_FAC_SLIPSTREAM_WETH = 9800;
    uint16 internal constant RISK_FAC_SLIPSTREAM_USDC = 9800;
    uint112 internal constant EXPOSURE_SLIPSTREAM_CBBTC = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_SLIPSTREAM_WETH = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_SLIPSTREAM_USDC = uint112(2_000_000 * 1e18);

    // Staked Aerodrome Pool Asset Module
    uint16 internal constant RISK_FAC_STAKED_AERO_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_STAKED_AERO_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_STAKED_AERO_AM_WETH = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_STAKED_AERO_AM_USDC = uint112(2_000_000 * 1e18);

    // Staked Slipstream Asset Module
    uint16 internal constant RISK_FAC_STAKED_SLIPSTREAM_AM_CBBTC = 9800;
    uint16 internal constant RISK_FAC_STAKED_SLIPSTREAM_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_STAKED_SLIPSTREAM_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_STAKED_SLIPSTREAM_AM_CBBTC = uint112(10_000_000 * 1e18);
    uint112 internal constant EXPOSURE_STAKED_SLIPSTREAM_AM_WETH = uint112(10_000_000 * 1e18);
    uint112 internal constant EXPOSURE_STAKED_SLIPSTREAM_AM_USDC = uint112(10_000_000 * 1e18);

    // Staked Stargate Asset Module
    uint16 internal constant RISK_FAC_STAKED_STARGATE_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_STAKED_STARGATE_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_STAKED_STARGATE_AM_WETH = uint112(250_000 * 1e18);
    uint112 internal constant EXPOSURE_STAKED_STARGATE_AM_USDC = uint112(250_000 * 1e18);

    // Stargate Asset Module
    uint16 internal constant RISK_FAC_STARGATE_AM_WETH = 9700;
    uint16 internal constant RISK_FAC_STARGATE_AM_USDC = 9700;
    uint112 internal constant EXPOSURE_STARGATE_AM_WETH = uint112(250_000 * 1e18);
    uint112 internal constant EXPOSURE_STARGATE_AM_USDC = uint112(250_000 * 1e18);

    // Uniswap V3 Asset Module
    uint16 internal constant RISK_FAC_UNISWAPV3_AM_CBBTC = 9800;
    uint16 internal constant RISK_FAC_UNISWAPV3_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_UNISWAPV3_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_UNISWAPV3_AM_CBBTC = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_UNISWAPV3_AM_WETH = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_UNISWAPV3_AM_USDC = uint112(2_000_000 * 1e18);

    // Wrapped Aerodrome Pool Asset Module
    uint16 internal constant RISK_FAC_WRAPPED_AERO_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_WRAPPED_AERO_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_WRAPPED_AERO_AM_WETH = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_WRAPPED_AERO_AM_USDC = uint112(2_000_000 * 1e18);

    // cbBTC Lending Pool
    uint128 internal constant MIN_USD_VALUE_CBBTC = 1 * 1e18;
    uint64 internal constant GRACE_PERIOD_CBBTC = 15 minutes;
    uint64 internal constant MAX_RECURSIVE_CALLS_CBBTC = 6;

    // USDC Lending Pool
    uint128 internal constant MIN_USD_VALUE_USDC = 1 * 1e18;
    uint64 internal constant GRACE_PERIOD_USDC = 15 minutes;
    uint64 internal constant MAX_RECURSIVE_CALLS_USDC = 6;

    // WETH Lending Pool
    uint128 internal constant MIN_USD_VALUE_WETH = 1 * 1e18;
    uint64 internal constant GRACE_PERIOD_WETH = 15 minutes;
    uint64 internal constant MAX_RECURSIVE_CALLS_WETH = 6;
}

library ExternalContracts {
    address internal constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address internal constant AERO_VOTER = 0x16613524e02ad97eDfeF371bC883F2F5d6C480A5;
    address internal constant ALIEN_BASE_POS_MNGR = 0xB7996D1ECD07fB227e8DcA8CD5214bDfb04534E5;
    address internal constant SEQUENCER_UPTIME_ORACLE = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;
    address internal constant SLIPSTREAM_POS_MNGR = 0x827922686190790b37229fd06084350E74485b72;
    address internal constant STARGATE_FACTORY = 0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6;
    address internal constant STARGATE_LP_STAKING = 0x06Eb48763f117c7Be887296CDcdfad2E4092739C;
    address internal constant UNISWAPV3_POS_MNGR = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address internal constant UNISWAPV4_POS_MNGR = 0x7C5f5A4bBd8fD63184577525326123B519429bDc;
}

library StargatePoolIds {
    uint256 internal constant WETH = 13;
    uint256 internal constant USDBC = 1;
}

library StargatePids {
    uint256 internal constant USDBC = 1;
}

library AerodromeGauges {
    address internal constant CL1_CBETH_WETH = address(0xF5550F8F0331B8CAA165046667f4E6628E9E3Aac);
    address internal constant CL1_EURC_USDC = address(0x85af8D930cB738954d307D6E62F04dd05D839C37);
    address internal constant CL1_EZETH_WETH = address(0xC6B4fe83Fb284bDdE1f1d19F0B5beB31011B280A);
    address internal constant CL1_TBTC_CBBTC = address(0xB57eC27f68Bd356e300D57079B6cdbe57d50830d);
    address internal constant CL1_USDC_USDBC = address(0x4a3E1294d7869567B387FC3d5e5Ccf14BE2Bbe0a);
    address internal constant CL1_USDC_USDT = address(0xBd85D45f1636fCEB2359d9Dcf839f12b3cF5AF3F);
    address internal constant CL1_USDS_USDC = address(0xe2a2B1D8AA4bD8A05e517Ccf61E96A727831B63e);
    address internal constant CL1_USDZ_USDC = address(0xE2F3C8c699A1bf30A12118B287B5208e7C6ddFEF);
    address internal constant CL1_WEETH_WETH = address(0xfCfEE5f453728BaA5ffDA151f25A0e53B8C5A01C);
    address internal constant CL1_WETH_WRSETH = address(0xEc33F9cbE64c7Bc9b262Efaaa56b7872e8889AaE);
    address internal constant CL1_WETH_WSTETH = address(0x2A1f7bf46bd975b5004b61c6040597E1B6117040);
    address internal constant CL1_WSTETH_WRSETH = address(0x4197186D3D65f694018Ae4B80355225Ce1dD64AD);
    address internal constant CL50_EURC_USDC = address(0x1f6c9d116CE22b51b0BC666f86B038a6c19900B8);
    address internal constant CL100_EURC_CBBTC = address(0x017a82B26d612cAD89d240206F652E76ae8C4B31);
    address internal constant CL100_USDC_CBBTC = address(0x6399ed6725cC163D019aA64FF55b22149D7179A8);
    address internal constant CL100_USDC_TRUMP = address(0x0c1D14b66e74FBB35d53A0c97Dbe93fa8a97BbE7);
    address internal constant CL100_USDZ_CBBTC = address(0x384Ce87727323eDeDdc95D3206399806A3da7F02);
    address internal constant CL100_USDZ_WETH = address(0x549690894f61bf0D3a5799D03fDED6e775A424aA);
    address internal constant CL100_VIRTUAL_WETH = address(0x5013Ea8783Bfeaa8c4850a54eacd54D7A3B7f889);
    address internal constant CL100_WETH_CBBTC = address(0x41b2126661C673C2beDd208cC72E85DC51a5320a);
    address internal constant CL100_WETH_EURC = address(0xb0C500d53720ff63F000de6D26f7Fe5c66571e3d);
    address internal constant CL100_WETH_USDC = address(0xF33a96b5932D9E9B9A0eDA447AbD8C9d48d2e0c8);
    address internal constant CL100_WETH_USDT = address(0x2c0CbF25Bb64687d11ea2E4a3dc893D56Ca39c10);
    address internal constant CL200_AERO_WSTETH = address(0x45F8b8eC9c92D09BA8495074436fD97073423041);
    address internal constant CL200_AERO_CBBTC = address(0x2B74B62c564456C48055bd515A62594742b3f545);
    address internal constant CL200_TBTC_WETH = address(0x996802075582Af2eE133fb30Cc5A9E8A671d3c3a);
    address internal constant CL200_TBTC_USDC = address(0x37E1a626b09faDE99E94752942a88f17EA2170fd);
    address internal constant CL200_USDZ_DEGEN = address(0x9918C85E4e5937DA606d65C9935Ea3ffe4DE06A4);
    address internal constant CL200_VIRTUAL_WETH = address(0xBDA319Bc7Cc8F0829df39eC0FFF5D1E061FFadf7);
    address internal constant CL200_WETH_AERO = address(0xdE8FF0D3e8ab225110B088a250b546015C567E27);
    address internal constant CL200_WETH_DEGEN = address(0x319e23D38d8ee58783Ff5331507b808709bd00b0);
    address internal constant CL200_WETH_RDNT = address(0x8D88C541f22de965536bD1849013caEE6ce90e11);
    address internal constant S_EZETH_WETH = address(0x4Fa58b3Bec8cE12014c7775a0B3da7e6AdC3c7eA);
    address internal constant S_USDC_USDBC = address(0x1Cfc45C5221A07DA0DE958098A319a29FbBD66fE);
    address internal constant S_USDZ_USDC = address(0xb7E4bBee04285F4B55d0A93b34E5dA95C3a7faf9);
    address internal constant V_AERO_USDBC = address(0x9a202c932453fB3d04003979B121E80e5A14eE7b);
    address internal constant V_AERO_WSTETH = address(0x26D6D4E9e3fAf1C7C19992B1Ca792e4A9ea4F833);
    address internal constant V_CBETH_WETH = address(0xDf9D427711CCE46b52fEB6B2a20e4aEaeA12B2b7);
    address internal constant V_EURC_USDC = address(0x1f077baf21b95314bD251b21aD1f0Cc8D5D86781);
    address internal constant V_EZETH_WETH = address(0x6318373c5a01224094BF0B1AC88562345B2Fb91E);
    address internal constant V_USDC_AERO = address(0x4F09bAb2f0E15e2A078A227FE1537665F55b8360);
    address internal constant V_USDZ_WETH = address(0xc15B32d92E265832c87EC4b36B7e598ae2daad42);
    address internal constant V_VIRTUAL_AERO = address(0x57538a02972c01440113cC7A7Ff8F1d954d01239);
    address internal constant V_VIRTUAL_CBBTC = address(0x8c44e7F913D0893Cd5A3CBBb2fCd59785a7801ab);
    address internal constant V_VIRTUAL_WETH = address(0xBD62Cad65b49b4Ad9C7aa9b8bDB89d63221F7af5);
    address internal constant V_WEETH_AERO = address(0x0A5f63A1aC754b4418cc5381eE17E04CCad42F56);
    address internal constant V_WEETH_WETH = address(0xf8d47b641eD9DF1c924C0F7A6deEEA2803b9CfeF);
    address internal constant V_WETH_AERO = address(0x96a24aB830D4ec8b1F6f04Ceac104F1A3b211a01);
    address internal constant V_WETH_DEGEN = address(0x86A1260AB9f758026Ce1a5830BdfF66DBcF736d5);
    address internal constant V_WETH_EURC = address(0x21D4eF9D2b66069f3307765A0349526f8E988294);
    address internal constant V_WETH_USDBC = address(0xeca7Ff920E7162334634c721133F3183B83B0323);
    address internal constant V_WETH_USDC = address(0x519BBD1Dd8C6A94C46080E24f316c14Ee758C025);
    address internal constant V_WETH_WRSETH = address(0x2da7789a6371F550caF9054694F5A5A6682903f9);
    address internal constant V_WETH_WSTETH = address(0xDf7c8F17Ab7D47702A4a4b6D951d2A4c90F99bf4);
}

library AerodromePools {
    address internal constant S_EZETH_WETH = address(0x497139e8435E01555AC1e3740fccab7AFf149e02);
    address internal constant S_USDC_USDBC = address(0x27a8Afa3Bd49406e48a074350fB7b2020c43B2bD);
    address internal constant S_USDZ_USDC = address(0x6d0b9C9E92a3De30081563c3657B5258b3fFa38B);
    address internal constant V_AERO_USDBC = address(0x2223F9FE624F69Da4D8256A7bCc9104FBA7F8f75);
    address internal constant V_AERO_WSTETH = address(0x82a0c1a0d4EF0c0cA3cFDA3AD1AA78309Cc6139b);
    address internal constant V_CBETH_WETH = address(0x44Ecc644449fC3a9858d2007CaA8CFAa4C561f91);
    address internal constant V_EURC_USDC = address(0xFDF5139b38525627B47538536042A7c8d2686BD9);
    address internal constant V_EZETH_WETH = address(0x0C8bF3cb3E1f951B284EF14aa95444be86a33E2f);
    address internal constant V_USDC_AERO = address(0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAFb971d);
    address internal constant V_USDZ_WETH = address(0x2ce63497999F520CC2afaaadbCFC37Afd9deF4b0);
    address internal constant V_VIRTUAL_AERO = address(0x8B49c7eC53Cb4CA3666bB16727FC5C5F6d12226f);
    address internal constant V_VIRTUAL_CBBTC = address(0xb909F567c5c2Bb1A4271349708CC4637D7318b4A);
    address internal constant V_VIRTUAL_WETH = address(0x21594b992F68495dD28d605834b58889d0a727c7);
    address internal constant V_WEETH_AERO = address(0xc5aDfb267a95df1233a2b5F7f48041E7Fb384BcA);
    address internal constant V_WEETH_WETH = address(0x91F0f34916Ca4E2cCe120116774b0e4fA0cdcaA8);
    address internal constant V_WETH_AERO = address(0x7f670f78B17dEC44d5Ef68a48740b6f8849cc2e6);
    address internal constant V_WETH_DEGEN = address(0x2C4909355b0C036840819484c3A882A95659aBf3);
    address internal constant V_WETH_EURC = address(0x9DFf4b5AE4fD673213502Ab8fbf6d36015efb3E1);
    address internal constant V_WETH_USDBC = address(0xB4885Bc63399BF5518b994c1d0C153334Ee579D0);
    address internal constant V_WETH_USDC = address(0xcDAC0d6c6C59727a65F871236188350531885C43);
    address internal constant V_WETH_WRSETH = address(0xA24382874A6FD59de45BbccFa160488647514c28);
    address internal constant V_WETH_WSTETH = address(0xA6385c73961dd9C58db2EF0c4EB98cE4B60651e8);
}
