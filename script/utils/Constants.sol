/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

library DeployAddresses {
    // base
    address public constant weth_base = 0x4200000000000000000000000000000000000006;
    address public constant dai_base = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address public constant comp_base = 0x9e1028F5F1D5eDE59748FFceE5532509976840E0;
    address public constant usdbc_base = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address public constant usdc_base = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant tbtc_base = 0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b;
    address public constant crvusd_base = 0x417Ac0e078398C154EdFadD9Ef675d30Be60Af93;
    address public constant cbeth_base = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address public constant reth_base = 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c;
    address public constant sushi_base = 0x7D49a065D17d6d4a55dc13649901fdBB98B2AFBA;
    address public constant axlusdc_base = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;
    address public constant axldai_base = 0x5C7e299CF531eb66f2A1dF637d37AbB78e6200C7;
    address public constant axlusdt_base = 0x7f5373AE26c3E8FfC4c77b7255DF7eC1A9aF52a6;
    address public constant axl_base = 0x23ee2343B892b1BB63503a4FAbc840E0e2C6810f;
    address public constant crv_base = 0x8Ee73c484A26e0A5df2Ee2a4960B789967dd0415;
    address public constant stg_base = 0xE3B53AF74a4BF62Ae5511055290838050bf764Df;
    address public constant wsteth_base = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address public constant aero_base = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;

    address public constant oracleCompToUsd_base = 0x9DDa783DE64A9d1A60c49ca761EbE528C35BA428;
    address public constant oracleDaiToUsd_base = 0x591e79239a7d679378eC8c847e5038150364C78F;
    address public constant oracleEthToUsd_base = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address public constant oracleCbethToUsd_base = 0xd7818272B9e248357d13057AAb0B417aF31E817d;
    address public constant oracleUsdcToUsd_base = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address public constant oracleUsdbcToUsd_base = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address public constant oracleWbtcToUsd_base = 0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E;
    address public constant oracleRethToEth_base = 0xf397bF97280B488cA19ee3093E81C0a77F02e9a5;
    address public constant oracleStgToUsd_base = 0x63Af8341b62E683B87bB540896bF283D96B4D385;
    address public constant oracleWstethToEth_base = 0xa669E5272E60f78299F4824495cE01a3923f4380;
    address public constant oracleAeroToUsd_base = 0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0;

    address public constant aeroFactory = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address public constant aeroVoter = 0x16613524e02ad97eDfeF371bC883F2F5d6C480A5;
    address public constant sequencerUptimeOracle_base = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;
    address public constant slipstreamPositionMgr = 0x827922686190790b37229fd06084350E74485b72;
    address public constant stargateFactory_base = 0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6;
    address public constant stargateLpStakingTime_base = 0x06Eb48763f117c7Be887296CDcdfad2E4092739C;
    address public constant uniswapV3PositionMgr_base = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
}

library DeployNumbers {
    uint8 public constant wethDecimals = 18;
    uint8 public constant daiDecimals = 18;
    uint8 public constant compDecimals = 18;
    uint8 public constant usdcDecimals = 6;
    uint8 public constant usdbcDecimals = 6;
    uint8 public constant tbtcDecimals = 18;
    uint8 public constant crvusdDecimals = 18;
    uint8 public constant cbethDecimals = 18;
    uint8 public constant rethDecimals = 18;
    uint8 public constant sushiDecimals = 18;
    uint8 public constant axlusdcDecimals = 6;
    uint8 public constant axldaiDecimals = 18;
    uint8 public constant axlusdtDecimals = 6;
    uint8 public constant axlDecimals = 6;
    uint8 public constant crvDecimals = 18;
    uint8 public constant stgDecimals = 18;
    uint8 public constant wstethDecimals = 18;
    uint8 public constant aeroDecimals = 18;

    uint256 public constant stargateWethPoolId = 13;
    uint256 public constant stargateUsdbcPoolId = 1;
    uint256 public constant stargateUsdbcPid = 1;

    uint32 public constant comp_usd_cutOffTime = 25 hours;
    uint32 public constant dai_usd_cutOffTime = 25 hours;
    uint32 public constant eth_usd_cutOffTime = 1 hours;
    uint32 public constant usdc_usd_cutOffTime = 25 hours;
    uint32 public constant cbeth_usd_cutOffTime = 1 hours;
    uint32 public constant reth_eth_cutOffTime = 25 hours;
    uint32 public constant stg_usd_cutOffTime = 25 hours;
    uint32 public constant wsteth_eth_cutOffTime = 25 hours;
    uint32 public constant aero_usd_cutOffTime = 25 hours;

    uint80 public constant AeroToUsdOracleId = 8;
    uint80 public constant EthToUsdOracleId = 2;
}

