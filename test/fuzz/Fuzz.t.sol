/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ArcadiaAccountsFixture } from "../utils/fixtures/arcadia-accounts/ArcadiaAccountsFixture.f.sol";
import { ArcadiaOracle } from "../utils/mocks/oracles/ArcadiaOracle.sol";
import { Base_Test } from "../Base.t.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";
import { Constants } from "../utils/Constants.sol";
import { CreditorMock } from "../utils/mocks/creditors/CreditorMock.sol";
import { ERC20Mock } from "../utils/mocks/tokens/ERC20Mock.sol";
import { ERC721Mock } from "../utils/mocks/tokens/ERC721Mock.sol";
import { ERC1155Mock } from "../utils/mocks/tokens/ERC1155Mock.sol";
import { FloorERC721AMExtension } from "../utils/extensions/FloorERC721AMExtension.sol";
import { FloorERC1155AMExtension } from "../utils/extensions/FloorERC1155AMExtension.sol";
import { MockERC20, MockERC721, MockERC1155, MockOracles, Rates } from "../utils/Types.sol";
import { NativeTokenAMExtension } from "../utils/extensions/NativeTokenAMExtension.sol";

/**
 * @notice Common logic needed by all fuzz tests.
 * @dev Each function must be fuzz tested over its full space of possible state configurations
 * (both the state variables of the contract being tested
 * as the state variables of any external contract with which the function interacts).
 * @dev in practice each input parameter and state variable (as explained above) must be tested over its full range
 * (eg. a uint256 from 0 to type(uint256).max), unless the parameter/variable is bound by an invariant.
 * If this case, said invariant must be explicitly tested in the invariant tests.
 */
