/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Asset, Oracle } from "./Shared.sol";

library AerodromeGauges {
    address internal constant CL1_CBBTC_LBTC = 0xc3f97660D0b47F0E05C3c513f73eeff7c1bd6c7a;
    address internal constant CL1_CBETH_WETH = 0xF5550F8F0331B8CAA165046667f4E6628E9E3Aac;
    address internal constant CL1_EURC_USDC = 0x85af8D930cB738954d307D6E62F04dd05D839C37;
    address internal constant CL1_EZETH_WETH = 0xC6B4fe83Fb284bDdE1f1d19F0B5beB31011B280A;
    address internal constant CL1_TBTC_CBBTC = 0xB57eC27f68Bd356e300D57079B6cdbe57d50830d;
    address internal constant CL1_USDC_USDBC = 0x4a3E1294d7869567B387FC3d5e5Ccf14BE2Bbe0a;
    address internal constant CL1_USDC_USDT = 0xBd85D45f1636fCEB2359d9Dcf839f12b3cF5AF3F;
    address internal constant CL1_USDS_USDC = 0xe2a2B1D8AA4bD8A05e517Ccf61E96A727831B63e;
    address internal constant CL1_USDZ_USDC = 0xE2F3C8c699A1bf30A12118B287B5208e7C6ddFEF;
    address internal constant CL1_WEETH_WETH = 0xfCfEE5f453728BaA5ffDA151f25A0e53B8C5A01C;
    address internal constant CL1_WETH_WRSETH = 0xEc33F9cbE64c7Bc9b262Efaaa56b7872e8889AaE;
    address internal constant CL1_WETH_WSTETH = 0x2A1f7bf46bd975b5004b61c6040597E1B6117040;
    address internal constant CL1_WSTETH_WRSETH = 0x4197186D3D65f694018Ae4B80355225Ce1dD64AD;
    address internal constant CL50_EURC_USDC = 0x1f6c9d116CE22b51b0BC666f86B038a6c19900B8;
    address internal constant CL100_EURC_CBBTC = 0x017a82B26d612cAD89d240206F652E76ae8C4B31;
    address internal constant CL100_USDC_CBBTC = 0x6399ed6725cC163D019aA64FF55b22149D7179A8;
    address internal constant CL100_USDC_TRUMP = 0x0c1D14b66e74FBB35d53A0c97Dbe93fa8a97BbE7;
    address internal constant CL100_USDZ_CBBTC = 0x384Ce87727323eDeDdc95D3206399806A3da7F02;
    address internal constant CL100_USDZ_WETH = 0x549690894f61bf0D3a5799D03fDED6e775A424aA;
    address internal constant CL100_VIRTUAL_WETH = 0x5013Ea8783Bfeaa8c4850a54eacd54D7A3B7f889;
    address internal constant CL100_WETH_CBBTC = 0x41b2126661C673C2beDd208cC72E85DC51a5320a;
    address internal constant CL100_WETH_EURC = 0xb0C500d53720ff63F000de6D26f7Fe5c66571e3d;
    address internal constant CL100_WETH_USDC = 0xF33a96b5932D9E9B9A0eDA447AbD8C9d48d2e0c8;
    address internal constant CL100_WETH_USDT = 0x2c0CbF25Bb64687d11ea2E4a3dc893D56Ca39c10;
    address internal constant CL100_WETH_VVV = 0x5d05eF25a5f933271E1f0FDc02dC3EaB6a4eA687;
    address internal constant CL200_AERO_WSTETH = 0x45F8b8eC9c92D09BA8495074436fD97073423041;
    address internal constant CL200_AERO_CBBTC = 0x2B74B62c564456C48055bd515A62594742b3f545;
    address internal constant CL200_TBTC_WETH = 0x996802075582Af2eE133fb30Cc5A9E8A671d3c3a;
    address internal constant CL200_TBTC_USDC = 0x37E1a626b09faDE99E94752942a88f17EA2170fd;
    address internal constant CL200_USDZ_DEGEN = 0x9918C85E4e5937DA606d65C9935Ea3ffe4DE06A4;
    address internal constant CL200_VIRTUAL_WETH = 0xBDA319Bc7Cc8F0829df39eC0FFF5D1E061FFadf7;
    address internal constant CL200_WETH_AAVE = 0x28047b764D603A25146A0b8a8D414740dC1E650E;
    address internal constant CL200_WETH_AERO = 0xdE8FF0D3e8ab225110B088a250b546015C567E27;
    address internal constant CL200_WETH_DEGEN = 0x319e23D38d8ee58783Ff5331507b808709bd00b0;
    address internal constant CL200_WETH_MORPHO = 0xf008577BfbB3B8EAAaC22C1933C9a8cd876fCFd2;
    address internal constant CL200_WETH_VVV = 0x6831125a82Af7417e0cde3A214c03fE248Ff6AA8;
    address internal constant CL200_WETH_WELL = 0xe871A267A418C200F8b92Ae21397221122B79808;
    address internal constant CL200_WETH_RDNT = 0x8D88C541f22de965536bD1849013caEE6ce90e11;
    address internal constant CL2000_USDC_AERO = 0x430C09546ae9249AB75B9A4ef7B5FD9a4006D6f3;
    address internal constant S_EZETH_WETH = 0x4Fa58b3Bec8cE12014c7775a0B3da7e6AdC3c7eA;
    address internal constant S_USDC_USDBC = 0x1Cfc45C5221A07DA0DE958098A319a29FbBD66fE;
    address internal constant S_USDZ_USDC = 0xb7E4bBee04285F4B55d0A93b34E5dA95C3a7faf9;
    address internal constant V_AERO_USDBC = 0x9a202c932453fB3d04003979B121E80e5A14eE7b;
    address internal constant V_AERO_WELL = 0x57c198edE5e375a273935f5ED8B4D22fE836f080;
    address internal constant V_AERO_WSTETH = 0x26D6D4E9e3fAf1C7C19992B1Ca792e4A9ea4F833;
    address internal constant V_CBETH_WETH = 0xDf9D427711CCE46b52fEB6B2a20e4aEaeA12B2b7;
    address internal constant V_EURC_USDC = 0x1f077baf21b95314bD251b21aD1f0Cc8D5D86781;
    address internal constant V_EZETH_WETH = 0x6318373c5a01224094BF0B1AC88562345B2Fb91E;
    address internal constant V_USDC_AERO = 0x4F09bAb2f0E15e2A078A227FE1537665F55b8360;
    address internal constant V_USDZ_WETH = 0xc15B32d92E265832c87EC4b36B7e598ae2daad42;
    address internal constant V_VIRTUAL_AERO = 0x57538a02972c01440113cC7A7Ff8F1d954d01239;
    address internal constant V_VIRTUAL_CBBTC = 0x8c44e7F913D0893Cd5A3CBBb2fCd59785a7801ab;
    address internal constant V_VIRTUAL_WETH = 0xBD62Cad65b49b4Ad9C7aa9b8bDB89d63221F7af5;
    address internal constant V_WEETH_AERO = 0x0A5f63A1aC754b4418cc5381eE17E04CCad42F56;
    address internal constant V_WEETH_WETH = 0xf8d47b641eD9DF1c924C0F7A6deEEA2803b9CfeF;
    address internal constant V_WETH_AERO = 0x96a24aB830D4ec8b1F6f04Ceac104F1A3b211a01;
    address internal constant V_WETH_DEGEN = 0x86A1260AB9f758026Ce1a5830BdfF66DBcF736d5;
    address internal constant V_WETH_EURC = 0x21D4eF9D2b66069f3307765A0349526f8E988294;
    address internal constant V_WETH_USDBC = 0xeca7Ff920E7162334634c721133F3183B83B0323;
    address internal constant V_WETH_USDC = 0x519BBD1Dd8C6A94C46080E24f316c14Ee758C025;
    address internal constant V_WETH_VVV = 0x37a70295FCefebBB0a29735A53E2e6786A02F930;
    address internal constant V_WETH_WELL = 0x7b6964440b615aC1d31bc95681B133E112fB2684;
    address internal constant V_WETH_WRSETH = 0x2da7789a6371F550caF9054694F5A5A6682903f9;
    address internal constant V_WETH_WSTETH = 0xDf7c8F17Ab7D47702A4a4b6D951d2A4c90F99bf4;
}

