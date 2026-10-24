// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGaugeFactory {
    // forge-lint: disable-next-item(mixed-case-function)
    function IS_STABLE() external view returns (bool isStable);

    // forge-lint: disable-next-item(mixed-case-function)
    function LEAF_VOTER() external view returns (address leafVoter);
}
