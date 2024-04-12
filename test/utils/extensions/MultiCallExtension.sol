/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ActionMultiCall } from "../../../src/actions/MultiCall.sol";

contract MultiCallExtension is ActionMultiCall {
    function assets() public view returns (address[] memory) {
        return mintedAssets;
    }

    function ids() public view returns (uint256[] memory) {
        return mintedIds;
    }

    function setMintedAssets(address[] memory mintedAssets_) public {
        mintedAssets = mintedAssets_;
    }

    function setMintedIds(uint256[] memory mintedIds_) public {
        mintedIds = mintedIds_;
    }
}
