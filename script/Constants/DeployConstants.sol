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

    address public constant oracleCompToUsd_base = 0x9DDa783DE64A9d1A60c49ca761EbE528C35BA428;
    address public constant oracleDaiToUsd_base = 0x591e79239a7d679378eC8c847e5038150364C78F;
    address public constant oracleEthToUsd_base = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address public constant oracleCbethToUsd_base = 0xd7818272B9e248357d13057AAb0B417aF31E817d;
    address public constant oracleUsdcToUsd_base = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address public constant oracleUsdbcToUsd_base = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address public constant oracleWbtcToUsd_base = 0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E;
    address public constant oracleRethToEth_base = 0xf397bF97280B488cA19ee3093E81C0a77F02e9a5;
    address public constant oracleStgToUsd_base = 0x63Af8341b62E683B87bB540896bF283D96B4D385;

    address public constant uniswapV3PositionMgr_base = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address public constant stargateFactory_base = 0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6;
    address public constant stargateLpStakingTime_base = 0x06Eb48763f117c7Be887296CDcdfad2E4092739C;
    address public constant sequencerUptimeOracle_base = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;

    // to do: change to gnosis
    address public constant protocolOwner_base = 0x0f518becFC14125F23b8422849f6393D59627ddB;
    address public constant pauseGuardian_base = 0x0106BBB9a3AAf4ec5fEbC6A1A90A2C2FEacb1087;
    address public constant riskManager_base = 0x829bc2A98f1D0AFA4C487894a329CF372Ca3337C;
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

    uint16 public constant uniswapV3AM_riskFact_eth = 9800;
    uint16 public constant uniswapV3AM_riskFact_usdc = 9800;
    uint112 public constant uniswapV3AM_exposure_eth = uint112(2_000_000 * 1e18);
    uint112 public constant uniswapV3AM_exposure_usdc = uint112(2_000_000 * 1e18);

    uint16 public constant stargateAM_riskFact_eth = 9700;
    uint16 public constant stargateAM_riskFact_usdc = 9700;
    uint112 public constant stargateAM_exposure_eth = uint112(250_000 * 1e18);
    uint112 public constant stargateAM_exposure_usdc = uint112(250_000 * 1e18);

    uint16 public constant stakedStargateAM_riskFact_eth = 9800;
    uint16 public constant stakedStargateAM_riskFact_usdc = 9800;
    uint112 public constant stakedStargateAM_exposure_eth = uint112(250_000 * 1e18);
    uint112 public constant stakedStargateAM_exposure_usdc = uint112(250_000 * 1e18);

    uint128 public constant minUsdValue_eth = 1 * 1e18; // 1 USD?
    uint64 public constant gracePeriod_eth = 15 minutes;
    uint64 public constant maxRecursiveCalls_eth = 5;

    uint128 public constant minUsdValue_usdc = 1 * 1e18; // 1 USD?
    uint64 public constant gracePeriod_usdc = 15 minutes;
    uint64 public constant maxRecursiveCalls_usdc = 5;
}
