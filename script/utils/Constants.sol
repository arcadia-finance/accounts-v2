/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

library ArcadiaContracts {
    address internal constant AERO_POOL_AM = address(0xfe0FA1FD8F8E889062F03e2f126Fc7B9DE6091A5); // TODo:fork address!!
    address internal constant CHAINLINK_OM = address(0x6a5485E3ce6913890ae5e8bDc08a868D432eEB31);
    address internal constant ERC20_PRIMARY_AM = address(0xfBecEaFC96ed6fc800753d3eE6782b6F9a60Eed7);
    address internal constant FACTORY = address(0xDa14Fdd72345c4d2511357214c5B89A919768e59);
    address internal constant REGISTRY = address(0xd0690557600eb8Be8391D1d97346e2aab5300d5f);
    address internal constant SLIPSTREAM_AM = address(0xd3A7055bBcDA4F8F49e5c5dE7E83B09a33633F44); // TODo:fork address!!
    address internal constant STAKED_AERO_AM = address(0x9f42361B7602Df1A8Ae28Bf63E6cb1883CD44C27); // TODo:fork address!!
    address internal constant STAKED_STARGATE_AM = address(0xae909e19fd13C01c28d5Ee439D403920CF7f9Eea);
    address internal constant STARGATE_AM = address(0x20f7903290bF98716B62Dc1c9DA634291b8cfeD4);
    address internal constant UNISWAPV3_AM = address(0x21bd524cC54CA78A7c48254d4676184f781667dC);
    address internal constant LENDINGPOOL_USDC = address(0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1);
    address internal constant LENDINGPOOL_WETH = address(0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2);
    address internal constant WRAPPED_AERO_AM = address(0x17B5826382e3a5257b829cF0546A08Bd77409270); // TODo:fork address!!
}

library ArcadiaSafes {
    address internal constant OWNER = address(0xb4d72B1c91e640e4ED7d7397F3244De4D8ACc50B);
    address internal constant GUARDIAN = address(0xEdD41f9740b06eCBfe1CE9194Ce2715C28263187);
    address internal constant RISK_MANAGER = address(0xD5FA6C6e284007743d4263255385eDA78dDa268c);
}

library MerkleRoots {
    bytes32 internal constant UPGRADE_ROOT_1_TO_1 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;
}

library PrimaryAssets {
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address internal constant COMP = 0x9e1028F5F1D5eDE59748FFceE5532509976840E0;
    address internal constant USDBC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant TBTC = 0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b;
    address internal constant CRVUSD = 0x417Ac0e078398C154EdFadD9Ef675d30Be60Af93;
    address internal constant CBETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address internal constant RETH = 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c;
    address internal constant SUSHI = 0x7D49a065D17d6d4a55dc13649901fdBB98B2AFBA;
    address internal constant AXLUSDC = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;
    address internal constant AXLDAI = 0x5C7e299CF531eb66f2A1dF637d37AbB78e6200C7;
    address internal constant AXLUSDT = 0x7f5373AE26c3E8FfC4c77b7255DF7eC1A9aF52a6;
    address internal constant AXL = 0x23ee2343B892b1BB63503a4FAbc840E0e2C6810f;
    address internal constant CRV = 0x8Ee73c484A26e0A5df2Ee2a4960B789967dd0415;
    address internal constant STG = 0xE3B53AF74a4BF62Ae5511055290838050bf764Df;
    address internal constant WSTETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address internal constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
}

library Decimals {
    uint8 internal constant WETH = 18;
    uint8 internal constant DAI = 18;
    uint8 internal constant COMP = 18;
    uint8 internal constant USDC = 6;
    uint8 internal constant USDBC = 6;
    uint8 internal constant TBTC = 18;
    uint8 internal constant CRVUSD = 18;
    uint8 internal constant CBETH = 18;
    uint8 internal constant RETH = 18;
    uint8 internal constant SUSHI = 18;
    uint8 internal constant AXLUSDC = 6;
    uint8 internal constant AXLDAI = 18;
    uint8 internal constant AXLUSDT = 6;
    uint8 internal constant AXL = 6;
    uint8 internal constant CRV = 18;
    uint8 internal constant STG = 18;
    uint8 internal constant WSTETH = 18;
    uint8 internal constant AERO = 18;
}

