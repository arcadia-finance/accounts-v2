/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { SpotToMarginMigrator } from "../../../src/accounts/helpers/SpotToMarginMigrator.sol";

contract SpotToMarginMigratorExtension is SpotToMarginMigrator {
    constructor(address factory) SpotToMarginMigrator(factory) { }

    function getOwnerOfAccount(address account) public view returns (address owner) {
        owner = accountToOwner[account];
    }
}
