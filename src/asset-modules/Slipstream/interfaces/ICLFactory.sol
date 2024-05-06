// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.22;

interface ICLFactory {
    function poolImplementation() external view returns (address);
}