library Oracles {
    address internal constant COMP_USD = 0x9DDa783DE64A9d1A60c49ca761EbE528C35BA428;
    address internal constant DAI_USD = 0x591e79239a7d679378eC8c847e5038150364C78F;
    address internal constant ETH_USD = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address internal constant CBETH_USD = 0xd7818272B9e248357d13057AAb0B417aF31E817d;
    address internal constant USDC_USD = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address internal constant USDBC_USD = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address internal constant WBTC_USD = 0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E;
    address internal constant RETH_ETH = 0xf397bF97280B488cA19ee3093E81C0a77F02e9a5;
    address internal constant STG_USD = 0x63Af8341b62E683B87bB540896bF283D96B4D385;
    address internal constant WSTETH_ETH = 0xa669E5272E60f78299F4824495cE01a3923f4380;
    address internal constant AERO_USD = 0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0;
}

library OracleIds {
    uint80 internal constant AERO_USD = 8;
    uint80 internal constant ETH_USD = 2;
}

library CutOffTimes {
    uint32 internal constant COMP_USD = 25 hours;
    uint32 internal constant DAI_USD = 25 hours;
    uint32 internal constant ETH_USD = 1 hours;
    uint32 internal constant USDC_USD = 25 hours;
    uint32 internal constant CBETH_USD = 1 hours;
    uint32 internal constant RETH_ETH = 25 hours;
    uint32 internal constant STG_USD = 25 hours;
    uint32 internal constant WSTETH_ETH = 25 hours;
    uint32 internal constant AERO_USD = 25 hours;
}