library AerodromePools {
    address internal constant S_EZETH_WETH = 0x497139e8435E01555AC1e3740fccab7AFf149e02;
    address internal constant S_USDC_USDBC = 0x27a8Afa3Bd49406e48a074350fB7b2020c43B2bD;
    address internal constant S_USDZ_USDC = 0x6d0b9C9E92a3De30081563c3657B5258b3fFa38B;
    address internal constant V_AERO_USDBC = 0x2223F9FE624F69Da4D8256A7bCc9104FBA7F8f75;
    address internal constant V_AERO_WELL = 0xCd401DE1cBAa0d770eE5FB70ff622c752C92B8c5;
    address internal constant V_AERO_WSTETH = 0x82a0c1a0d4EF0c0cA3cFDA3AD1AA78309Cc6139b;
    address internal constant V_CBETH_WETH = 0x44Ecc644449fC3a9858d2007CaA8CFAa4C561f91;
    address internal constant V_EURC_USDC = 0xFDF5139b38525627B47538536042A7c8d2686BD9;
    address internal constant V_EZETH_WETH = 0x0C8bF3cb3E1f951B284EF14aa95444be86a33E2f;
    address internal constant V_USDC_AERO = 0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAFb971d;
    address internal constant V_USDZ_WETH = 0x2ce63497999F520CC2afaaadbCFC37Afd9deF4b0;
    address internal constant V_VIRTUAL_AERO = 0x8B49c7eC53Cb4CA3666bB16727FC5C5F6d12226f;
    address internal constant V_VIRTUAL_CBBTC = 0xb909F567c5c2Bb1A4271349708CC4637D7318b4A;
    address internal constant V_VIRTUAL_WETH = 0x21594b992F68495dD28d605834b58889d0a727c7;
    address internal constant V_WEETH_AERO = 0xc5aDfb267a95df1233a2b5F7f48041E7Fb384BcA;
    address internal constant V_WEETH_WETH = 0x91F0f34916Ca4E2cCe120116774b0e4fA0cdcaA8;
    address internal constant V_WETH_AERO = 0x7f670f78B17dEC44d5Ef68a48740b6f8849cc2e6;
    address internal constant V_WETH_DEGEN = 0x2C4909355b0C036840819484c3A882A95659aBf3;
    address internal constant V_WETH_EURC = 0x9DFf4b5AE4fD673213502Ab8fbf6d36015efb3E1;
    address internal constant V_WETH_USDBC = 0xB4885Bc63399BF5518b994c1d0C153334Ee579D0;
    address internal constant V_WETH_USDC = 0xcDAC0d6c6C59727a65F871236188350531885C43;
    address internal constant V_WETH_VVV = 0x01784ef301D79e4B2DF3a21ad9a536d4cF09A5Ce;
    address internal constant V_WETH_WELL = 0x89D0F320ac73dd7d9513FFC5bc58D1161452a657;
    address internal constant V_WETH_WRSETH = 0xA24382874A6FD59de45BbccFa160488647514c28;
    address internal constant V_WETH_WSTETH = 0xA6385c73961dd9C58db2EF0c4EB98cE4B60651e8;
}

