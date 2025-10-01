/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

interface IAeroVoter {
    function isGauge(address) external view returns (bool);
}