library RiskParameters {
    uint16 internal constant COL_FAC_COMP_WETH = 7000;
    uint16 internal constant COL_FAC_COMP_USDC = 6500;
    uint16 internal constant LIQ_FAC_COMP_WETH = 7700;
    uint16 internal constant LIQ_FAC_COMP_USDC = 7200;
    uint112 internal constant EXPOSURE_COMP_WETH = 0;
    uint112 internal constant EXPOSURE_COMP_USDC = 0;

    uint16 internal constant COL_FAC_DAI_WETH = 8100;
    uint16 internal constant COL_FAC_DAI_USDC = 8300;
    uint16 internal constant LIQ_FAC_DAI_WETH = 8600;
    uint16 internal constant LIQ_FAC_DAI_USDC = 8700;
    uint112 internal constant EXPOSURE_DAI_WETH = uint112(500_000 * 10 ** Decimals.DAI);
    uint112 internal constant EXPOSURE_DAI_USDC = uint112(500_000 * 10 ** Decimals.DAI);

    uint16 internal constant COL_FAC_WETH_WETH = 9000;
    uint16 internal constant COL_FAC_WETH_USDC = 8100;
    uint16 internal constant LIQ_FAC_WETH_WETH = 9400;
    uint16 internal constant LIQ_FAC_WETH_USDC = 8500;
    uint112 internal constant EXPOSURE_WETH_WETH = uint112(1000 * 10 ** Decimals.WETH);
    uint112 internal constant EXPOSURE_WETH_USDC = uint112(500 * 10 ** Decimals.WETH);

    uint16 internal constant COL_FAC_USDC_WETH = 8600;
    uint16 internal constant COL_FAC_USDC_USDC = 9000;
    uint16 internal constant LIQ_FAC_USDC_WETH = 9200;
    uint16 internal constant LIQ_FAC_USDC_USDC = 9400;
    uint112 internal constant EXPOSURE_USDC_WETH = uint112(800_000 * 10 ** Decimals.USDC);
    uint112 internal constant EXPOSURE_USDC_USDC = uint112(1_000_000 * 10 ** Decimals.USDC);

    uint16 internal constant COL_FAC_USDBC_WETH = 8600;
    uint16 internal constant COL_FAC_USDBC_USDC = 9000;
    uint16 internal constant LIQ_FAC_USDBC_WETH = 9200;
    uint16 internal constant LIQ_FAC_USDBC_USDC = 9400;
    uint112 internal constant EXPOSURE_USDBC_WETH = uint112(750_000 * 10 ** Decimals.USDBC);
    uint112 internal constant EXPOSURE_USDBC_USDC = uint112(1_000_000 * 10 ** Decimals.USDBC);

    uint16 internal constant COL_FAC_WBTC_WETH = 7600;
    uint16 internal constant COL_FAC_WBTC_USDC = 8600;
    uint16 internal constant LIQ_FAC_WBTC_WETH = 8400;
    uint16 internal constant LIQ_FAC_WBTC_USDC = 9400;
    uint112 internal constant EXPOSURE_WBTC_WETH = 0;
    uint112 internal constant EXPOSURE_WBTC_USDC = 0;

    uint16 internal constant COL_FAC_CBETH_WETH = 9100;
    uint16 internal constant COL_FAC_CBETH_USDC = 8100;
    uint16 internal constant LIQ_FAC_CBETH_WETH = 9500;
    uint16 internal constant LIQ_FAC_CBETH_USDC = 9400;
    uint112 internal constant EXPOSURE_CBETH_WETH = uint112(400 * 10 ** Decimals.CBETH);
    uint112 internal constant EXPOSURE_CBETH_USDC = uint112(300 * 10 ** Decimals.CBETH);

    uint16 internal constant COL_FAC_RETH_WETH = 8500;
    uint16 internal constant COL_FAC_RETH_USDC = 8100;
    uint16 internal constant LIQ_FAC_RETH_WETH = 9200;
    uint16 internal constant LIQ_FAC_RETH_USDC = 9400;
    uint112 internal constant EXPOSURE_RETH_WETH = uint112(210 * 10 ** Decimals.RETH);
    uint112 internal constant EXPOSURE_RETH_USDC = uint112(200 * 10 ** Decimals.RETH);

    uint16 internal constant COL_FAC_SUSHI_WETH = 7600;
    uint16 internal constant COL_FAC_SUSHI_USDC = 8600;
    uint16 internal constant LIQ_FAC_SUSHI_WETH = 8400;
    uint16 internal constant LIQ_FAC_SUSHI_USDC = 9400;
    uint112 internal constant EXPOSURE_SUSHI_WETH = 0;
    uint112 internal constant EXPOSURE_SUSHI_USDC = 0;

    uint16 internal constant COL_FAC_AXLUSDC_WETH = 7600;
    uint16 internal constant COL_FAC_AXLUSDC_USDC = 8600;
    uint16 internal constant LIQ_FAC_AXLUSDC_WETH = 8400;
    uint16 internal constant LIQ_FAC_AXLUSDC_USDC = 9400;
    uint112 internal constant EXPOSURE_AXLUSDC_WETH = 0;
    uint112 internal constant EXPOSURE_AXLUSDC_USDC = 0;

    uint16 internal constant COL_FAC_AXLDAI_WETH = 7600;
    uint16 internal constant COL_FAC_AXLDAI_USDC = 8600;
    uint16 internal constant LIQ_FAC_AXLDAI_WETH = 8400;
    uint16 internal constant LIQ_FAC_AXLDAI_USDC = 9400;
    uint112 internal constant EXPOSURE_AXLDAI_WETH = 0;
    uint112 internal constant EXPOSURE_AXLDAI_USDC = 0;

    uint16 internal constant COL_FAC_AXLUSDT_WETH = 7600;
    uint16 internal constant COL_FAC_AXLUSDT_USDC = 8600;
    uint16 internal constant LIQ_FAC_AXLUSDT_WETH = 8400;
    uint16 internal constant LIQ_FAC_AXLUSDT_USDC = 9400;
    uint112 internal constant EXPOSURE_AXLUSDT_WETH = 0;
    uint112 internal constant EXPOSURE_AXLUSDT_USDC = 0;

    uint16 internal constant COL_FAC_AXL_WETH = 7600;
    uint16 internal constant COL_FAC_AXL_USDC = 8600;
    uint16 internal constant LIQ_FAC_AXL_WETH = 8400;
    uint16 internal constant LIQ_FAC_AXL_USDC = 9400;
    uint112 internal constant EXPOSURE_AXL_WETH = 0;
    uint112 internal constant EXPOSURE_AXL_USDC = 0;

    uint16 internal constant COL_FAC_CRV_WETH = 5500;
    uint16 internal constant COL_FAC_CRV_USDC = 5000;
    uint16 internal constant LIQ_FAC_CRV_WETH = 7000;
    uint16 internal constant LIQ_FAC_CRV_USDC = 6500;
    uint112 internal constant EXPOSURE_CRV_WETH = 0;
    uint112 internal constant EXPOSURE_CRV_USDC = 0;

    uint16 internal constant COL_FAC_TBTC_WETH = 7600;
    uint16 internal constant COL_FAC_TBTC_USDC = 8600;
    uint16 internal constant LIQ_FAC_TBTC_WETH = 8400;
    uint16 internal constant LIQ_FAC_TBTC_USDC = 9400;
    uint112 internal constant EXPOSURE_TBTC_WETH = 0;
    uint112 internal constant EXPOSURE_TBTC_USDC = 0;

    uint16 internal constant COL_FAC_CRVUSD_WETH = 7600;
    uint16 internal constant COL_FAC_CRVUSD_USDC = 8600;
    uint16 internal constant LIQ_FAC_CRVUSD_WETH = 8400;
    uint16 internal constant LIQ_FAC_CRVUSD_USDC = 9400;
    uint112 internal constant EXPOSURE_CRVUSD_WETH = 0;
    uint112 internal constant EXPOSURE_CRVUSD_USDC = 0;

    uint16 internal constant COL_FAC_STG_WETH = 6000;
    uint16 internal constant COL_FAC_STG_USDC = 5500;
    uint16 internal constant LIQ_FAC_STG_WETH = 7200;
    uint16 internal constant LIQ_FAC_STG_USDC = 7000;
    uint112 internal constant EXPOSURE_STG_WETH = 1; // Cannot be deposited as primary asset, but still as yield source
    uint112 internal constant EXPOSURE_STG_USDC = 1; // Cannot be deposited as primary asset, but still as yield source

    uint16 internal constant COL_FAC_WSTETH_WETH = 9100;
    uint16 internal constant COL_FAC_WSTETH_USDC = 8100;
    uint16 internal constant LIQ_FAC_WSTETH_WETH = 9500;
    uint16 internal constant LIQ_FAC_WSTETH_USDC = 9400;
    uint112 internal constant EXPOSURE_WSTETH_WETH = uint112(400 * 10 ** Decimals.WSTETH);
    uint112 internal constant EXPOSURE_WSTETH_USDC = uint112(300 * 10 ** Decimals.WSTETH);

    uint16 internal constant COL_FAC_AERO_WETH = 7500;
    uint16 internal constant COL_FAC_AERO_USDC = 6700;
    uint16 internal constant LIQ_FAC_AERO_WETH = 8700;
    uint16 internal constant LIQ_FAC_AERO_USDC = 8000;
    uint112 internal constant EXPOSURE_AERO_WETH = uint112(3e6 * 10 ** Decimals.AERO);
    uint112 internal constant EXPOSURE_AERO_USDC = uint112(3e6 * 10 ** Decimals.AERO);

    uint16 internal constant RISK_FAC_AERO_POOL_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_AERO_POOL_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_AERO_POOL_AM_WETH = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_AERO_POOL_AM_USDC = uint112(2_000_000 * 1e18);

    uint16 internal constant RISK_FAC_STAKED_AERO_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_STAKED_AERO_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_STAKED_AERO_AM_WETH = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_STAKED_AERO_AM_USDC = uint112(2_000_000 * 1e18);

    uint16 internal constant RISK_FAC_WRAPPED_AERO_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_WRAPPED_AERO_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_WRAPPED_AERO_AM_WETH = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_WRAPPED_AERO_AM_USDC = uint112(2_000_000 * 1e18);

    uint16 internal constant RISK_FAC_STAKED_STARGATE_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_STAKED_STARGATE_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_STAKED_STARGATE_AM_WETH = uint112(250_000 * 1e18);
    uint112 internal constant EXPOSURE_STAKED_STARGATE_AM_USDC = uint112(250_000 * 1e18);

    uint16 internal constant RISK_FAC_STARGATE_AM_WETH = 9700;
    uint16 internal constant RISK_FAC_STARGATE_AM_USDC = 9700;
    uint112 internal constant EXPOSURE_STARGATE_AM_WETH = uint112(250_000 * 1e18);
    uint112 internal constant EXPOSURE_STARGATE_AM_USDC = uint112(250_000 * 1e18);

    uint16 internal constant RISK_FAC_UNISWAPV3_AM_WETH = 9800;
    uint16 internal constant RISK_FAC_UNISWAPV3_AM_USDC = 9800;
    uint112 internal constant EXPOSURE_UNISWAPV3_AM_WETH = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_UNISWAPV3_AM_USDC = uint112(2_000_000 * 1e18);

    // ToDo: change before deployment
    uint16 internal constant RISK_FAC_SLIPSTREAM_WETH = 9800;
    uint16 internal constant RISK_FAC_SLIPSTREAM_USDC = 9800;
    uint112 internal constant EXPOSURE_SLIPSTREAM_WETH = uint112(2_000_000 * 1e18);
    uint112 internal constant EXPOSURE_SLIPSTREAM_USDC = uint112(2_000_000 * 1e18);

    uint128 internal constant MIN_USD_VALUE_WETH = 1 * 1e18;
    uint64 internal constant GRACE_PERIOD_WETH = 15 minutes;
    uint64 internal constant MAX_RECURSIVE_CALLS_WETH = 5;

    uint128 internal constant MIN_USD_VALUE_USDC = 1 * 1e18;
    uint64 internal constant GRACE_PERIOD_USDC = 15 minutes;
    uint64 internal constant MAX_RECURSIVE_CALLS_USDC = 5;
}

