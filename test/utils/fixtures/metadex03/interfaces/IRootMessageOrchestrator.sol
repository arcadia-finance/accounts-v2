// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRootMessageOrchestrator {
    function setAdapter(uint256 chainId, address adapter) external;
}
