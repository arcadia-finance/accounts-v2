/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Test } from "../../../Base.t.sol";

import { AccountsGuardExtension } from "../../extensions/AccountsGuardExtension.sol";
import { AccountV3 } from "../../../../src/accounts/AccountV3.sol";
import { ArcadiaOracle } from "../../mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { ChainlinkOMExtension } from "../../extensions/ChainlinkOMExtension.sol";
import { Constants } from "../../Constants.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC20Mock } from "../../mocks/tokens/ERC20Mock.sol";
import { ERC20PrimaryAMExtension } from "../../extensions/ERC20PrimaryAMExtension.sol";
import { FactoryExtension } from "../../extensions/FactoryExtension.sol";
import { RegistryL2Extension } from "../../extensions/RegistryL2Extension.sol";
import { SequencerUptimeOracle } from "../../mocks/oracles/SequencerUptimeOracle.sol";
import { Utils } from "../../Utils.sol";

contract ArcadiaAccountsFixture is Base_Test {
    function deployArcadiaAccounts() public {
        // Deploy the sequencer uptime oracle.
        vm.prank(users.oracleOwner);
        sequencerUptimeOracle = new SequencerUptimeOracle();

        // Deploy the base test contracts.
        vm.startPrank(users.owner);
        factory = new FactoryExtension();
        registry = new RegistryL2Extension(address(factory), address(sequencerUptimeOracle));
        chainlinkOM = new ChainlinkOMExtension(address(registry));
        erc20AM = new ERC20PrimaryAMExtension(address(registry));

        accountsGuard = new AccountsGuardExtension(users.owner, address(factory));
        accountLogic = new AccountV3(address(factory), address(accountsGuard));
        factory.setLatestAccountVersion(2);
        factory.setNewAccountInfo(address(registry), address(accountLogic), Constants.upgradeRoot3To4And4To3, "");

        // Set the Guardians.
        vm.startPrank(users.owner);
        factory.changeGuardian(users.guardian);
        registry.changeGuardian(users.guardian);

        // Add Asset Modules to the Registry.
        vm.startPrank(users.owner);
        registry.addAssetModule(address(erc20AM));
        vm.stopPrank();

        // Add Oracle Modules to the Registry.
        vm.startPrank(users.owner);
        registry.addOracleModule(address(chainlinkOM));
        vm.stopPrank();

        // Deploy an initial Account with all inputs to zero
        vm.prank(users.accountOwner);
        address proxyAddress = factory.createAccount(0, 0, address(0));
        account = AccountV3(proxyAddress);

        // Label the base test contracts.
        vm.label({ account: address(factory), newLabel: "Factory" });
        vm.label({ account: address(registry), newLabel: "Registry" });
        vm.label({ account: address(chainlinkOM), newLabel: "Chainlink Oracle Module" });
        vm.label({ account: address(erc20AM), newLabel: "Standard ERC20 Asset Module" });
        vm.label({ account: address(accountLogic), newLabel: "Account Logic" });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    function initMockedOracle(string memory description, int256 price) internal returns (ArcadiaOracle oracle) {
        oracle = initMockedOracle(18, description, price);
    }

    function initMockedOracle(uint8 decimals, string memory description, uint256 price)
        public
        returns (ArcadiaOracle oracle)
    {
        oracle = initMockedOracle(decimals, description, int256(price));
    }

    function initMockedOracle(uint8 decimals, string memory description, int256 price)
        public
        returns (ArcadiaOracle oracle)
    {
        vm.startPrank(users.oracleOwner);
        oracle = new ArcadiaOracle(uint8(decimals), description);
        oracle.setOffchainTransmitter(users.transmitter);
        vm.stopPrank();

        vm.prank(users.transmitter);
        oracle.transmit(price);
    }

    function initAndAddAsset(string memory name, string memory symbol, uint8 decimals, int256 price)
        internal
        returns (address)
    {
        vm.prank(users.tokenCreator);
        ERC20Mock asset = new ERC20Mock(name, symbol, decimals);

        addAssetToArcadia(address(asset), price);

        return address(asset);
    }

    function addAssetToArcadia(address asset, int256 price) internal virtual {
        ArcadiaOracle oracle = initMockedOracle(string.concat(ERC20(asset).name(), " / USD"), price);

        vm.startPrank(users.owner);
        chainlinkOM.addOracle(address(oracle), bytes16(bytes(ERC20(asset).name())), "USD", 2 days);

        uint80[] memory oracles = new uint80[](1);
        oracles[0] = uint80(chainlinkOM.oracleToOracleId(address(oracle)));
        erc20AM.addAsset(asset, BitPackingLib.pack(BA_TO_QA_SINGLE, oracles));
        vm.stopPrank();
    }

    function depositERC20InAccount(AccountV3 account_, ERC20Mock token, uint256 amount) public {
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
}
