/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

interface IWrappedStakedSlipstream {
    function AERO() external view returns (address);
    function CL_FACTORY() external view returns (address);
    function POSITION_MANAGER() external view returns (address);
    function approve(address spender, uint256 id) external;
    function balanceOf(address owner) external view returns (uint256);
    function baseURI() external view returns (string memory);
    function burn(uint256 positionId) external returns (uint256 rewards);
    function claimReward(uint256 positionId) external returns (uint256 rewards);
    function getApproved(uint256) external view returns (address);
    function idToGauge(uint256 id) external view returns (address gauge);
    function isApprovedForAll(address, address) external view returns (bool);
    function mint(uint256 positionId) external returns (uint256 positionId_);
    function name() external view returns (string memory);
    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4);
    function owner() external view returns (address);
    function ownerOf(uint256 id) external view returns (address owner);
    function rewardOf(uint256 positionId) external view returns (uint256 rewards);
    function safeTransferFrom(address from, address to, uint256 id) external;
    function safeTransferFrom(address from, address to, uint256 id, bytes memory data) external;
    function setApprovalForAll(address operator, bool approved) external;
    function setBaseURI(string memory newBaseURI) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory uri);
    function transferFrom(address from, address to, uint256 id) external;
    function transferOwnership(address newOwner) external;
}