library DeployBytes {
    bytes32 public constant upgradeRoot1To1 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;
}

library DeployRiskConstantsBase {
    uint16 public constant comp_collFact_eth = 7000;
    uint16 public constant comp_collFact_usdc = 6500;
    uint16 public constant comp_liqFact_eth = 7700;
    uint16 public constant comp_liqFact_usdc = 7200;
    uint112 public constant comp_exposure_eth = 0;
    uint112 public constant comp_exposure_usdc = 0;

    uint16 public constant dai_collFact_eth = 8100;
    uint16 public constant dai_collFact_usdc = 8300;
    uint16 public constant dai_liqFact_eth = 8600;
    uint16 public constant dai_liqFact_usdc = 8700;
    uint112 public constant dai_exposure_eth = uint112(500_000 * 10 ** DeployNumbers.daiDecimals);
    uint112 public constant dai_exposure_usdc = uint112(500_000 * 10 ** DeployNumbers.daiDecimals);

    uint16 public constant eth_collFact_eth = 9000;
    uint16 public constant eth_collFact_usdc = 8100;
    uint16 public constant eth_liqFact_eth = 9400;
    uint16 public constant eth_liqFact_usdc = 8500;
    uint112 public constant eth_exposure_eth = uint112(1000 * 10 ** DeployNumbers.wethDecimals);
    uint112 public constant eth_exposure_usdc = uint112(500 * 10 ** DeployNumbers.wethDecimals);

    uint16 public constant usdc_collFact_eth = 8600;
    uint16 public constant usdc_collFact_usdc = 9000;
    uint16 public constant usdc_liqFact_eth = 9200;
    uint16 public constant usdc_liqFact_usdc = 9400;
    uint112 public constant usdc_exposure_eth = uint112(800_000 * 10 ** DeployNumbers.usdcDecimals);
    uint112 public constant usdc_exposure_usdc = uint112(1_000_000 * 10 ** DeployNumbers.usdcDecimals);

    uint16 public constant usdbc_collFact_eth = 8600;
    uint16 public constant usdbc_collFact_usdc = 9000;
    uint16 public constant usdbc_liqFact_eth = 9200;
    uint16 public constant usdbc_liqFact_usdc = 9400;
    uint112 public constant usdbc_exposure_eth = uint112(750_000 * 10 ** DeployNumbers.usdbcDecimals);
    uint112 public constant usdbc_exposure_usdc = uint112(1_000_000 * 10 ** DeployNumbers.usdbcDecimals);

    uint16 public constant wbtc_collFact_eth = 7600;
    uint16 public constant wbtc_collFact_usdc = 8600;
    uint16 public constant wbtc_liqFact_eth = 8400;
    uint16 public constant wbtc_liqFact_usdc = 9400;
    uint112 public constant wbtc_exposure_eth = 0;
    uint112 public constant wbtc_exposure_usdc = 0;

    uint16 public constant cbeth_collFact_eth = 9100;
    uint16 public constant cbeth_collFact_usdc = 8100;
    uint16 public constant cbeth_liqFact_eth = 9500;
    uint16 public constant cbeth_liqFact_usdc = 9400;
    uint112 public constant cbeth_exposure_eth = uint112(400 * 10 ** DeployNumbers.cbethDecimals);
    uint112 public constant cbeth_exposure_usdc = uint112(300 * 10 ** DeployNumbers.cbethDecimals);

    uint16 public constant reth_collFact_eth = 8500;
    uint16 public constant reth_collFact_usdc = 8100;
    uint16 public constant reth_liqFact_eth = 9200;
    uint16 public constant reth_liqFact_usdc = 9400;
    uint112 public constant reth_exposure_eth = uint112(210 * 10 ** DeployNumbers.rethDecimals);
    uint112 public constant reth_exposure_usdc = uint112(200 * 10 ** DeployNumbers.rethDecimals);

    uint16 public constant sushi_collFact_eth = 7600;
    uint16 public constant sushi_collFact_usdc = 8600;
    uint16 public constant sushi_liqFact_eth = 8400;
    uint16 public constant sushi_liqFact_usdc = 9400;
    uint112 public constant sushi_exposure_eth = 0;
    uint112 public constant sushi_exposure_usdc = 0;

    uint16 public constant axlusdc_collFact_eth = 7600;
    uint16 public constant axlusdc_collFact_usdc = 8600;
    uint16 public constant axlusdc_liqFact_eth = 8400;
    uint16 public constant axlusdc_liqFact_usdc = 9400;
    uint112 public constant axlusdc_exposure_eth = 0;
    uint112 public constant axlusdc_exposure_usdc = 0;

    uint16 public constant axldai_collFact_eth = 7600;
    uint16 public constant axldai_collFact_usdc = 8600;
    uint16 public constant axldai_liqFact_eth = 8400;
    uint16 public constant axldai_liqFact_usdc = 9400;
    uint112 public constant axldai_exposure_eth = 0;
    uint112 public constant axldai_exposure_usdc = 0;

    uint16 public constant axlusdt_collFact_eth = 7600;
    uint16 public constant axlusdt_collFact_usdc = 8600;
    uint16 public constant axlusdt_liqFact_eth = 8400;
    uint16 public constant axlusdt_liqFact_usdc = 9400;
    uint112 public constant axlusdt_exposure_eth = 0;
    uint112 public constant axlusdt_exposure_usdc = 0;

    uint16 public constant axl_collFact_eth = 7600;
    uint16 public constant axl_collFact_usdc = 8600;
    uint16 public constant axl_liqFact_eth = 8400;
    uint16 public constant axl_liqFact_usdc = 9400;
    uint112 public constant axl_exposure_eth = 0;
    uint112 public constant axl_exposure_usdc = 0;

    uint16 public constant crv_collFact_eth = 5500;
    uint16 public constant crv_collFact_usdc = 5000;
    uint16 public constant crv_liqFact_eth = 7000;
    uint16 public constant crv_liqFact_usdc = 6500;
    uint112 public constant crv_exposure_eth = 0;
    uint112 public constant crv_exposure_usdc = 0;

    uint16 public constant tbtc_collFact_eth = 7600;
    uint16 public constant tbtc_collFact_usdc = 8600;
    uint16 public constant tbtc_liqFact_eth = 8400;
    uint16 public constant tbtc_liqFact_usdc = 9400;
    uint112 public constant tbtc_exposure_eth = 0;
    uint112 public constant tbtc_exposure_usdc = 0;

    uint16 public constant crvusd_collFact_eth = 7600;
    uint16 public constant crvusd_collFact_usdc = 8600;
    uint16 public constant crvusd_liqFact_eth = 8400;
    uint16 public constant crvusd_liqFact_usdc = 9400;
    uint112 public constant crvusd_exposure_eth = 0;
    uint112 public constant crvusd_exposure_usdc = 0;

    uint16 public constant stg_collFact_eth = 6000;
    uint16 public constant stg_collFact_usdc = 5500;
    uint16 public constant stg_liqFact_eth = 7200;
    uint16 public constant stg_liqFact_usdc = 7000;
    uint112 public constant stg_exposure_eth = 1; // Cannot be deposited as primary asset, but still as yield source
    uint112 public constant stg_exposure_usdc = 1; // Cannot be deposited as primary asset, but still as yield source

    uint16 public constant wsteth_collFact_eth = 9100;
    uint16 public constant wsteth_collFact_usdc = 8100;
    uint16 public constant wsteth_liqFact_eth = 9500;
    uint16 public constant wsteth_liqFact_usdc = 9400;
    uint112 public constant wsteth_exposure_eth = uint112(400 * 10 ** DeployNumbers.wstethDecimals);
    uint112 public constant wsteth_exposure_usdc = uint112(300 * 10 ** DeployNumbers.wstethDecimals);

    uint16 public constant aero_collFact_eth = 0;
    uint16 public constant aero_collFact_usdc = 0;
    uint16 public constant aero_liqFact_eth = 0;
    uint16 public constant aero_liqFact_usdc = 0;
    uint112 public constant aero_exposure_eth = 1; // Cannot be deposited as primary asset, but still as yield source
    uint112 public constant aero_exposure_usdc = 1; // Cannot be deposited as primary asset, but still as yield source

    uint16 public constant aerodromePoolAM_riskFact_eth = 0;
    uint16 public constant aerodromePoolAM_riskFact_usdc = 0;
    uint112 public constant aerodromePoolAM_exposure_eth = uint112(0);
    uint112 public constant aerodromePoolAM_exposure_usdc = uint112(0);

    uint16 public constant stakedAerodromeAM_riskFact_eth = 0;
    uint16 public constant stakedAerodromeAM_riskFact_usdc = 0;
    uint112 public constant stakedAerodromeAM_exposure_eth = uint112(0);
    uint112 public constant stakedAerodromeAM_exposure_usdc = uint112(0);

    uint16 public constant wrappedAerodromeAM_riskFact_eth = 0;
    uint16 public constant wrappedAerodromeAM_riskFact_usdc = 0;
    uint112 public constant wrappedAerodromeAM_exposure_eth = uint112(0);
    uint112 public constant wrappedAerodromeAM_exposure_usdc = uint112(0);

    uint16 public constant stakedStargateAM_riskFact_eth = 9800;
    uint16 public constant stakedStargateAM_riskFact_usdc = 9800;
    uint112 public constant stakedStargateAM_exposure_eth = uint112(250_000 * 1e18);
    uint112 public constant stakedStargateAM_exposure_usdc = uint112(250_000 * 1e18);

    uint16 public constant stargateAM_riskFact_eth = 9700;
    uint16 public constant stargateAM_riskFact_usdc = 9700;
    uint112 public constant stargateAM_exposure_eth = uint112(250_000 * 1e18);
    uint112 public constant stargateAM_exposure_usdc = uint112(250_000 * 1e18);

    uint16 public constant uniswapV3AM_riskFact_eth = 9800;
    uint16 public constant uniswapV3AM_riskFact_usdc = 9800;
    uint112 public constant uniswapV3AM_exposure_eth = uint112(2_000_000 * 1e18);
    uint112 public constant uniswapV3AM_exposure_usdc = uint112(2_000_000 * 1e18);

    uint16 public constant slipstreamAM_riskFact_eth = 9800;
    uint16 public constant slipstreamAM_riskFact_usdc = 9800;
    uint112 public constant slipstreamAM_exposure_eth = uint112(2_000_000 * 1e18);
    uint112 public constant slipstreamAM_exposure_usdc = uint112(2_000_000 * 1e18);

    uint128 public constant minUsdValue_eth = 1 * 1e18; // 1 USD?
    uint64 public constant gracePeriod_eth = 15 minutes;
    uint64 public constant maxRecursiveCalls_eth = 5;

    uint128 public constant minUsdValue_usdc = 1 * 1e18; // 1 USD?
    uint64 public constant gracePeriod_usdc = 15 minutes;
    uint64 public constant maxRecursiveCalls_usdc = 5;
}

