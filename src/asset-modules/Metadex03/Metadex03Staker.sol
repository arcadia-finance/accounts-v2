/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { IMetadex03Gauge } from "./interfaces/IMetadex03Gauge.sol";
import { SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title Metadex03 Staker
 * @author Pragma Labs
 * @notice Stakes the Metadex03 LP of a single position in its gauge.
 */
contract Metadex03Staker {
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the Asset Module that deploys the clones.
    address internal immutable ASSET_MODULE;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error OnlyAssetModule();

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Only the Asset Module can call functions with this modifier.
     */
    modifier onlyAssetModule() {
        if (msg.sender != ASSET_MODULE) revert OnlyAssetModule();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() {
        ASSET_MODULE = msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
                     INTERACTIONS STAKING CONTRACT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Approves the Asset Module to withdraw and claim, and the gauge to pull the Asset.
     * @param gauge The contract address of the gauge.
     * @param asset The contract address of the Asset.
     */
    function initialize(address gauge, address asset) external onlyAssetModule {
        IMetadex03Gauge(gauge).setApprovalForAll(ASSET_MODULE, true);
        IMetadex03Gauge(gauge).approveForClaim(ASSET_MODULE, true);
        ERC20(asset).approve(gauge, type(uint256).max);
    }

    /**
     * @notice Stakes an amount of Asset in the gauge.
     * @param gauge The contract address of the gauge.
     * @param amount The amount of Asset to stake.
     */
    function deposit(address gauge, uint256 amount) external onlyAssetModule {
        IMetadex03Gauge(gauge).deposit(amount);
    }

    /**
     * @notice Withdraws an amount of Asset from the gauge without claiming emissions, to the Asset Module.
     * @param gauge The contract address of the gauge.
     * @param asset The contract address of the Asset.
     * @param amount The amount of Asset to withdraw.
     */
    function emergencyWithdraw(address gauge, address asset, uint256 amount) external onlyAssetModule {
        IMetadex03Gauge(gauge).emergencyWithdraw(amount);
        // forge-lint: disable-next-item(solmate-safe-transfer-lib)
        ERC20(asset).safeTransfer(ASSET_MODULE, amount);
    }
}
