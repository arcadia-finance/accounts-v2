// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IERC721 {
    function ownerOf(uint256 id) external view returns (address);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function transferFrom(address from, address to, uint256 id) external;
}
