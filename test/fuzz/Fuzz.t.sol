/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Base_Test, Constants } from "../Base.t.sol";
import { MockOracles, MockERC20, MockERC721, MockERC1155, Rates } from "../utils/Types.sol";
import { MainRegistry } from "../../src/MainRegistry.sol";
import { OracleHub } from "../../src/OracleHub.sol";
import { PricingModule } from "../../src/pricing-modules/AbstractPricingModule.sol";
import { TrustedCreditorMock } from ".././utils/mocks/TrustedCreditorMock.sol";
import { Proxy } from "../../src/Proxy.sol";
import { ERC20Mock } from ".././utils/mocks/ERC20Mock.sol";
import { ERC721Mock } from ".././utils/mocks/ERC721Mock.sol";
import { ERC1155Mock } from ".././utils/mocks/ERC1155Mock.sol";
import { ArcadiaOracle } from ".././utils/mocks/ArcadiaOracle.sol";
import { AccountV1 } from "../../src/AccountV1.sol";

/**
 * @notice Common logic needed by all fuzz tests.
 * @dev Each function must be fuzz tested over its full space of possible state configurations
 * (both the state variables of the contract being tested
 * as the state variables of any external contract with which the function interacts).
 * @dev in practice each input parameter and state variable (as explained above) must be tested over its full range
 * (eg. a uint256 from 0 to type(uint256).max), unless the parameter/variable is bound by an invariant.
 * If this case, said invariant must be explicitly tested in the invariant tests.
 */
