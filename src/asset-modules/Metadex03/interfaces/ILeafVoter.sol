// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILeafVoter {
    enum ChainStatus {
        None,
        Active,
        Paused,
        Suspended,
        Sunset
    }

    function chainStatus() external view returns (ChainStatus status);
    function EMISSIONS_HANDLER() external view returns (address);
    function FACTORY_REGISTRY() external view returns (address);
    function MIN_REDEEM_AMOUNT() external view returns (uint256);
    function ORCHESTRATOR() external view returns (address);
    function RECEIPT_TOKEN() external view returns (address);
}
