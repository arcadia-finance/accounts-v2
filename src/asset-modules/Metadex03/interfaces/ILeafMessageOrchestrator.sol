// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILeafMessageOrchestrator {
    function ROOT_CHAIN_ID() external view returns (uint256);
    function adapter() external view returns (address);
}
