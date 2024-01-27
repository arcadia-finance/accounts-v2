/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Test, Constants } from "../Base.t.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";
import { MockOracles, MockERC20, MockERC721, MockERC1155, Rates } from "../utils/Types.sol";
import { Registry } from "../../src/Registry.sol";
import { AssetModule } from "../../src/asset-modules/abstracts/AbstractAM.sol";
import { CreditorMock } from "../utils/mocks/creditors/CreditorMock.sol";
import { ERC20Mock } from "../utils/mocks/tokens/ERC20Mock.sol";
import { ERC721Mock } from "../utils/mocks/tokens/ERC721Mock.sol";
import { ERC1155Mock } from "../utils/mocks/tokens/ERC1155Mock.sol";
import { ArcadiaOracle } from "../utils/mocks/oracles/ArcadiaOracle.sol";
import { AccountV1 } from "../../src/accounts/AccountV1.sol";

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
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    MockOracles internal mockOracles;
    MockERC20 internal mockERC20;
    MockERC721 internal mockERC721;
    MockERC1155 internal mockERC1155;
    Rates internal rates;

    // baseToQuoteAsset arrays
    bool[] internal BA_TO_QA_SINGLE = new bool[](1);
    bool[] internal BA_TO_QA_DOUBLE = new bool[](2);

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
                                   MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier notTestContracts(address fuzzedAddress) {
        vm.assume(fuzzedAddress != address(sequencerUptimeOracle));
        vm.assume(fuzzedAddress != address(factory));
        vm.assume(fuzzedAddress != address(accountV1Logic));
        vm.assume(fuzzedAddress != address(accountV2Logic));
        vm.assume(fuzzedAddress != address(proxyAccount));
        vm.assume(fuzzedAddress != address(registryExtension));
        vm.assume(fuzzedAddress != address(vm));
        vm.assume(fuzzedAddress != address(this));
        vm.assume(fuzzedAddress != address(chainlinkOM));
        vm.assume(fuzzedAddress != address(erc20AssetModule));
        vm.assume(fuzzedAddress != address(floorERC1155AM));
        vm.assume(fuzzedAddress != address(floorERC721AM));
        vm.assume(fuzzedAddress != address(uniV3AssetModule));
        vm.assume(fuzzedAddress != address(creditorUsd));
        vm.assume(fuzzedAddress != address(creditorStable1));
        vm.assume(fuzzedAddress != address(creditorToken1));
        vm.assume(fuzzedAddress != address(mockERC20.stable1));
        vm.assume(fuzzedAddress != address(mockERC20.stable2));
        vm.assume(fuzzedAddress != address(mockERC20.token1));
        vm.assume(fuzzedAddress != address(mockERC20.token2));
        vm.assume(fuzzedAddress != address(mockERC20.token3));
        vm.assume(fuzzedAddress != address(mockERC20.token4));
        vm.assume(fuzzedAddress != address(mockERC721.nft1));
        vm.assume(fuzzedAddress != address(mockERC721.nft2));
        vm.assume(fuzzedAddress != address(mockERC721.nft3));
        vm.assume(fuzzedAddress != address(mockERC1155.sft1));
        vm.assume(fuzzedAddress != address(mockERC1155.sft2));
        vm.assume(fuzzedAddress != address(mockOracles.stable1ToUsd));
        vm.assume(fuzzedAddress != address(mockOracles.stable2ToUsd));
        vm.assume(fuzzedAddress != address(mockOracles.token1ToUsd));
        vm.assume(fuzzedAddress != address(mockOracles.token2ToUsd));
        vm.assume(fuzzedAddress != address(mockOracles.token3ToToken4));
        vm.assume(fuzzedAddress != address(mockOracles.token4ToUsd));
        vm.assume(fuzzedAddress != address(mockOracles.nft1ToToken1));
        vm.assume(fuzzedAddress != address(mockOracles.nft2ToUsd));
        vm.assume(fuzzedAddress != address(mockOracles.nft3ToToken1));
        vm.assume(fuzzedAddress != address(mockOracles.sft1ToToken1));
        vm.assume(fuzzedAddress != address(mockOracles.sft2ToUsd));
        assumeNotForgeAddress(fuzzedAddress);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Warp to have a timestamp of at least two days old.
        vm.warp(2 days);

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
        creditorStable1.setMinimumMargin(Constants.initLiquidationCost);
        creditorStable1.setLiquidator(Constants.initLiquidator);

        vm.label({ account: address(creditorUsd), newLabel: "USD Creditor" });
        vm.label({ account: address(creditorStable1), newLabel: "Stable1 Creditor" });

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

        // Add Chainlink Oracles to the Chainlink Oracles Module.
        vm.startPrank(users.creatorAddress);
        chainlinkOM.addOracle(address(mockOracles.stable1ToUsd), "STABLE1", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.stable2ToUsd), "STABLE2", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.token1ToUsd), "TOKEN1", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.token2ToUsd), "TOKEN2", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.nft1ToToken1), "NFT1", "TOKEN1", 2 days);
        chainlinkOM.addOracle(address(mockOracles.sft1ToToken1), "SFT1", "TOKEN1", 2 days);
        vm.stopPrank();

        vm.startPrank(registryExtension.owner());
        // Create the oracle-direction arrays.
        BA_TO_QA_SINGLE[0] = true;
        BA_TO_QA_DOUBLE[0] = true;
        BA_TO_QA_DOUBLE[1] = true;

        // Add STABLE1, STABLE2, TOKEN1 and TOKEN2 to the ERC20PrimaryAM.
        oracleStable1ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.stable1ToUsd)));
        oracleStable2ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.stable2ToUsd)));
        oracleToken1ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token1ToUsd)));
        oracleToken2ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token2ToUsd)));

        erc20AssetModule.addAsset(
            address(mockERC20.stable1), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStable1ToUsdArr)
        );
        erc20AssetModule.addAsset(
            address(mockERC20.stable2), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStable2ToUsdArr)
        );
        erc20AssetModule.addAsset(address(mockERC20.token1), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken1ToUsdArr));
        erc20AssetModule.addAsset(address(mockERC20.token2), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken2ToUsdArr));

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
        registryExtension.setRiskParameters(address(creditorUsd), 0, 15 minutes, type(uint64).max);
        registryExtension.setRiskParameters(address(creditorStable1), 0, 15 minutes, type(uint64).max);
        registryExtension.setRiskParameters(address(creditorToken1), 0, 15 minutes, type(uint64).max);

        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );

        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );

        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.tokenToTokenCollFactor,
            Constants.tokenToTokenLiqFactor
        );

        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.tokenToTokenCollFactor,
            Constants.tokenToTokenLiqFactor
        );

        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );

        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
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
        ArcadiaOracle oracle = new ArcadiaOracle(uint8(decimals), description, address(73));
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
        ArcadiaOracle oracle = new ArcadiaOracle(uint8(decimals), description, address(73));
        oracle.setOffchainTransmitter(users.defaultTransmitter);
        vm.stopPrank();
        return oracle;
    }

    function initMockedOracle(uint8 decimals, string memory description, int256 answer)
        public
        returns (ArcadiaOracle)
    {
        vm.startPrank(users.defaultCreatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(uint8(decimals), description, address(73));
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

    function mintERC20TokenTo(address token, address to, uint256 amount) public {
        ERC20Mock(token).mint(to, amount);
    }

    function mintERC20TokensTo(address[] memory tokens, address to, uint256[] memory amounts) public {
        for (uint8 i = 0; i < tokens.length; ++i) {
            ERC20Mock(tokens[i]).mint(to, amounts[i]);
        }
    }

    function approveERC20TokenFor(address token, address spender, uint256 amount, address user) public {
        vm.prank(user);
        ERC20Mock(token).approve(spender, amount);
    }

    function approveERC20TokensFor(address[] memory tokens, address spender, uint256[] memory amounts, address user)
        public
    {
        vm.startPrank(user);
        for (uint8 i = 0; i < tokens.length; ++i) {
            ERC20Mock(tokens[i]).approve(spender, amounts[i]);
        }
        vm.stopPrank();
    }
}
