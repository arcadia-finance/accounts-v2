/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

contract Vault {
    address public owner;
    uint256 public totalValue;
    uint256 public lockedValue;
    address public baseCurrency;
    address public trustedCreditor;
    uint16 public vaultVersion;

    uint256 public mockToSurpressWarning;

    constructor(address _owner) payable {
        owner = _owner;
    }

    function setTotalValue(uint256 _totalValue) external {
        totalValue = _totalValue;
    }

    function setTrustedCreditor(address _trustedCreditor) external {
        trustedCreditor = _trustedCreditor;
    }

    function isVaultHealthy(uint256 amount, uint256 totalOpenDebt)
        external
        view
        returns (bool success, address _trustedCreditor, uint256 vaultVersion_)
    {
        if (amount != 0) {
            //Check if vault is still healthy after an increase of used margin.
            success = totalValue >= lockedValue + amount;
        } else {
            //Check if vault is healthy for a given amount of openDebt.
            success = totalValue >= totalOpenDebt;
        }

        return (success, trustedCreditor, vaultVersion);
    }

    function vaultManagementAction(address, bytes calldata) external returns (address, uint256) {
        mockToSurpressWarning = 1;
        return (trustedCreditor, vaultVersion);
    }
}
