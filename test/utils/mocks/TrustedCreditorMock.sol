/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

contract TrustedCreditorMock {
    bool isCallSuccesfull = true;

    uint96 public fixedLiquidationCost;

    address public baseCurrency;
    address public liquidator;

    mapping(address => uint256) openPosition;

    constructor() { }

    function openMarginAccount(uint256)
        external
        view
        returns (bool success, address baseCurrency_, address liquidator_, uint256 fixedLiquidationCost_)
    {
        if (isCallSuccesfull) {
            success = true;
            baseCurrency_ = baseCurrency;
            liquidator_ = liquidator;
            fixedLiquidationCost_ = fixedLiquidationCost;
        } else {
            success = false;
            baseCurrency_ = address(0);
            liquidator_ = address(0);
            fixedLiquidationCost_ = 0;
        }
    }

    function getOpenPosition(address account) external view returns (uint256 openPosition_) {
        openPosition_ = openPosition[account];
    }

    function setOpenPosition(address account, uint256 openPosition_) external {
        openPosition[account] = openPosition_;
    }

    function setCallResult(bool success) external {
        isCallSuccesfull = success;
    }

    function setBaseCurrency(address baseCurrency_) external {
        baseCurrency = baseCurrency_;
    }

    function setLiquidator(address liquidator_) external {
        liquidator = liquidator_;
    }

    function setFixedLiquidationCost(uint96 fixedLiquidationCost_) external {
        fixedLiquidationCost = fixedLiquidationCost_;
    }
}
