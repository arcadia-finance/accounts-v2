/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IAeroVoter {
    function isGauge(address) external returns (bool);
}
