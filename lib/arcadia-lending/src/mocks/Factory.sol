/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./Vault.sol";

contract Factory {
    mapping(address => uint256) public vaultIndex;
    mapping(uint256 => address) public ownerOf;

    address[] public allVaults;

    constructor() { }

    function createVault(uint256 salt) external returns (address vault) {
        vault = address(
            new Vault{salt: bytes32(salt)}(
                msg.sender
            )
        );

        allVaults.push(vault);
        uint256 index = allVaults.length;
        vaultIndex[vault] = index;
        ownerOf[index] = msg.sender;
    }

    function isVault(address vault) public view returns (bool) {
        return vaultIndex[vault] > 0;
    }

    function ownerOfVault(address vault) public view returns (address owner_) {
        owner_ = ownerOf[vaultIndex[vault]];
    }
}
