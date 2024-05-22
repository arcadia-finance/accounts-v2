/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { MoonwellAM } from "../../../src/asset-modules/Moonwell/MoonwellAM.sol";

contract MoonwellAMExtension is MoonwellAM {
    constructor(
        address registry,
        string memory name_,
        string memory symbol_,
        address moonwellViews,
        address comptroller
    ) MoonwellAM(registry, name_, symbol_, moonwellViews, comptroller) { }

    function claimRewards(address asset, address[] memory) public {
        address[] memory emptyArr;
        _claimRewards(asset, emptyArr);
    }

    function getCurrentRewards(address asset, address[] memory rewards)
        public
        view
        returns (uint256[] memory currentRewards)
    {
        currentRewards = _getCurrentRewards(asset, rewards);
    }
}
