// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import { ISwapHook } from "../../../../lib/metadex-slipstream/contracts/core/interfaces/hook/ISwapHook.sol";

contract MockSwapHook is ISwapHook {
    uint24 public fee;
    bool public shouldRevert;
    bool public returnMalformed;

    function setFee(uint24 fee_) external {
        fee = fee_;
    }

    function setShouldRevert(bool shouldRevert_) external {
        shouldRevert = shouldRevert_;
    }

    function setReturnMalformed(bool returnMalformed_) external {
        returnMalformed = returnMalformed_;
    }

    function beforeSwap(SwapParams memory) external view override returns (uint24) {
        return _respond();
    }

    function afterSwap(SwapParams memory, AfterSwapParams memory) external view override returns (uint24) {
        return _respond();
    }

    function beforeFlash(FlashParams memory) external view override returns (uint24) {
        return _respond();
    }

    function getBeforeSwapFee(address, SwapParams memory) external view override returns (uint24) {
        return _respond();
    }

    function getAfterSwapFee(address, SwapParams memory, AfterSwapParams memory)
        external
        view
        override
        returns (uint24)
    {
        return _respond();
    }

    function getFlashFee(address, FlashParams memory) external view override returns (uint24) {
        return _respond();
    }

    function _respond() internal view returns (uint24) {
        if (shouldRevert) revert("HOOK");
        if (returnMalformed) {
            assembly {
                return(0, 1)
            }
        }
        return fee;
    }
}