abstract contract Fuzz_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    // Basecurrency ID's in MainRegistry.sol
    uint256 internal constant UsdBaseCurrencyID = 0;
    uint256 internal constant Stable1BaseCurrencyID = 1;
    uint256 internal constant Token1BaseCurrencyID = 2;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    MockOracles internal mockOracles;
    MockERC20 internal mockERC20;
    MockERC721 internal mockERC721;
    MockERC1155 internal mockERC1155;
    Rates internal rates;

    // ERC20 oracle arrays
    address[] public oracleStable1ToUsdArr = new address[](1);
    address[] public oracleStable2ToUsdArr = new address[](1);
    address[] public oracleToken1ToUsdArr = new address[](1);
    address[] public oracleToken2ToUsdArr = new address[](1);

    // ERC721 oracle arrays
    address[] public oracleNft1ToToken1ToUsd = new address[](2);

    // ERC1155 oracle array
    address[] public oracleSft1ToToken1ToUsd = new address[](2);

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Create mock ERC20 tokens for testing
        vm.startPrank(users.tokenCreatorAddress);

        mockERC20 = MockERC20({
            stable1: new ERC20Mock("STABLE1", "S1", uint8(Constants.stableDecimals)),
            stable2: new ERC20Mock("STABLE2", "S2", uint8(Constants.stableDecimals)),
            token1: new ERC20Mock("TOKEN1", "T1", uint8(Constants.tokenDecimals)),
            token2: new ERC20Mock("TOKEN2", "T2", uint8(Constants.tokenDecimals)),
            token3: new ERC20Mock("TOKEN3", "T3", uint8(Constants.tokenDecimals)),
            token4: new ERC20Mock("TOKEN4", "T4", uint8(Constants.tokenDecimals))
        });

        // Create mock ERC721 tokens for testing
        mockERC721 = MockERC721({
            nft1: new ERC721Mock("NFT1", "NFT1"),
            nft2: new ERC721Mock("NFT2", "NFT2"),
            nft3: new ERC721Mock("NFT3", "NFT3")
        });

        // Create a mock ERC1155 token for testing
        mockERC1155 = MockERC1155({ sft1: new ERC1155Mock("SFT1", "SFT1"), sft2: new ERC1155Mock("SFT2", "SFT2") });

        // Label the deployed tokens
        vm.label({ account: address(mockERC20.stable1), newLabel: "STABLE1" });
        vm.label({ account: address(mockERC20.stable2), newLabel: "STABLE2" });
        vm.label({ account: address(mockERC20.token1), newLabel: "TOKEN1" });
        vm.label({ account: address(mockERC20.token2), newLabel: "TOKEN2" });
        vm.label({ account: address(mockERC20.token3), newLabel: "TOKEN3" });
        vm.label({ account: address(mockERC20.token4), newLabel: "TOKEN4" });
        vm.label({ account: address(mockERC721.nft1), newLabel: "NFT1" });
        vm.label({ account: address(mockERC721.nft2), newLabel: "NFT2" });
        vm.label({ account: address(mockERC721.nft3), newLabel: "NFT3" });
        vm.label({ account: address(mockERC1155.sft1), newLabel: "SFT1" });
        vm.label({ account: address(mockERC1155.sft2), newLabel: "SFT2" });

        // Set rates
        rates = Rates({
            stable1ToUsd: 1 * 10 ** Constants.stableOracleDecimals,
            stable2ToUsd: 1 * 10 ** Constants.stableOracleDecimals,
            token1ToUsd: 6000 * 10 ** Constants.tokenOracleDecimals,
            token2ToUsd: 50 * 10 ** Constants.tokenOracleDecimals,
            token3ToToken4: 4 * 10 ** Constants.tokenOracleDecimals,
            token4ToUsd: 3 * 10 ** (Constants.tokenOracleDecimals - 2),
            nft1ToToken1: 50 * 10 ** Constants.nftOracleDecimals,
            nft2ToUsd: 7 * 10 ** Constants.nftOracleDecimals,
            nft3ToToken1: 1 * 10 ** (Constants.nftOracleDecimals - 1),
            sft1ToToken1: 1 * 10 ** (Constants.erc1155OracleDecimals - 2),
            sft2ToUsd: 1 * 10 ** Constants.erc1155OracleDecimals
        });

        // Set a trusted creditor with initialized params to use accross tests
        initBaseCurrency = address(mockERC20.stable1);
        trustedCreditor.setBaseCurrency(initBaseCurrency);
        vm.stopPrank();

        // Deploy Oracles
        mockOracles = MockOracles({
            stable1ToUsd: initMockedOracle(uint8(Constants.stableOracleDecimals), "STABLE1 / USD", rates.stable1ToUsd),
            stable2ToUsd: initMockedOracle(uint8(Constants.stableOracleDecimals), "STABLE2 / USD", rates.stable2ToUsd),
            token1ToUsd: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN1 / USD", rates.token1ToUsd),
            token2ToUsd: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN2 / USD", rates.token2ToUsd),
            token3ToToken4: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN3 / TOKEN4", rates.token3ToToken4),
            token4ToUsd: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN4 / USD", rates.token4ToUsd),
            nft1ToToken1: initMockedOracle(uint8(Constants.nftOracleDecimals), "NFT1 / TOKEN1", rates.nft1ToToken1),
            nft2ToUsd: initMockedOracle(uint8(Constants.nftOracleDecimals), "NFT2 / USD", rates.nft2ToUsd),
            nft3ToToken1: initMockedOracle(uint8(Constants.nftOracleDecimals), "NFT3 / TOKEN1", rates.nft3ToToken1),
            sft1ToToken1: initMockedOracle(uint8(Constants.erc1155OracleDecimals), "SFT1 / TOKEN1", rates.sft1ToToken1),
            sft2ToUsd: initMockedOracle(uint8(Constants.erc1155OracleDecimals), "SFT2 / TOKEN1", rates.sft2ToUsd)
        });

        // Add STABLE1 AND TOKEN1 as baseCurrencies in MainRegistry
        vm.startPrank(mainRegistryExtension.owner());
        mainRegistryExtension.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable1),
                baseCurrencyToUsdOracle: address(mockOracles.stable1ToUsd),
                baseCurrencyLabel: "STABLE1",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.stableDecimals))
            })
        );

        mainRegistryExtension.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                assetAddress: address(mockERC20.token1),
                baseCurrencyToUsdOracle: address(mockOracles.token1ToUsd),
                baseCurrencyLabel: "TOKEN1",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );

        // Add Oracles to the OracleHub.
        // Do not add TOKEN4/USD, TOKEN3/TOKEN4 as we are testing it on a case-by-case basis
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                baseAsset: "STABLE1",
                quoteAsset: "USD",
                oracle: address(mockOracles.stable1ToUsd),
                baseAssetAddress: address(mockERC20.stable1),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                baseAsset: "STABLE2",
                quoteAsset: "USD",
                oracle: address(mockOracles.stable2ToUsd),
                baseAssetAddress: address(mockERC20.stable2),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                baseAsset: "TOKEN1",
                quoteAsset: "USD",
                oracle: address(mockOracles.token1ToUsd),
                baseAssetAddress: address(mockERC20.token1),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                baseAsset: "TOKEN2",
                quoteAsset: "USD",
                oracle: address(mockOracles.token2ToUsd),
                baseAssetAddress: address(mockERC20.token2),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.nftOracleDecimals),
                baseAsset: "NFT1",
                quoteAsset: "TOKEN1",
                oracle: address(mockOracles.nft1ToToken1),
                baseAssetAddress: address(mockERC721.nft1),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.erc1155OracleDecimals),
                baseAsset: "SFT1",
                quoteAsset: "TOKEN1",
                oracle: address(mockOracles.sft1ToToken1),
                baseAssetAddress: address(mockERC1155.sft1),
                isActive: true
            })
        );

        PricingModule.RiskVarInput[] memory riskVarsStable = new PricingModule.RiskVarInput[](3);
        PricingModule.RiskVarInput[] memory riskVarsToken = new PricingModule.RiskVarInput[](3);

        riskVarsStable[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: Constants.stableToStableCollFactor,
            liquidationFactor: Constants.stableToStableLiqFactor
        });
        riskVarsStable[1] = PricingModule.RiskVarInput({
            baseCurrency: 1,
            asset: address(0),
            collateralFactor: Constants.stableToStableCollFactor,
            liquidationFactor: Constants.stableToStableLiqFactor
        });
        riskVarsStable[2] = PricingModule.RiskVarInput({
            baseCurrency: 2,
            asset: address(0),
            collateralFactor: Constants.tokenToStableCollFactor,
            liquidationFactor: Constants.tokenToStableLiqFactor
        });

        riskVarsToken[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: Constants.tokenToStableCollFactor,
            liquidationFactor: Constants.tokenToStableLiqFactor
        });
        riskVarsToken[1] = PricingModule.RiskVarInput({
            baseCurrency: 1,
            asset: address(0),
            collateralFactor: Constants.tokenToStableCollFactor,
            liquidationFactor: Constants.tokenToStableLiqFactor
        });
        riskVarsToken[2] = PricingModule.RiskVarInput({
            baseCurrency: 2,
            asset: address(0),
            collateralFactor: Constants.tokenToTokenLiqFactor,
            liquidationFactor: Constants.tokenToTokenLiqFactor
        });

        // Add STABLE1, STABLE2, TOKEN1 and TOKEN2 to the standardERC20PricingModule.
        oracleStable1ToUsdArr[0] = address(mockOracles.stable1ToUsd);
        oracleStable2ToUsdArr[0] = address(mockOracles.stable2ToUsd);
        oracleToken1ToUsdArr[0] = address(mockOracles.token1ToUsd);
        oracleToken2ToUsdArr[0] = address(mockOracles.token2ToUsd);

        erc20PricingModule.addAsset(
            address(mockERC20.stable1), oracleStable1ToUsdArr, riskVarsStable, type(uint128).max
        );
        erc20PricingModule.addAsset(
            address(mockERC20.stable2), oracleStable2ToUsdArr, riskVarsStable, type(uint128).max
        );
        erc20PricingModule.addAsset(address(mockERC20.token1), oracleToken1ToUsdArr, riskVarsToken, type(uint128).max);
        erc20PricingModule.addAsset(address(mockERC20.token2), oracleToken2ToUsdArr, riskVarsToken, type(uint128).max);

        // Add NFT1 to the floorERC721PricingModule.
        oracleNft1ToToken1ToUsd[0] = address(mockOracles.nft1ToToken1);
        oracleNft1ToToken1ToUsd[1] = address(mockOracles.token1ToUsd);

        floorERC721PricingModule.addAsset(
            address(mockERC721.nft1), 0, 999, oracleNft1ToToken1ToUsd, emptyRiskVarInput, type(uint128).max
        );

        // Add ERC1155 contract to the floorERC1155PricingModule
        oracleSft1ToToken1ToUsd[0] = address(mockOracles.sft1ToToken1);
        oracleSft1ToToken1ToUsd[1] = address(mockOracles.token1ToUsd);

        floorERC1155PricingModule.addAsset(
            address(mockERC1155.sft1), 1, oracleSft1ToToken1ToUsd, emptyRiskVarInput, type(uint128).max
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function initMockedOracle(uint8 decimals, string memory description, uint256 answer)
        public
        returns (ArcadiaOracle)
    {
        vm.startPrank(users.defaultCreatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(
            uint8(decimals),
            description,
            address(73)
        );
        oracle.setOffchainTransmitter(users.defaultTransmitter);
        vm.stopPrank();
        vm.startPrank(users.defaultTransmitter);
        int256 convertedAnswer = int256(answer);
        oracle.transmit(convertedAnswer);
        vm.stopPrank();
        return oracle;
    }

    function initMockedOracle(uint8 decimals, string memory description) public returns (ArcadiaOracle) {
        vm.startPrank(users.defaultCreatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(
            uint8(decimals),
            description,
            address(73)
        );
        oracle.setOffchainTransmitter(users.defaultTransmitter);
        vm.stopPrank();
        return oracle;
    }

    function initMockedOracle(uint8 decimals, string memory description, int256 answer)
        public
        returns (ArcadiaOracle)
    {
        vm.startPrank(users.defaultCreatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(
            uint8(decimals),
            description,
            address(73)
        );
        oracle.setOffchainTransmitter(users.defaultTransmitter);
        vm.stopPrank();

        vm.prank(users.defaultTransmitter);
        oracle.transmit(answer);

        return oracle;
    }

    function transmitOracle(ArcadiaOracle oracle, int256 answer, address transmitter) public {
        vm.startPrank(transmitter);
        oracle.transmit(answer);
        vm.stopPrank();
    }

    function transmitOracle(ArcadiaOracle oracle, int256 answer) public {
        vm.startPrank(users.defaultTransmitter);
        oracle.transmit(answer);
        vm.stopPrank();
    }

    function depositTokenInAccount(AccountV1 account_, ERC20Mock token, uint256 amount) public {
        address[] memory assets = new address[](1);
        assets[0] = address(token);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        deal(address(token), account_.owner(), amount);
        vm.startPrank(account_.owner());
        token.approve(address(account_), amount);
        account_.deposit(assets, ids, amounts);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/
}
