/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.22;

interface IAssetManager {
    function onSetAssetManager(address owner, bool status, bytes calldata data) external;
}
