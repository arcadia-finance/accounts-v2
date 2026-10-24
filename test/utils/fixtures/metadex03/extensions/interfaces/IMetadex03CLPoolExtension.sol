// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ICLPoolExtension } from "../../../slipstream/extensions/interfaces/ICLPoolExtension.sol";

interface IMetadex03CLPoolExtension is ICLPoolExtension {
    function settleToBlock() external returns (uint256 rollover);
}
