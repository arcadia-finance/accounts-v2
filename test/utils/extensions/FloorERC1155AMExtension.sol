/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FloorERC1155AM } from "../mocks/asset-modules/FloorERC1155AM.sol";

contract FloorERC1155AMExtension is FloorERC1155AM {
    constructor(address owner_, address registry_) FloorERC1155AM(owner_, registry_) { }
}
