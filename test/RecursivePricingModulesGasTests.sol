/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Base_Test, Constants } from "./Base.t.sol";
import { OracleHub } from "../src/OracleHub.sol";
import { Proxy } from "../src/Proxy.sol";
import { ERC20Mock } from "./utils/mocks/ERC20Mock.sol";
import { ERC4626Mock } from "./utils/mocks/ERC4626Mock.sol";
import { ArcadiaOracle } from "./utils/mocks/ArcadiaOracle.sol";
import { Factory } from "../src/Factory.sol";
import { AccountV1 } from "../src/AccountV1.sol";

import { PrimaryPricingModule } from "../src/pricing-modules/PrimaryPricingModuleOptionThomas.sol";
import { MainRegistry } from "../src/MainRegistryOptionThomas.sol";
import { PrimaryChainlinkERC20PricingModule } from
    "../src/pricing-modules/PrimaryChainlinkERC20PricingModuleOptionThomas.sol";
import { ERC4626PricingModule } from "../src/pricing-modules/DerivedERC4626PricingModuleOptionThomas.sol";

/**
 * @notice Common logic needed by all fuzz tests.
 * @dev Each function must be fuzz tested over its full space of possible state configurations
 * (both the state variables of the contract being tested
 * as the state variables of any external contract with which the function interacts).
 * @dev in practice each input parameter and state variable (as explained above) must be tested over its full range
 * (eg. a uint256 from 0 to type(uint256).max), unless the parameter/variable is bound by an invariant.
 * If this case, said invariant must be explicitly tested in the invariant tests.
 */
