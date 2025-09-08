/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address, address, uint256) external;
}

contract AerodromeAMMock {
    uint256 public tokenId;

    function mint(address pool, uint128 amount) external returns (uint256 _tokenId) {
        /// forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(pool).transferFrom(msg.sender, address(this), amount);
        return ++tokenId;
    }

    function burn(uint256) external {
        tokenId = tokenId; // prevent view function warnings
    }
}