library Assets {
    function AAVE() internal pure returns (Asset memory) {
        return Asset({ asset: 0x63706e401c06ac8513145b7687A14804d17f814b, decimals: 18 });
    }

    function AERO() internal pure returns (Asset memory) {
        return Asset({ asset: 0x940181a94A35A4569E4529A3CDfB74e38FD98631, decimals: 18 });
    }

    function CBBTC() internal pure returns (Asset memory) {
        return Asset({ asset: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf, decimals: 8 });
    }

    function CBETH() internal pure returns (Asset memory) {
        return Asset({ asset: 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22, decimals: 18 });
    }

    function COMP() internal pure returns (Asset memory) {
        return Asset({ asset: 0x9e1028F5F1D5eDE59748FFceE5532509976840E0, decimals: 18 });
    }

    function DAI() internal pure returns (Asset memory) {
        return Asset({ asset: 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb, decimals: 18 });
    }

    function DEGEN() internal pure returns (Asset memory) {
        return Asset({ asset: 0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed, decimals: 18 });
    }

    function EURC() internal pure returns (Asset memory) {
        return Asset({ asset: 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42, decimals: 6 });
    }

    function EZETH() internal pure returns (Asset memory) {
        return Asset({ asset: 0x2416092f143378750bb29b79eD961ab195CcEea5, decimals: 18 });
    }

    function GHO() internal pure returns (Asset memory) {
        return Asset({ asset: 0x6Bb7a212910682DCFdbd5BCBb3e28FB4E8da10Ee, decimals: 18 });
    }

    function LBTC() internal pure returns (Asset memory) {
        return Asset({ asset: 0xecAc9C5F704e954931349Da37F60E39f515c11c1, decimals: 8 });
    }

    function MORPHO() internal pure returns (Asset memory) {
        return Asset({ asset: 0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842, decimals: 18 });
    }

    function RDNT() internal pure returns (Asset memory) {
        return Asset({ asset: 0xd722E55C1d9D9fA0021A5215Cbb904b92B3dC5d4, decimals: 18 });
    }

    function RETH() internal pure returns (Asset memory) {
        return Asset({ asset: 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c, decimals: 18 });
    }

    function STG() internal pure returns (Asset memory) {
        return Asset({ asset: 0xE3B53AF74a4BF62Ae5511055290838050bf764Df, decimals: 18 });
    }

    function TBTC() internal pure returns (Asset memory) {
        return Asset({ asset: 0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b, decimals: 18 });
    }

    function TRUMP() internal pure returns (Asset memory) {
        return Asset({ asset: 0xc27468b12ffA6d714B1b5fBC87eF403F38b82AD4, decimals: 18 });
    }

    function USDBC() internal pure returns (Asset memory) {
        return Asset({ asset: 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA, decimals: 6 });
    }

    function USDC() internal pure returns (Asset memory) {
        return Asset({ asset: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, decimals: 6 });
    }

    function USDS() internal pure returns (Asset memory) {
        return Asset({ asset: 0x820C137fa70C8691f0e44Dc420a5e53c168921Dc, decimals: 18 });
    }

    function USDT() internal pure returns (Asset memory) {
        return Asset({ asset: 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2, decimals: 6 });
    }

    function USDZ() internal pure returns (Asset memory) {
        return Asset({ asset: 0x04D5ddf5f3a8939889F11E97f8c4BB48317F1938, decimals: 18 });
    }

    function VIRTUAL() internal pure returns (Asset memory) {
        return Asset({ asset: 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b, decimals: 18 });
    }

    function VVV() internal pure returns (Asset memory) {
        return Asset({ asset: 0xacfE6019Ed1A7Dc6f7B508C02d1b04ec88cC21bf, decimals: 18 });
    }

    function WEETH() internal pure returns (Asset memory) {
        return Asset({ asset: 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A, decimals: 18 });
    }

    function WELL() internal pure returns (Asset memory) {
        return Asset({ asset: 0xA88594D404727625A9437C3f886C7643872296AE, decimals: 18 });
    }

    function WETH() internal pure returns (Asset memory) {
        return Asset({ asset: 0x4200000000000000000000000000000000000006, decimals: 18 });
    }

    function WRSETH() internal pure returns (Asset memory) {
        return Asset({ asset: 0xEDfa23602D0EC14714057867A78d01e94176BEA0, decimals: 18 });
    }

    function WSTETH() internal pure returns (Asset memory) {
        return Asset({ asset: 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452, decimals: 18 });
    }
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

library MerkleRoots {
    bytes32 internal constant V1 = 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f;
    bytes32 internal constant V2 = 0xad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5;
}

library Oracles {
    function AAVE_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x3d6774EF702A10b20FCa8Ed40FC022f7E4938e07,
            baseAsset: "AAVE",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 23
        });
    }

    function AERO_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0,
            baseAsset: "AERO",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 8
        });
    }

    function CBBTC_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x07DA0E54543a844a80ABE69c8A12F22B3aA59f9D,
            baseAsset: "CBBTC",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 15
        });
    }

    function CBETH_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xd7818272B9e248357d13057AAb0B417aF31E817d,
            baseAsset: "CBETH",
            quoteAsset: "USD",
            cutOffTime: 1 hours,
            id: 4
        });
    }

    function COMP_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x9DDa783DE64A9d1A60c49ca761EbE528C35BA428,
            baseAsset: "COMP",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 0
        });
    }

    function DAI_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x591e79239a7d679378eC8c847e5038150364C78F,
            baseAsset: "DAI",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 1
        });
    }

    function DEGEN_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xE62BcE5D7CB9d16AB8b4D622538bc0A50A5799c2,
            baseAsset: "DEGEN",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 9
        });
    }

    function ETH_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70,
            baseAsset: "ETH",
            quoteAsset: "USD",
            cutOffTime: 1 hours,
            id: 2
        });
    }

    function EURC_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xDAe398520e2B67cd3f27aeF9Cf14D93D927f8250,
            baseAsset: "EURC",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 16
        });
    }

    function EZETH_ETH() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x960BDD1dFD20d7c98fa482D793C3dedD73A113a3,
            baseAsset: "EZETH",
            quoteAsset: "ETH",
            cutOffTime: 25 hours,
            id: 10
        });
    }

    function GHO_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x42868EFcee13C0E71af89c04fF7d96f5bec479b0,
            baseAsset: "GHO",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 24
        });
    }

    function LBTC_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x9e07546c9Fe8868855CD04B26051a26D1599E270,
            baseAsset: "LBTC",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 22
        });
    }

    function MORPHO_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xe95e258bb6615d47515Fc849f8542dA651f12bF6,
            baseAsset: "MORPHO",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 25
        });
    }

    function RDNT_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xEf2E24ba6def99B5e0b71F6CDeaF294b02163094,
            baseAsset: "RDNT",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 13
        });
    }

    function RETH_ETH() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xf397bF97280B488cA19ee3093E81C0a77F02e9a5,
            baseAsset: "RETH",
            quoteAsset: "ETH",
            cutOffTime: 25 hours,
            id: 5
        });
    }

    function STG_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x63Af8341b62E683B87bB540896bF283D96B4D385,
            baseAsset: "STG",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 6
        });
    }

    function TBTC_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x6D75BFB5A5885f841b132198C9f0bE8c872057BF,
            baseAsset: "TBTC",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 14
        });
    }

    function TRUMP_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x7bAfa1Af54f17cC0775a1Cf813B9fF5dED2C51E5,
            baseAsset: "TRUMP",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 20
        });
    }

    function USDC_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B,
            baseAsset: "USDC",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 3
        });
    }

    function USDS_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x2330aaE3bca5F05169d5f4597964D44522F62930,
            baseAsset: "USDS",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 19
        });
    }

    function USDT_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xf19d560eB8d2ADf07BD6D13ed03e1D11215721F9,
            baseAsset: "USDT",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 12
        });
    }

    function USDZ_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xe25969e2Fa633a0C027fAB8F30Fc9C6A90D60B48,
            baseAsset: "USDZ",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 17
        });
    }

    function VIRTUAL_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xEaf310161c9eF7c813A14f8FEF6Fb271434019F7,
            baseAsset: "VIRTUAL",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 21
        });
    }

    function VVV_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0x8eC6a128a430f7A850165bcF18facc9520a9873F,
            baseAsset: "VVV",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 27
        });
    }

    function WEETH_ETH() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xFC1415403EbB0c693f9a7844b92aD2Ff24775C65,
            baseAsset: "WEETH",
            quoteAsset: "ETH",
            id: 11,
            cutOffTime: 25 hours
        });
    }

    function WELL_USD() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xc15d9944dAefE2dB03e53bef8DDA25a56832C5fe,
            baseAsset: "WELL",
            quoteAsset: "USD",
            cutOffTime: 25 hours,
            id: 26
        });
    }

    function WRSETH_ETH() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xe8dD07CCf5BC4922424140E44Eb970F5950725ef,
            baseAsset: "WRSETH",
            quoteAsset: "ETH",
            id: 18,
            cutOffTime: 25 hours
        });
    }

    function WSTETH_ETH() internal pure returns (Oracle memory) {
        return Oracle({
            oracle: 0xa669E5272E60f78299F4824495cE01a3923f4380,
            baseAsset: "WSTETH",
            quoteAsset: "ETH",
            id: 7,
            cutOffTime: 25 hours
        });
    }
}

library Safes {
    address internal constant GUARDIAN = 0xEdD41f9740b06eCBfe1CE9194Ce2715C28263187;
    address internal constant OWNER = 0xb4d72B1c91e640e4ED7d7397F3244De4D8ACc50B;
    address internal constant RISK_MANAGER = 0xD5FA6C6e284007743d4263255385eDA78dDa268c;
    address internal constant TREASURY = 0xFd6db26eDc581D8F381f46eF4a6396A762b66E95;
}

library StargatePids {
    uint256 internal constant USDBC = 1;
}

library StargatePoolIds {
    uint256 internal constant WETH = 13;
    uint256 internal constant USDBC = 1;
}