library ArcadiaContracts {
    address public constant aerodromePoolAM = address(0);
    address public constant chainlinkOM = address(0x6a5485E3ce6913890ae5e8bDc08a868D432eEB31);
    address public constant erc20PrimaryAM = address(0xfBecEaFC96ed6fc800753d3eE6782b6F9a60Eed7);
    address public constant factory = address(0xDa14Fdd72345c4d2511357214c5B89A919768e59);
    address public constant registry = address(0xd0690557600eb8Be8391D1d97346e2aab5300d5f);
    address public constant slipstreamAM = address(0);
    address public constant stakedAerodromeAM = address(0);
    address public constant stakedStargateAM = address(0xae909e19fd13C01c28d5Ee439D403920CF7f9Eea);
    address public constant stargateAM = address(0x20f7903290bF98716B62Dc1c9DA634291b8cfeD4);
    address public constant uniswapV3AM = address(0x21bd524cC54CA78A7c48254d4676184f781667dC);
    address public constant usdcLendingPool = address(0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1);
    address public constant wethLendingPool = address(0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2);
    address public constant wrappedAerodromeAM = address(0);
}

library ArcadiaSafes {
    address public constant owner = address(0xb4d72B1c91e640e4ED7d7397F3244De4D8ACc50B);
    address public constant guardian = address(0xEdD41f9740b06eCBfe1CE9194Ce2715C28263187);
    address public constant riskManager = address(0xD5FA6C6e284007743d4263255385eDA78dDa268c);
}

