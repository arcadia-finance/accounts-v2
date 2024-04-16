/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1 } from "../../../src/accounts/AccountV1.sol";

contract AccountV1Extension is AccountV1 {
    constructor(address factory) AccountV1(factory) { }

    function getLocked() external view returns (uint256 locked_) {
        locked_ = locked;
    }

    function setLocked(uint8 locked_) external {
        locked = locked_;
    }

    function setInAuction() external {
        inAuction = true;
    }

    function setLastActionTimestamp(uint32 lastActionTimestamp_) external {
        lastActionTimestamp = lastActionTimestamp_;
    }

    function getLengths() external view returns (uint256, uint256, uint256, uint256) {
        return (erc20Stored.length, erc721Stored.length, erc721TokenIds.length, erc1155Stored.length);
    }

    function setCreditor(address creditor_) public {
        creditor = creditor_;
    }

    function setMinimumMargin(uint96 minimumMargin_) public {
        minimumMargin = minimumMargin_;
    }

    function setOwner(address newOwner) public {
        owner = newOwner;
    }

    function setRegistry(address registry_) public {
        registry = registry_;
    }

    function getERC20Stored(uint256 index) public view returns (address) {
        return erc20Stored[index];
    }

    function getERC20Balances(address asset) public view returns (uint256) {
        return erc20Balances[asset];
    }

    function getERC721Stored(uint256 index) public view returns (address) {
        return erc721Stored[index];
    }

    function getERC721TokenIds(uint256 index) public view returns (uint256) {
        return erc721TokenIds[index];
    }

    function getERC1155Stored(uint256 index) public view returns (address) {
        return erc1155Stored[index];
    }

    function getERC1155TokenIds(uint256 index) public view returns (uint256) {
        return erc1155TokenIds[index];
    }

    function getERC1155Balances(address asset, uint256 assetId) public view returns (uint256) {
        return erc1155Balances[asset][assetId];
    }

    function getCoolDownPeriod() public pure returns (uint256 coolDownPeriod) {
        coolDownPeriod = COOL_DOWN_PERIOD;
    }
}