library ExternalContracts {
    address internal constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address internal constant AERO_VOTER = 0x16613524e02ad97eDfeF371bC883F2F5d6C480A5;
    address internal constant SEQUENCER_UPTIME_ORACLE = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;
    address internal constant SLIPSTREAM_POS_MNGR = 0x827922686190790b37229fd06084350E74485b72;
    address internal constant STARGATE_FACTORY = 0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6;
    address internal constant STARGATE_LP_STAKING = 0x06Eb48763f117c7Be887296CDcdfad2E4092739C;
    address internal constant UNISWAPV3_POS_MNGR = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
}

library StargatePoolIds {
    uint256 internal constant WETH = 13;
    uint256 internal constant USDBC = 1;
}

library StargatePids {
    uint256 internal constant USDBC = 1;
}

library AerodromeGauges {
    address internal constant V_AERO_USDBC = address(0x9a202c932453fB3d04003979B121E80e5A14eE7b);
    address internal constant V_AERO_WSTETH = address(0x26D6D4E9e3fAf1C7C19992B1Ca792e4A9ea4F833);
    address internal constant V_CBETH_WETH = address(0xDf9D427711CCE46b52fEB6B2a20e4aEaeA12B2b7);
    address internal constant V_USDC_AERO = address(0x4F09bAb2f0E15e2A078A227FE1537665F55b8360);
    address internal constant V_WETH_AERO = address(0x96a24aB830D4ec8b1F6f04Ceac104F1A3b211a01);
    address internal constant V_WETH_USDC = address(0x519BBD1Dd8C6A94C46080E24f316c14Ee758C025);
    address internal constant V_WETH_USDBC = address(0xeca7Ff920E7162334634c721133F3183B83B0323);
    address internal constant V_WETH_WSTETH = address(0xDf7c8F17Ab7D47702A4a4b6D951d2A4c90F99bf4);
    address internal constant S_USDC_USDBC = address(0x1Cfc45C5221A07DA0DE958098A319a29FbBD66fE);
}

library AerodromePools {
    address internal constant V_AERO_USDBC = address(0x2223F9FE624F69Da4D8256A7bCc9104FBA7F8f75);
    address internal constant V_AERO_WSTETH = address(0x82a0c1a0d4EF0c0cA3cFDA3AD1AA78309Cc6139b);
    address internal constant V_CBETH_WETH = address(0x44Ecc644449fC3a9858d2007CaA8CFAa4C561f91);
    address internal constant V_USDC_AERO = address(0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAFb971d);
    address internal constant V_WETH_AERO = address(0x7f670f78B17dEC44d5Ef68a48740b6f8849cc2e6);
    address internal constant V_WETH_USDC = address(0xcDAC0d6c6C59727a65F871236188350531885C43);
    address internal constant V_WETH_USDBC = address(0xB4885Bc63399BF5518b994c1d0C153334Ee579D0);
    address internal constant V_WETH_WSTETH = address(0xA6385c73961dd9C58db2EF0c4EB98cE4B60651e8);
    address internal constant S_USDC_USDBC = address(0x27a8Afa3Bd49406e48a074350fB7b2020c43B2bD);
}