abstract contract Fuzz_Test is Base_Test, ArcadiaAccountsFixture {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// forge-lint: disable-start(mixed-case-variable)
    FloorERC721AMExtension internal floorERC721AM;
    FloorERC1155AMExtension internal floorERC1155AM;
    NativeTokenAMExtension internal nativeTokenAM;
    MockOracles internal mockOracles;
    MockERC20 internal mockERC20;
    MockERC721 internal mockERC721;
    MockERC1155 internal mockERC1155;
    Rates internal rates;
    /// forge-lint: disable-end(mixed-case-variable)

    // ERC20 oracle arrays
    uint80[] internal oracleStable1ToUsdArr = new uint80[](1);
    uint80[] internal oracleStable2ToUsdArr = new uint80[](1);
    uint80[] internal oracleToken1ToUsdArr = new uint80[](1);
    uint80[] internal oracleToken2ToUsdArr = new uint80[](1);

    // ERC721 oracle arrays
    uint80[] internal oracleNft1ToToken1ToUsd = new uint80[](2);

    // ERC1155 oracle array
    uint80[] internal oracleSft1ToToken1ToUsd = new uint80[](2);

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    CreditorMock internal creditorUsd;
    CreditorMock internal creditorStable1;
    CreditorMock internal creditorToken1;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();
        deployArcadiaAccounts(address(0));

        // Warp to have a timestamp of at least two days old.
        vm.warp(2 days);

        // Deploy mocked Asset Modules.
        vm.startPrank(users.owner);
        floorERC721AM = new FloorERC721AMExtension(address(registry));
        floorERC1155AM = new FloorERC1155AMExtension(address(registry));
        registry.addAssetModule(address(floorERC721AM));
        registry.addAssetModule(address(floorERC1155AM));
        vm.stopPrank();

        vm.label({ account: address(floorERC721AM), newLabel: "ERC721 Asset Module" });
        vm.label({ account: address(floorERC1155AM), newLabel: "ERC1155 Asset Module" });

        // Create mock ERC20 tokens for testing
        vm.startPrank(users.tokenCreator);

        mockERC20 = MockERC20({
            stable1: new ERC20Mock("STABLE1", "S1", uint8(Constants.STABLE_DECIMALS)),
            stable2: new ERC20Mock("STABLE2", "S2", uint8(Constants.STABLE_DECIMALS)),
            token1: new ERC20Mock("TOKEN1", "T1", uint8(Constants.TOKEN_DECIMALS)),
            token2: new ERC20Mock("TOKEN2", "T2", uint8(Constants.TOKEN_DECIMALS)),
            token3: new ERC20Mock("TOKEN3", "T3", uint8(Constants.TOKEN_DECIMALS)),
            token4: new ERC20Mock("TOKEN4", "T4", uint8(Constants.TOKEN_DECIMALS))
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
            stable1ToUsd: 1 * 10 ** Constants.STABLE_ORACLE_DECIMALS,
            stable2ToUsd: 1 * 10 ** Constants.STABLE_ORACLE_DECIMALS,
            token1ToUsd: 6000 * 10 ** Constants.TOKEN_ORACLE_DECIMALS,
            token2ToUsd: 50 * 10 ** Constants.TOKEN_ORACLE_DECIMALS,
            token3ToToken4: 4 * 10 ** Constants.TOKEN_ORACLE_DECIMALS,
            token4ToUsd: 3 * 10 ** (Constants.TOKEN_ORACLE_DECIMALS - 2),
            nft1ToToken1: 50 * 10 ** Constants.NFT_ORACLE_DECIMALS,
            nft2ToUsd: 7 * 10 ** Constants.NFT_ORACLE_DECIMALS,
            nft3ToToken1: 1 * 10 ** (Constants.NFT_ORACLE_DECIMALS - 1),
            sft1ToToken1: 1 * 10 ** (Constants.SFT_ORACLE_DECIMALS - 2),
            sft2ToUsd: 1 * 10 ** Constants.SFT_ORACLE_DECIMALS
        });

        // Create a creditor with each Numeraire.
        creditorUsd = new CreditorMock();
        creditorStable1 = new CreditorMock();
        creditorToken1 = new CreditorMock();
        creditorStable1.setNumeraire(address(mockERC20.stable1));
        creditorToken1.setNumeraire(address(mockERC20.token1));
        creditorUsd.setRiskManager(users.riskManager);
        creditorStable1.setRiskManager(users.riskManager);
        creditorToken1.setRiskManager(users.riskManager);

        // Initialize the default liquidation cost and liquidator of creditor
        // The numeraire on initialization will depend on the type of test and set at a lower level
        creditorStable1.setMinimumMargin(Constants.MINIMUM_MARGIN);
        creditorStable1.setLiquidator(Constants.LIQUIDATOR);

        vm.label({ account: address(creditorUsd), newLabel: "USD Creditor" });
        vm.label({ account: address(creditorStable1), newLabel: "Stable1 Creditor" });

        // Deploy Oracles
        mockOracles = MockOracles({
            stable1ToUsd: initMockedOracle(uint8(Constants.STABLE_ORACLE_DECIMALS), "STABLE1 / USD", rates.stable1ToUsd),
            stable2ToUsd: initMockedOracle(uint8(Constants.STABLE_ORACLE_DECIMALS), "STABLE2 / USD", rates.stable2ToUsd),
            token1ToUsd: initMockedOracle(uint8(Constants.TOKEN_ORACLE_DECIMALS), "TOKEN1 / USD", rates.token1ToUsd),
            token2ToUsd: initMockedOracle(uint8(Constants.TOKEN_ORACLE_DECIMALS), "TOKEN2 / USD", rates.token2ToUsd),
            token3ToToken4: initMockedOracle(
                uint8(Constants.TOKEN_ORACLE_DECIMALS), "TOKEN3 / TOKEN4", rates.token3ToToken4
            ),
            token4ToUsd: initMockedOracle(uint8(Constants.TOKEN_ORACLE_DECIMALS), "TOKEN4 / USD", rates.token4ToUsd),
            nft1ToToken1: initMockedOracle(uint8(Constants.NFT_ORACLE_DECIMALS), "NFT1 / TOKEN1", rates.nft1ToToken1),
            nft2ToUsd: initMockedOracle(uint8(Constants.NFT_ORACLE_DECIMALS), "NFT2 / USD", rates.nft2ToUsd),
            nft3ToToken1: initMockedOracle(uint8(Constants.NFT_ORACLE_DECIMALS), "NFT3 / TOKEN1", rates.nft3ToToken1),
            sft1ToToken1: initMockedOracle(uint8(Constants.SFT_ORACLE_DECIMALS), "SFT1 / TOKEN1", rates.sft1ToToken1),
            sft2ToUsd: initMockedOracle(uint8(Constants.SFT_ORACLE_DECIMALS), "SFT2 / TOKEN1", rates.sft2ToUsd)
        });

        // Add Chainlink Oracles to the Chainlink Oracles Module.
        vm.startPrank(users.owner);
        chainlinkOM.addOracle(address(mockOracles.stable1ToUsd), "STABLE1", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.stable2ToUsd), "STABLE2", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.token1ToUsd), "TOKEN1", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.token2ToUsd), "TOKEN2", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.nft1ToToken1), "NFT1", "TOKEN1", 2 days);
        chainlinkOM.addOracle(address(mockOracles.sft1ToToken1), "SFT1", "TOKEN1", 2 days);
        vm.stopPrank();

        vm.startPrank(registry.owner());

        // Add STABLE1, STABLE2, TOKEN1 and TOKEN2 to the ERC20PrimaryAM.
        oracleStable1ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.stable1ToUsd)));
        oracleStable2ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.stable2ToUsd)));
        oracleToken1ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token1ToUsd)));
        oracleToken2ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token2ToUsd)));

        erc20AM.addAsset(address(mockERC20.stable1), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStable1ToUsdArr));
        erc20AM.addAsset(address(mockERC20.stable2), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStable2ToUsdArr));
        erc20AM.addAsset(address(mockERC20.token1), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken1ToUsdArr));
        erc20AM.addAsset(address(mockERC20.token2), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken2ToUsdArr));

        // Add NFT1 to the floorERC721AM.
        oracleNft1ToToken1ToUsd[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.nft1ToToken1)));
        oracleNft1ToToken1ToUsd[1] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token1ToUsd)));

        floorERC721AM.addAsset(
            address(mockERC721.nft1), 0, 999, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleNft1ToToken1ToUsd)
        );

        // Add ERC1155 contract to the floorERC1155AM
        oracleSft1ToToken1ToUsd[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.sft1ToToken1)));
        oracleSft1ToToken1ToUsd[1] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token1ToUsd)));

        floorERC1155AM.addAsset(
            address(mockERC1155.sft1), 1, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleSft1ToToken1ToUsd)
        );

        vm.stopPrank();

        // Set Risk Variables.
        vm.startPrank(users.riskManager);
        registry.setRiskParameters(address(creditorUsd), 0, 15 minutes, type(uint64).max);
        registry.setRiskParameters(address(creditorStable1), 0, 15 minutes, type(uint64).max);
        registry.setRiskParameters(address(creditorToken1), 0, 15 minutes, type(uint64).max);

        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.STABLE_TO_STABLE_COLL_FACTOR,
            Constants.STABLE_TO_STABLE_LIQ_FACTOR
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.STABLE_TO_STABLE_COLL_FACTOR,
            Constants.STABLE_TO_STABLE_LIQ_FACTOR
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.TOKEN_TO_STABLE_COLL_FACTOR,
            Constants.TOKEN_TO_STABLE_LIQ_FACTOR
        );

        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.STABLE_TO_STABLE_COLL_FACTOR,
            Constants.STABLE_TO_STABLE_LIQ_FACTOR
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.STABLE_TO_STABLE_COLL_FACTOR,
            Constants.STABLE_TO_STABLE_LIQ_FACTOR
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.TOKEN_TO_STABLE_COLL_FACTOR,
            Constants.TOKEN_TO_STABLE_LIQ_FACTOR
        );

        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.TOKEN_TO_STABLE_COLL_FACTOR,
            Constants.TOKEN_TO_STABLE_LIQ_FACTOR
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.TOKEN_TO_STABLE_COLL_FACTOR,
            Constants.TOKEN_TO_STABLE_LIQ_FACTOR
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.TOKEN_TO_TOKEN_COLL_FACTOR,
            Constants.TOKEN_TO_TOKEN_LIQ_FACTOR
        );

        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.TOKEN_TO_STABLE_COLL_FACTOR,
            Constants.TOKEN_TO_STABLE_LIQ_FACTOR
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.TOKEN_TO_STABLE_COLL_FACTOR,
            Constants.TOKEN_TO_STABLE_LIQ_FACTOR
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.TOKEN_TO_TOKEN_COLL_FACTOR,
            Constants.TOKEN_TO_TOKEN_LIQ_FACTOR
        );

        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );

        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function addAssetToArcadia(address asset, int256 price) internal virtual override {
        super.addAssetToArcadia(asset, price);

        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(address(creditorUsd), asset, 0, type(uint112).max, 80, 90);
    }

    function addAssetToArcadia(address asset, int256 price, uint112 initialExposure, uint112 maxExposure) internal {
        addAssetToArcadia(asset, price);
        erc20AM.setExposure(address(creditorUsd), asset, initialExposure, maxExposure);
    }

    function addNativeTokenToArcadia(address asset, int256 price) internal {
        deployNativeTokenAM();

        ArcadiaOracle oracle = initMockedOracle("NT / USD", price);

        vm.startPrank(users.owner);
        chainlinkOM.addOracle(address(oracle), "NT", "USD", 2 days);
        uint80[] memory oracles = new uint80[](1);
        oracles[0] = uint80(chainlinkOM.oracleToOracleId(address(oracle)));
        nativeTokenAM.addAsset(asset, BitPackingLib.pack(BA_TO_QA_SINGLE, oracles));
        vm.stopPrank();

        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(address(creditorUsd), asset, 0, type(uint112).max, 80, 90);
    }

    function addNativeTokenToArcadia(address asset, int256 price, uint112 initialExposure, uint112 maxExposure)
        internal
    {
        addNativeTokenToArcadia(asset, price);
        nativeTokenAM.setExposure(address(creditorUsd), asset, initialExposure, maxExposure);
    }

    /// forge-lint: disable-next-item(mixed-case-function)
    function deployNativeTokenAM() internal {
        vm.startPrank(users.owner);
        nativeTokenAM = new NativeTokenAMExtension(address(registry), 18);
        registry.addAssetModule(address(nativeTokenAM));
        vm.stopPrank();
    }
}
