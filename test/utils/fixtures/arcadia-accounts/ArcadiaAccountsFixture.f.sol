/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Test } from "../../../Base.t.sol";

import { AccountV1 } from "../../../../src/accounts/AccountV1.sol";
import { ArcadiaOracle } from "../../mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { ChainlinkOMExtension } from "../../extensions/ChainlinkOMExtension.sol";
import { Constants } from "../../Constants.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC20Mock } from "../../mocks/tokens/ERC20Mock.sol";
import { ERC20PrimaryAMExtension } from "../../extensions/ERC20PrimaryAMExtension.sol";
import { Factory } from "../../../../src/Factory.sol";
import { RegistryExtension } from "../../extensions/RegistryExtension.sol";
import { SequencerUptimeOracle } from "../../mocks/oracles/SequencerUptimeOracle.sol";
import { Utils } from "../../Utils.sol";

contract ArcadiaAccountsFixture is Base_Test {
    function deployArcadiaAccounts() public {
        // Deploy the sequencer uptime oracle.
        vm.prank(users.oracleOwner);
        sequencerUptimeOracle = new SequencerUptimeOracle();

        // Deploy the base test contracts.
        vm.startPrank(users.owner);
        factory = new Factory();
        registry = new RegistryExtension(address(factory), address(sequencerUptimeOracle));
        chainlinkOM = new ChainlinkOMExtension(address(registry));
        erc20AM = new ERC20PrimaryAMExtension(address(registry));

        accountV1Logic = new AccountV1(address(factory));
        factory.setNewAccountInfo(address(registry), address(accountV1Logic), Constants.upgradeProof1To2, "");

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
        account = AccountV1(proxyAddress);

        // Label the base test contracts.
        vm.label({ account: address(factory), newLabel: "Factory" });
        vm.label({ account: address(registry), newLabel: "Registry" });
        vm.label({ account: address(chainlinkOM), newLabel: "Chainlink Oracle Module" });
        vm.label({ account: address(erc20AM), newLabel: "Standard ERC20 Asset Module" });
        vm.label({ account: address(accountV1Logic), newLabel: "Account V1 Logic" });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function initMockedOracle(string memory description, int256 price) public returns (address) {
        vm.startPrank(users.oracleOwner);
        ArcadiaOracle oracle = new ArcadiaOracle(18, description, address(0));
        oracle.setOffchainTransmitter(users.transmitter);
        vm.stopPrank();

        vm.prank(users.transmitter);
        oracle.transmit(price);

        return address(oracle);
    }

    function initAndAddAsset(string memory name, string memory symbol, uint8 decimals, int256 price)
        public
        returns (address)
    {
        vm.prank(users.tokenCreator);
        ERC20Mock asset = new ERC20Mock(name, symbol, decimals);

        AddAsset(address(asset), price);

        return address(asset);
    }

    function AddAsset(address asset, int256 price) public {
        address oracle = initMockedOracle(string.concat(ERC20(asset).name(), " / USD"), price);

        vm.startPrank(users.owner);
        chainlinkOM.addOracle(oracle, bytes16(bytes(ERC20(asset).name())), "USD", 2 days);

        uint80[] memory oracles = new uint80[](1);
        oracles[0] = uint80(chainlinkOM.oracleToOracleId(oracle));
        erc20AM.addAsset(asset, BitPackingLib.pack(BA_TO_QA_SINGLE, oracles));
        vm.stopPrank();
    }
}
