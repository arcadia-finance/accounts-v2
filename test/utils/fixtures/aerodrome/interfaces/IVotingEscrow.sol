/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

interface IVotingEscrow {
    /// @notice Address of Protocol Team multisig
    function team() external view returns (address);
}
