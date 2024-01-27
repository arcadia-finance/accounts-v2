/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

contract CreditorMock {
    bool isCallSuccesfull = true;

    uint96 public minimumMargin;

    address public numeraire;
    address public riskManager;
    address public liquidator;

    error OpenPositionNonZero();

    mapping(address => uint256) openPosition;

    constructor() { }

    function openMarginAccount(uint256)
        external
        view
        returns (bool success, address numeraire_, address liquidator_, uint256 minimumMargin_)
    {
        if (isCallSuccesfull) {
            success = true;
            numeraire_ = numeraire;
            liquidator_ = liquidator;
            minimumMargin_ = minimumMargin;
        } else {
            success = false;
            numeraire_ = address(0);
            liquidator_ = address(0);
            minimumMargin_ = 0;
        }
    }

    function closeMarginAccount(address account) external view {
        if (openPosition[account] != 0) revert OpenPositionNonZero();
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

    function setNumeraire(address numeraire_) external {
        numeraire = numeraire_;
    }

    function setRiskManager(address riskManager_) external {
        riskManager = riskManager_;
    }

    function setLiquidator(address liquidator_) external {
        liquidator = liquidator_;
    }

    function setMinimumMargin(uint96 minimumMargin_) external {
        minimumMargin = minimumMargin_;
    }

    function startLiquidation(address, uint256) external view returns (uint256 openPosition_) {
        openPosition_ = openPosition[msg.sender];
    }
}
