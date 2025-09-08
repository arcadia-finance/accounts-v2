/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

contract RevertingReceive {
    error TestError();

    /// forge-lint: disable-next-item(mixed-case-function)
    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {
        revert TestError();
    }
}
