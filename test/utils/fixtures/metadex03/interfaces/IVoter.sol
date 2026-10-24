// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVoter {
    error CeilingExceeded();

    struct Point {
        int128 bias;
        int128 slope;
        uint48 ts;
        uint128 permanentStakeBalance;
    }

    function chainStates(uint256 chainId)
        external
        view
        returns (
            Point memory point,
            uint256 ceiling,
            uint256 totalRedeemed,
            uint256 reportedSurplus,
            uint256 lastIndex,
            uint8 status
        );
    function grantRole(bytes32 role, address account) external;
    function registerChain(uint256 chainId) external;
}
