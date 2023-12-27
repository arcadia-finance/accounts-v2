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

    address public constant oracleCompToUsd_base = 0x9DDa783DE64A9d1A60c49ca761EbE528C35BA428;
    address public constant oracleDaiToUsd_base = 0x591e79239a7d679378eC8c847e5038150364C78F;
    address public constant oracleEthToUsd_base = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address public constant oracleUsdcToUsd_base = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    address public constant oracleWbtcToUsd_base = 0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E;
    address public constant oracleCbethToEth_base = 0x868a501e68F3D1E89CfC0D22F6b22E8dabce5F04;
    address public constant oracleRethToEth_base = 0xf397bF97280B488cA19ee3093E81C0a77F02e9a5;

    address public constant uniswapV3PositionMgr_base = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;

    address public constant sequencerUptimeOracle_base = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;

    // to do: change to gnosis
    address public constant treasury_base = 0xBEB56fbEf3387af554A554E7DB25830eB7b92e32;
}

library DeployNumbers {
    uint256 public constant oracleCompToUsdUnit = 1e8;
    uint256 public constant oracleDaiToUsdUnit = 1e8;
    uint256 public constant oracleEthToUsdUnit = 1e8;
    uint256 public constant oracleUsdcToUsdUnit = 1e8;
    uint256 public constant oracleWbtcToUsdUnit = 1e8;
    uint256 public constant oracleCbethToEthUnit = 1e18;
    uint256 public constant oracleRethToEthUnit = 1e18;

    uint256 public constant wethDecimals = 18;
    uint256 public constant daiDecimals = 18;
    uint256 public constant compDecimals = 18;
    uint256 public constant usdcDecimals = 6;
    uint256 public constant usdbcDecimals = 6;
    uint256 public constant tbtcDecimals = 18;
    uint256 public constant crvusdDecimals = 18;
    uint256 public constant cbethDecimals = 18;
    uint256 public constant rethDecimals = 18;
    uint256 public constant sushiDecimals = 18;
    uint256 public constant axlusdcDecimals = 6;
    uint256 public constant axldaiDecimals = 18;
    uint256 public constant axlusdtDecimals = 6;
    uint256 public constant axlDecimals = 6;
    uint256 public constant crvDecimals = 18;
}

library DeployBytes {
    bytes32 public constant upgradeRoot1To1 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;
}

library DeployRiskConstantsBase {
    uint16 public constant comp_collFact_1 = 7000; //eth
    uint16 public constant comp_collFact_2 = 6500; //usdc
    uint16 public constant comp_liqFact_1 = 7700; //eth
    uint16 public constant comp_liqFact_2 = 7200; //usdc

    uint16 public constant dai_collFact_1 = 8000; //eth
    uint16 public constant dai_collFact_2 = 8800; //usdc
    uint16 public constant dai_liqFact_1 = 8500; //eth
    uint16 public constant dai_liqFact_2 = 9200; //usdc

    uint16 public constant eth_collFact_1 = 9000; //eth
    uint16 public constant eth_collFact_2 = 8000; //usdc
    uint16 public constant eth_liqFact_1 = 9400; //eth
    uint16 public constant eth_liqFact_2 = 8500; //usdc

    uint16 public constant usdc_collFact_1 = 8000; //eth
    uint16 public constant usdc_collFact_2 = 9000; //usdc
    uint16 public constant usdc_liqFact_1 = 8500; //eth
    uint16 public constant usdc_liqFact_2 = 9400; //usdc

    uint16 public constant wbtc_collFact_1 = 7600; //eth
    uint16 public constant wbtc_collFact_2 = 8600; //usdc
    uint16 public constant wbtc_liqFact_1 = 8400; //eth
    uint16 public constant wbtc_liqFact_2 = 9400; //usdc

    uint16 public constant cbeth_collFact_1 = 8500; //eth
    uint16 public constant cbeth_collFact_2 = 7500; //usdc
    uint16 public constant cbeth_liqFact_1 = 9200; //eth
    uint16 public constant cbeth_liqFact_2 = 8200; //usdc

    uint16 public constant reth_collFact_1 = 8500; //eth
    uint16 public constant reth_collFact_2 = 7500; //usdc
    uint16 public constant reth_liqFact_1 = 9200; //eth
    uint16 public constant reth_liqFact_2 = 8200; //usdc

    uint16 public constant sushi_collFact_1 = 7600; //eth
    uint16 public constant sushi_collFact_2 = 8600; //usdc
    uint16 public constant sushi_liqFact_1 = 8400; //eth
    uint16 public constant sushi_liqFact_2 = 9400; //usdc

    uint16 public constant axlusdc_collFact_1 = 7600; //eth
    uint16 public constant axlusdc_collFact_2 = 8600; //usdc
    uint16 public constant axlusdc_liqFact_1 = 8400; //eth
    uint16 public constant axlusdc_liqFact_2 = 9400; //usdc

    uint16 public constant axldai_collFact_1 = 7600; //eth
    uint16 public constant axldai_collFact_2 = 8600; //usdc
    uint16 public constant axldai_liqFact_1 = 8400; //eth
    uint16 public constant axldai_liqFact_2 = 9400; //usdc

    uint16 public constant axlusdt_collFact_1 = 7600; //eth
    uint16 public constant axlusdt_collFact_2 = 8600; //usdc
    uint16 public constant axlusdt_liqFact_1 = 8400; //eth
    uint16 public constant axlusdt_liqFact_2 = 9400; //usdc

    uint16 public constant axl_collFact_1 = 7600; //eth
    uint16 public constant axl_collFact_2 = 8600; //usdc
    uint16 public constant axl_liqFact_1 = 8400; //eth
    uint16 public constant axl_liqFact_2 = 9400; //usdc

    uint16 public constant crv_collFact_1 = 7600; //eth
    uint16 public constant crv_collFact_2 = 8600; //usdc
    uint16 public constant crv_liqFact_1 = 8400; //eth
    uint16 public constant crv_liqFact_2 = 9400; //usdc

    uint16 public constant tbtc_collFact_1 = 7600; //eth
    uint16 public constant tbtc_collFact_2 = 8600; //usdc
    uint16 public constant tbtc_liqFact_1 = 8400; //eth
    uint16 public constant tbtc_liqFact_2 = 9400; //usdc

    uint16 public constant usdbc_collFact_1 = 7600; //eth
    uint16 public constant usdbc_collFact_2 = 8600; //usdc
    uint16 public constant usdbc_liqFact_1 = 8400; //eth
    uint16 public constant usdbc_liqFact_2 = 9400; //usdc

    uint16 public constant crvusd_collFact_1 = 7600; //eth
    uint16 public constant crvusd_collFact_2 = 8600; //usdc
    uint16 public constant crvusd_liqFact_1 = 8400; //eth
    uint16 public constant crvusd_liqFact_2 = 9400; //usdc
}
