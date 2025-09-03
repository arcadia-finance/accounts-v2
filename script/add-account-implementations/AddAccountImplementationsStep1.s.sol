/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.30;

import { AccountsGuard } from "../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV3 } from "../../src/accounts/AccountV3.sol";
import { AccountV4 } from "../../src/accounts/AccountV4.sol";
import { ArcadiaAccounts, Deployers } from "../utils/constants/Shared.sol";
import { Base_Script } from "../Base.s.sol";
import { Merkl, Safes } from "../utils/constants/Base.sol";
import { Utils } from "../../test/utils/Utils.sol";

contract AddAccountImplementationsStep1 is Base_Script {
    function run() public {
        require(vm.addr(deployer) == Deployers.ARCADIA, "Wrong deployer.");

        vm.startBroadcast(deployer);
        AccountsGuard accountsGuard = new AccountsGuard(Safes.OWNER, ArcadiaAccounts.FACTORY);
        new AccountV3(ArcadiaAccounts.FACTORY, address(accountsGuard), Merkl.DISTRIBUTOR);
        new AccountV4(ArcadiaAccounts.FACTORY, address(accountsGuard), Merkl.DISTRIBUTOR);
        vm.stopBroadcast();

        bytes32 leaf0 = keccak256(abi.encodePacked(uint256(1), uint256(3)));
        bytes32 leaf1 = keccak256(abi.encodePacked(uint256(2), uint256(4)));
        bytes32 root = Utils.commutativeKeccak256(leaf0, leaf1);
        emit log_bytes32(root);
    }
}
