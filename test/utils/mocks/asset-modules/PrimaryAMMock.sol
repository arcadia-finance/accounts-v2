// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { PrimaryAMExtension } from "../../extensions/PrimaryAMExtension.sol";

contract PrimaryAMMock is PrimaryAMExtension {
    constructor(address owner_, address registry_, uint256 assetType_)
        PrimaryAMExtension(owner_, registry_, assetType_)
    { }

    function isAllowed(address asset, uint256) public view override returns (bool) {
        return inAssetModule[asset];
    }
}
