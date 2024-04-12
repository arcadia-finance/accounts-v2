/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FloorERC721AM } from "../mocks/asset-modules/FloorERC721AM.sol";

contract FloorERC721AMExtension is FloorERC721AM {
    constructor(address registry_) FloorERC721AM(registry_) { }

    function getIdRange(address asset) public view returns (uint256 start, uint256 end) {
        start = idRange[asset].start;
        end = idRange[asset].end;
    }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }
}
