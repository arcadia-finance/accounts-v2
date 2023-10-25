/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { ActionMultiCall } from "../../../../../src/actions/MultiCall.sol";

contract MultiCallExtention is ActionMultiCall {
    function assets() public view returns (address[] memory) {
        return _assets;
    }

    function ids() public view returns (uint256[] memory) {
        return _ids;
    }
}
