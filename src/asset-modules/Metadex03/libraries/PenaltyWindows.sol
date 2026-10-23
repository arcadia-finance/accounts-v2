/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

import { IMetadex03Gauge } from "../interfaces/IMetadex03Gauge.sol";

/**
 * @title Metadex03 Penalty Windows
 * @author Pragma Labs
 * @notice Tracks the early unstake penalty window of a Metadex03 gauge.
 */
library PenaltyWindows {
    /**
     * @notice Returns if a claim for an account would be haircut by the gauge's penalty.
     * @param gauge The contract address of the Metadex03 gauge.
     * @param account The address of the staker.
     * @return open Bool indicating if the penalty window is open.
     * @dev A zero depositBlock means the account holds no stake.
     */
    function isOpen(address gauge, address account) internal view returns (bool open) {
        if (IMetadex03Gauge(gauge).depositBlock(account) == 0) return false;

        open = IMetadex03Gauge(gauge).isPenaltyActive(account);
    }
}