contract Fuzz_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    // Basecurrency ID's in MainRegistry.sol
    uint256 internal constant UsdBaseCurrencyID = 0;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    ArcadiaOracle oracleTokenToUsd;
    ERC20Mock internal primaryToken;
    ERC4626Mock internal middleToken;
    ERC4626Mock internal upperToken;

    uint256 internal tokenToUsd;

    // ERC20 oracle arrays
    address[] internal oracleTokenToUsdArr = new address[](1);

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    MainRegistry internal mainRegistry;
    PrimaryChainlinkERC20PricingModule internal erc20PricingModule_;
    ERC4626PricingModule internal middleErc4626PricingModule;
    ERC4626PricingModule internal upperErc4626PricingModule;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        Base_Test.setUp();

        // Create mock ERC20 tokens for testing
        vm.startPrank(users.tokenCreatorAddress);
        primaryToken = new ERC20Mock("PRIMARY TOKEN", "PT", uint8(Constants.tokenDecimals));
        middleToken = new ERC4626Mock(primaryToken, "MIDDLE TOKEN", "MT");
        upperToken = new ERC4626Mock(middleToken, "UPPER TOKEN", "UT");

        // Mint tokens to accountOwner
        primaryToken.mint(users.accountOwner, 100 * 10 ** Constants.tokenDecimals);
        primaryToken.mint(users.tokenCreatorAddress, 11 * 10 ** Constants.tokenDecimals);
        primaryToken.approve(address(middleToken), type(uint256).max);

        middleToken.mint(10 * 10 ** Constants.tokenDecimals, users.accountOwner);
        middleToken.mint(1 * 10 ** Constants.tokenDecimals, users.tokenCreatorAddress);
        middleToken.approve(address(upperToken), type(uint256).max);

        upperToken.mint(1 * 10 ** Constants.tokenDecimals, users.accountOwner);
        vm.stopPrank();

        // Deploy test contracts.
        vm.startPrank(users.creatorAddress);
        factory = new Factory();
        mainRegistry = new MainRegistry(address(factory));
        erc20PricingModule_ = new PrimaryChainlinkERC20PricingModule(address(mainRegistry), address(oracleHub), 0);
        middleErc4626PricingModule = new ERC4626PricingModule(address(mainRegistry), address(oracleHub), 0);
        upperErc4626PricingModule = new ERC4626PricingModule(address(mainRegistry), address(oracleHub), 0);
        vm.stopPrank();

        // Initialize Mainregistry
        vm.prank(users.creatorAddress);
        factory.setNewAccountInfo(address(mainRegistry), address(accountV1Logic), Constants.upgradeProof1To2, "");

        // Add Pricing Modules to the Main Registry.
        vm.startPrank(users.creatorAddress);
        mainRegistry.addPricingModule(address(erc20PricingModule_));
        mainRegistry.addPricingModule(address(middleErc4626PricingModule));
        mainRegistry.addPricingModule(address(upperErc4626PricingModule));
        vm.stopPrank();

        // Set max USD exposures.
        vm.startPrank(users.creatorAddress);
        middleErc4626PricingModule.setMaxUsdExposureProtocol(type(uint128).max);
        upperErc4626PricingModule.setMaxUsdExposureProtocol(type(uint128).max);

        // Set rates
        tokenToUsd = 1 ** Constants.tokenOracleDecimals;

        // Deploy Oracles
        oracleTokenToUsd = initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN / USD", tokenToUsd);

        // Add Oracles to the OracleHub.
        vm.prank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                baseAsset: "TOKEN",
                quoteAsset: "USD",
                oracle: address(oracleTokenToUsd),
                baseAssetAddress: address(primaryToken),
                isActive: true
            })
        );

        // Add STABLE1, STABLE2, TOKEN1 and TOKEN2 to the standardERC20PricingModule.
        PrimaryPricingModule.RiskVarInput[] memory riskVarsToken = new PrimaryPricingModule.RiskVarInput[](1);
        riskVarsToken[0] = PrimaryPricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: Constants.tokenToStableCollFactor,
            liquidationFactor: Constants.tokenToStableLiqFactor
        });

        oracleTokenToUsdArr[0] = address(oracleTokenToUsd);

        vm.startPrank(users.creatorAddress);
        erc20PricingModule_.addAsset(address(primaryToken), oracleTokenToUsdArr, riskVarsToken, type(uint128).max);
        middleErc4626PricingModule.addAsset(address(middleToken));
        upperErc4626PricingModule.addAsset(address(upperToken));
        vm.stopPrank();

        // Deploy an initial Account with all inputs to zero
        vm.startPrank(users.accountOwner);
        address proxyAddress = factory.createAccount(0, 0, address(0), address(0));
        proxyAccount = AccountV1(proxyAddress);

        // Approve tokens
        primaryToken.approve(proxyAddress, type(uint256).max);
        middleToken.approve(proxyAddress, type(uint256).max);
        upperToken.approve(proxyAddress, type(uint256).max);
        vm.stopPrank();

        // Label the deployed tokens
        vm.label({ account: address(primaryToken), newLabel: "primaryToken" });
        vm.label({ account: address(middleToken), newLabel: "middleToken" });
        vm.label({ account: address(upperToken), newLabel: "upperToken" });
        vm.label({ account: address(erc20PricingModule_), newLabel: "primaryErc20PricingModule" });
        vm.label({ account: address(middleErc4626PricingModule), newLabel: "middleErc4626PricingModule" });
        vm.label({ account: address(upperErc4626PricingModule), newLabel: "upperErc4626PricingModule" });
    }
    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function testGas_deposit_3Assets() public {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(primaryToken);
        assetAddresses[1] = address(middleToken);
        assetAddresses[2] = address(upperToken);

        uint256[] memory assetIds = new uint256[](3);

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 100 * 10 ** Constants.tokenDecimals;
        assetAmounts[1] = 10 * 10 ** Constants.tokenDecimals;
        assetAmounts[2] = 1 * 10 ** Constants.tokenDecimals;

        vm.prank(users.accountOwner);
        proxyAccount.deposit(assetAddresses, assetIds, assetAmounts);

        //vm.cool(address(oracleTokenToUsd));

        //proxyAccount.getAccountValue(address(0));
    }

    function testGas_deposit_1Asset() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(upperToken);

        uint256[] memory assetIds = new uint256[](1);

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1 * 10 ** Constants.tokenDecimals;

        vm.prank(users.accountOwner);
        proxyAccount.deposit(assetAddresses, assetIds, assetAmounts);

        proxyAccount.getAccountValue(address(0));
    }

    function testGas_withdraw() public {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(primaryToken);
        assetAddresses[1] = address(middleToken);
        assetAddresses[2] = address(upperToken);

        uint256[] memory assetIds = new uint256[](3);

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 100 * 10 ** Constants.tokenDecimals;
        assetAmounts[1] = 10 * 10 ** Constants.tokenDecimals;
        assetAmounts[2] = 1 * 10 ** Constants.tokenDecimals;

        vm.prank(users.accountOwner);
        proxyAccount.deposit(assetAddresses, assetIds, assetAmounts);

        vm.prank(users.accountOwner);
        proxyAccount.withdraw(assetAddresses, assetIds, assetAmounts);
    }

    function testGas_ChangingRate_Up() public {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(primaryToken);
        assetAddresses[1] = address(middleToken);
        assetAddresses[2] = address(upperToken);

        uint256[] memory assetIds = new uint256[](3);

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 100 * 10 ** Constants.tokenDecimals;
        assetAmounts[1] = 10 * 10 ** Constants.tokenDecimals;
        assetAmounts[2] = 1 * 10 ** Constants.tokenDecimals;

        vm.prank(users.accountOwner);
        proxyAccount.deposit(assetAddresses, assetIds, assetAmounts);

        vm.prank(users.tokenCreatorAddress);
        primaryToken.mint(address(middleToken), 11 * 10 ** Constants.tokenDecimals);

        assetAddresses = new address[](1);
        assetAddresses[0] = address(upperToken);

        assetIds = new uint256[](1);

        assetAmounts = new uint256[](1);

        vm.prank(users.accountOwner);
        proxyAccount.deposit(assetAddresses, assetIds, assetAmounts);
    }

    function testGas_ChangingRate_Down() public {
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(primaryToken);
        assetAddresses[1] = address(middleToken);
        assetAddresses[2] = address(upperToken);

        uint256[] memory assetIds = new uint256[](3);

        uint256[] memory assetAmounts = new uint256[](3);
        assetAmounts[0] = 100 * 10 ** Constants.tokenDecimals;
        assetAmounts[1] = 10 * 10 ** Constants.tokenDecimals;
        assetAmounts[2] = 1 * 10 ** Constants.tokenDecimals;

        vm.prank(users.accountOwner);
        proxyAccount.deposit(assetAddresses, assetIds, assetAmounts);

        vm.prank(address(upperToken));
        middleToken.transfer(users.accountOwner, 5 * 10 ** (Constants.tokenDecimals - 1));

        assetAddresses = new address[](1);
        assetAddresses[0] = address(upperToken);

        assetIds = new uint256[](1);

        assetAmounts = new uint256[](1);

        vm.prank(users.accountOwner);
        proxyAccount.deposit(assetAddresses, assetIds, assetAmounts);
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