library AerodromePools {
    address public constant vAeroUsdbcPool = address(0x2223F9FE624F69Da4D8256A7bCc9104FBA7F8f75);
    address public constant vAeroWstethPool = address(0x82a0c1a0d4EF0c0cA3cFDA3AD1AA78309Cc6139b);
    address public constant vCbethWethPool = address(0x44Ecc644449fC3a9858d2007CaA8CFAa4C561f91);
    address public constant vUsdcAeroPool = address(0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAFb971d);
    address public constant vWethAeroPool = address(0x7f670f78B17dEC44d5Ef68a48740b6f8849cc2e6);
    address public constant vWethUsdcPool = address(0xcDAC0d6c6C59727a65F871236188350531885C43);
    address public constant vWethUsdbcPool = address(0xB4885Bc63399BF5518b994c1d0C153334Ee579D0);
    address public constant vWethWstethPool = address(0xA6385c73961dd9C58db2EF0c4EB98cE4B60651e8);
    address public constant sUsdcUsdbcPool = address(0x27a8Afa3Bd49406e48a074350fB7b2020c43B2bD);

    address public constant vAeroUsdbcGauge = address(0x9a202c932453fB3d04003979B121E80e5A14eE7b);
    address public constant vAeroWstethGauge = address(0x26D6D4E9e3fAf1C7C19992B1Ca792e4A9ea4F833);
    address public constant vCbethWethGauge = address(0xDf9D427711CCE46b52fEB6B2a20e4aEaeA12B2b7);
    address public constant vUsdcAeroGauge = address(0x4F09bAb2f0E15e2A078A227FE1537665F55b8360);
    address public constant vWethAeroGauge = address(0x96a24aB830D4ec8b1F6f04Ceac104F1A3b211a01);
    address public constant vWethUsdcGauge = address(0x519BBD1Dd8C6A94C46080E24f316c14Ee758C025);
    address public constant vWethUsdbcGauge = address(0xeca7Ff920E7162334634c721133F3183B83B0323);
    address public constant vWethWstethGauge = address(0xDf7c8F17Ab7D47702A4a4b6D951d2A4c90F99bf4);
    address public constant sUsdcUsdbcGauge = address(0x1Cfc45C5221A07DA0DE958098A319a29FbBD66fE);
}
