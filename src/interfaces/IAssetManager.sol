/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

interface IAssetManager {
    function onSetAssetManager(address owner, bool status, bytes calldata data) external;
}
