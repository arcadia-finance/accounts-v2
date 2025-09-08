/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuardExtension } from "../../../utils/extensions/AccountsGuardExtension.sol";
import { AccountV3 } from "../../../../src/accounts/AccountV3.sol";
import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { ChainlinkOMExtension } from "../../../utils/extensions/ChainlinkOMExtension.sol";
import { Constants, Fuzz_Test } from "../../Fuzz.t.sol";
import { DerivedAMMock } from "../../../utils/mocks/asset-modules/DerivedAMMock.sol";
import { ERC20PrimaryAMExtension } from "../../../utils/extensions/ERC20PrimaryAMExtension.sol";
import { FactoryExtension } from "../../../utils/extensions/FactoryExtension.sol";
import { FloorERC721AMExtension } from "../../../utils/extensions/FloorERC721AMExtension.sol";
import { FloorERC1155AMExtension } from "../../../utils/extensions/FloorERC1155AMExtension.sol";
import { OracleModuleMock } from "../../../utils/mocks/oracle-modules/OracleModuleMock.sol";
import { PrimaryAMMock } from "../../../utils/mocks/asset-modules/PrimaryAMMock.sol";
import { RegistryL1Extension } from "../../../utils/extensions/RegistryL1Extension.sol";

/**
 * @notice Common logic needed by all "RegistryL1" fuzz tests.
 */
abstract contract RegistryL1_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    PrimaryAMMock internal primaryAM;
    DerivedAMMock internal derivedAM;

    OracleModuleMock internal oracleModule;

    RegistryL1Extension internal registry_;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.owner);
        factory = new FactoryExtension();
        registry_ = new RegistryL1Extension(address(factory));
        chainlinkOM = new ChainlinkOMExtension(address(registry_));
        erc20AM = new ERC20PrimaryAMExtension(address(registry_));
        floorERC721AM = new FloorERC721AMExtension(address(registry_));
        floorERC1155AM = new FloorERC1155AMExtension(address(registry_));

        accountsGuard = new AccountsGuardExtension(users.owner, address(factory));
        accountLogic = new AccountV3(address(factory), address(accountsGuard), address(0));
        factory.setLatestAccountVersion(2);
        factory.setNewAccountInfo(address(registry_), address(accountLogic), Constants.upgradeRoot3To4And4To3, "");

        // Set the Guardians.
        factory.changeGuardian(users.guardian);
        registry_.changeGuardian(users.guardian);

        // Add Asset Modules to the Registry.
        registry_.addAssetModule(address(erc20AM));
        registry_.addAssetModule(address(floorERC721AM));
        registry_.addAssetModule(address(floorERC1155AM));

        // Add Oracle Modules to the Registry.
        registry_.addOracleModule(address(chainlinkOM));

        // Add oracles and assets.
        chainlinkOM.addOracle(address(mockOracles.stable1ToUsd), "STABLE1", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.stable2ToUsd), "STABLE2", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.token1ToUsd), "TOKEN1", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.token2ToUsd), "TOKEN2", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.nft1ToToken1), "NFT1", "TOKEN1", 2 days);
        chainlinkOM.addOracle(address(mockOracles.sft1ToToken1), "SFT1", "TOKEN1", 2 days);
        erc20AM.addAsset(address(mockERC20.stable1), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStable1ToUsdArr));
        erc20AM.addAsset(address(mockERC20.stable2), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStable2ToUsdArr));
        erc20AM.addAsset(address(mockERC20.token1), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken1ToUsdArr));
        erc20AM.addAsset(address(mockERC20.token2), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken2ToUsdArr));
        floorERC721AM.addAsset(
            address(mockERC721.nft1), 0, 999, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleNft1ToToken1ToUsd)
        );
        floorERC1155AM.addAsset(
            address(mockERC1155.sft1), 1, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleSft1ToToken1ToUsd)
        );

        primaryAM = new PrimaryAMMock(address(registry_), 0);
        registry_.addAssetModule(address(primaryAM));

        derivedAM = new DerivedAMMock(address(registry_), 0);
        registry_.addAssetModule(address(derivedAM));
        vm.stopPrank();

        // Deploy an initial Account with all inputs to zero
        vm.prank(users.accountOwner);
        address proxyAddress = factory.createAccount(0, 0, address(0));
        account = AccountV3(proxyAddress);

        // Set Risk Variables.
        vm.startPrank(users.riskManager);
        registry_.setRiskParameters(address(creditorUsd), 0, type(uint64).max);
        registry_.setRiskParameters(address(creditorStable1), 0, type(uint64).max);
        registry_.setRiskParameters(address(creditorToken1), 0, type(uint64).max);

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.tokenToTokenCollFactor,
            Constants.tokenToTokenLiqFactor
        );

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.tokenToTokenCollFactor,
            Constants.tokenToTokenLiqFactor
        );

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
        );

        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function addMockedOracle(uint256 oracleId, uint256 rate, bytes16 baseAsset, bytes16 quoteAsset, bool active)
        public
    {
        oracleModule.setOracle(oracleId, baseAsset, quoteAsset, active);
        registry_.setOracleToOracleModule(oracleId, address(oracleModule));
        oracleModule.setRate(oracleId, rate);
    }

    function convertAssetToUsd(uint256 assetDecimals, uint256 amount, uint80[] memory oracleArr)
        public
        view
        returns (uint256 usdValue)
    {
        uint256 ratesMultiplied = 1;
        uint256 sumOfOracleDecimals;
        for (uint8 i; i < oracleArr.length; i++) {
            (,, address oracle) = chainlinkOM.getOracleInformation(oracleArr[i]);
            (, int256 answer,,,) = ArcadiaOracle(oracle).latestRoundData();
            ratesMultiplied *= uint256(answer);
            sumOfOracleDecimals += ArcadiaOracle(oracle).decimals();
        }

        usdValue = (Constants.WAD * ratesMultiplied * amount) / (10 ** (sumOfOracleDecimals + assetDecimals));
    }

    function convertUsdToNumeraire(
        uint256 numeraireDecimals,
        uint256 usdAmount,
        uint256 rateNumeraireToUsd,
        uint256 oracleDecimals
    ) public pure returns (uint256 assetValue) {
        assetValue = (usdAmount * 10 ** oracleDecimals) / rateNumeraireToUsd;
        // USD value will always be in 18 decimals so we have to convert to numeraire decimals if needed
        if (numeraireDecimals < 18) {
            assetValue /= 10 ** (18 - numeraireDecimals);
        }
    }
}
