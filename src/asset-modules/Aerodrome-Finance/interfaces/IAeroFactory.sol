/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

interface IAeroFactory {
    function isPool(address) external view returns (bool);
}
