/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

interface IMockSwapHook {
    function setFee(uint24 fee) external;
    function setShouldRevert(bool shouldRevert) external;
    function setReturnMalformed(bool returnMalformed) external;
}
