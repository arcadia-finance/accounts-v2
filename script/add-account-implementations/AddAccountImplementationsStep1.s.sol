/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuard } from "../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV3 } from "../../src/accounts/AccountV3.sol";
import { AccountV4 } from "../../src/accounts/AccountV4.sol";
import { ArcadiaAccounts, Deployers } from "../utils/constants/Shared.sol";
import { Base_Script } from "../Base.s.sol";
import { Merkl, Safes } from "../utils/constants/Base.sol";

contract AddAccountImplementationsStep1 is Base_Script {
    function run() public {
        require(vm.addr(deployer) == Deployers.ARCADIA, "Wrong deployer.");

        vm.startBroadcast(deployer);
        AccountsGuard accountsGuard = new AccountsGuard(Safes.OWNER, ArcadiaAccounts.FACTORY);
        new AccountV3(ArcadiaAccounts.FACTORY, address(accountsGuard), Merkl.DISTRIBUTOR);
        new AccountV4(ArcadiaAccounts.FACTORY, address(accountsGuard), Merkl.DISTRIBUTOR);
        vm.stopBroadcast();
    }
}
