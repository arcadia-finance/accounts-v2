/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Test } from "../../../Base.t.sol";

import { AccountV1 } from "../../../../src/accounts/AccountV1.sol";
import { AccountV2 } from "../../mocks/accounts/AccountV2.sol";
import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { ChainlinkOMExtension } from "../../extensions/ChainlinkOMExtension.sol";
import { Constants } from "../../Constants.sol";
import { ERC20PrimaryAMExtension } from "../../extensions/ERC20PrimaryAMExtension.sol";
import { ERC721TokenReceiver } from "../../../../lib/solmate/src/tokens/ERC721.sol";
import { Factory } from "../../../../src/Factory.sol";
import { FloorERC721AMExtension } from "../../extensions/FloorERC721AMExtension.sol";
import { FloorERC1155AMExtension } from "../../extensions/FloorERC1155AMExtension.sol";
import { RegistryExtension } from "../../extensions/RegistryExtension.sol";
import { SequencerUptimeOracle } from "../../mocks/oracles/SequencerUptimeOracle.sol";
import { Utils } from "../../Utils.sol";

contract ArcadiaAccountsFixture is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                  HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

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
        floorERC721AM = new FloorERC721AMExtension(address(registry));
        floorERC1155AM = new FloorERC1155AMExtension(address(registry));

        accountV1Logic = new AccountV1(address(factory));
        accountV2Logic = new AccountV2(address(factory));
        factory.setNewAccountInfo(address(registry), address(accountV1Logic), Constants.upgradeProof1To2, "");

        // Set the Guardians.
        vm.startPrank(users.owner);
        factory.changeGuardian(users.guardian);
        registry.changeGuardian(users.guardian);

        // Add Asset Modules to the Registry.
        vm.startPrank(users.owner);
        registry.addAssetModule(address(erc20AM));
        registry.addAssetModule(address(floorERC721AM));
        registry.addAssetModule(address(floorERC1155AM));
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
        vm.label({ account: address(floorERC721AM), newLabel: "ERC721 Asset Module" });
        vm.label({ account: address(floorERC1155AM), newLabel: "ERC1155 Asset Module" });
        vm.label({ account: address(accountV1Logic), newLabel: "Account V1 Logic" });
        vm.label({ account: address(accountV2Logic), newLabel: "Account V2 Logic" });
    }
}
