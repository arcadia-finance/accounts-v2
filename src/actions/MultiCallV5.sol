/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { IERC20 } from "../interfaces/IERC20.sol";
import { IERC1155 } from "../interfaces/IERC1155.sol";
import { ERC721TokenReceiver } from "../../lib/solmate/src/tokens/ERC721.sol";
import { IActionBase, ActionData } from "../interfaces/IActionBase.sol";
import { IAeroAM } from "./interfaces/IAeroAM.sol";
import { IStakedSlipstreamAM } from "./interfaces/IStakedSlipstreamAM.sol";
import { INonfungiblePositionManagerSlip } from "./interfaces/INonFungiblePositionManagerSlip.sol";
import { INonfungiblePositionManager } from "./interfaces/INonFungiblePositionManager.sol";

/**
 * @title Generic Multicall action
 * @author Pragma Labs
 * @notice Calls any external contract with arbitrary data.
 * @dev Only calls are used, no delegatecalls.
 * @dev This address will approve random addresses. Do not store any funds on this address!
 */
contract ActionMultiCallV5 is IActionBase, ERC721TokenReceiver {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    address[] internal mintedAssets;
    uint256[] internal mintedIds;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error LengthMismatch();
    error InsufficientAmountOut();
    error OnlyInternal();
    error LeftoverNfts();

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event MultiCallExecuted(address account, uint16 actionType);

    /* //////////////////////////////////////////////////////////////
                            ACTION LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Calls a series of addresses with arbitrary calldata.
     * @param actionData A bytes object containing one actionData struct, an address array and a bytes array.
     * @return depositData The modified `ActionData` struct representing the final state of the `depositData` after executing the action.
     */
    function executeAction(bytes calldata actionData) external override returns (ActionData memory) {
        (ActionData memory depositData, address[] memory to, bytes[] memory data) =
            abi.decode(actionData, (ActionData, address[], bytes[]));

        uint256 callLength = to.length;
        if (callLength != data.length) revert LengthMismatch();

        for (uint256 i; i < callLength; ++i) {
            (bool success, bytes memory result) = to[i].call(data[i]);
            require(success, string(result));
        }

        for (uint256 i; i < depositData.assets.length; ++i) {
            if (depositData.assetTypes[i] == 1) {
                depositData.assetAmounts[i] = IERC20(depositData.assets[i]).balanceOf(address(this));
            } else if (depositData.assetTypes[i] == 2) {
                // If the amount is 0, we minted a new NFT.
                if (depositData.assetAmounts[i] == 0) {
                    depositData.assetAmounts[i] = 1;

                    // Start taking data from the minted arrays.
                    // We can overwrite address and ID from depositData.
                    // All assets with type == 2 and amount == 0 are stored in the minted arrays.
                    depositData.assetIds[i] = mintedIds[mintedIds.length - 1];
                    depositData.assets[i] = mintedAssets[mintedAssets.length - 1];
                    mintedIds.pop();
                    mintedAssets.pop();
                }
            } else if (depositData.assetTypes[i] == 3) {
                depositData.assetAmounts[i] =
                    IERC1155(depositData.assets[i]).balanceOf(address(this), depositData.assetIds[i]);
            }
        }

        // If any assets were minted and are left in this contract, revert.
        if (mintedIds.length > 0 || mintedAssets.length > 0) revert LeftoverNfts();

        return depositData;
    }

    /* //////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Repays an exact amount to a Creditor.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset that is being repaid.
     * @param account The contract address of the Account for which the debt is being repaid.
     * @param amount The amount of debt to repay.
     * @dev Can be called as one of the calls in executeAction, but fetches the actual contract balance after other DeFi interactions.
     */
    function executeRepay(address creditor, address asset, address account, uint256 amount) external {
        if (amount < 1) amount = IERC20(asset).balanceOf(address(this));

        (bool success, bytes memory data) =
            creditor.call(abi.encodeWithSignature("repay(uint256,address)", amount, account));
        require(success, string(data));
    }

    /**
     * @notice Checks the current balance of an asset and ensures it's larger than a required amount.
     * @param asset The token contract address of the asset that is being checked.
     * @param minAmountOut The amount of tokens this contract needs to hold at least to succeed.
     * @dev Can be called as one of the calls in executeAction.
     */
    function checkAmountOut(address asset, uint256 minAmountOut) external view {
        if (IERC20(asset).balanceOf(address(this)) < minAmountOut) revert InsufficientAmountOut();
    }

    /**
     * @notice Helper function to mint an LP token and return the ID for later usage.
     * @param to The contract address of the LP token.
     * @param data The data to call the lp contract with.
     * @dev Asset address and ID is temporarily stored in this contract.
     */
    function mintUniV3LP(address to, bytes memory data) external {
        if (msg.sender != address(this)) revert OnlyInternal();
        (bool success, bytes memory result) = to.call(data);
        require(success, string(result));

        (uint256 tokenId,,,) = abi.decode(result, (uint256, uint128, uint256, uint256));
        mintedAssets.push(to);
        mintedIds.push(tokenId);
    }

    struct MinimizedMintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
    }

    /**
     * @notice Helper function to mint an LP token with current balances
     * @param mintParams Part of the parameters needed for the mint.
     * @dev Asset address and ID is temporarily stored in this contract.
     */
    function mintUniV3LPWithConfig(MinimizedMintParams memory mintParams) external {
        if (msg.sender != address(this)) revert OnlyInternal();
        uint256 balance0 = IERC20(mintParams.token0).balanceOf(address(this));
        uint256 balance1 = IERC20(mintParams.token1).balanceOf(address(this));

        bytes memory data = abi.encodeWithSelector(
            INonfungiblePositionManager.mint.selector,
            INonfungiblePositionManager.MintParams({
                token0: mintParams.token0,
                token1: mintParams.token1,
                fee: mintParams.fee,
                tickLower: mintParams.tickLower,
                tickUpper: mintParams.tickUpper,
                amount0Desired: balance0,
                amount1Desired: balance1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        bytes memory callData =
            abi.encodeWithSelector(this.mintUniV3LP.selector, 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1, data);

        (bool success, bytes memory result) = address(this).call(callData);
        require(success, string(result));
    }

    /**
     * @notice Helper function to mint an LP token with current balances
     * @param mintParams Part of the parameters needed for the mint.
     * @param stakePosition Whether to stake the position or not.
     * @param wrapPosition Whether to wrap the position or not.
     * @dev Asset address and ID is temporarily stored in this contract.
     */
    function mintSlipLPWithConfig(MinimizedMintParams memory mintParams, bool stakePosition, bool wrapPosition)
        external
    {
        if (msg.sender != address(this)) revert OnlyInternal();
        uint256 balance0 = IERC20(mintParams.token0).balanceOf(address(this));
        uint256 balance1 = IERC20(mintParams.token1).balanceOf(address(this));

        bytes memory data = abi.encodeWithSelector(
            INonfungiblePositionManagerSlip.mint.selector,
            INonfungiblePositionManagerSlip.MintParams({
                token0: mintParams.token0,
                token1: mintParams.token1,
                tickSpacing: mintParams.tickSpacing,
                tickLower: mintParams.tickLower,
                tickUpper: mintParams.tickUpper,
                amount0Desired: balance0,
                amount1Desired: balance1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp,
                sqrtPriceX96: 0
            })
        );

        bytes memory callData;
        // use the normal slipstream NFT, unstaked
        if (!stakePosition) {
            callData =
                abi.encodeWithSelector(this.mintUniV3LP.selector, 0x827922686190790b37229fd06084350E74485b72, data);
            // use the StakedSlipstream Asset Module, staked
        } else if (stakePosition && !wrapPosition) {
            callData = abi.encodeWithSelector(
                this.mintSlipAndStake.selector,
                0x1Dc7A0f5336F52724B650E39174cfcbbEdD67bF1,
                0x827922686190790b37229fd06084350E74485b72,
                data
            );
            // use the WrappedStakedSlipstream wrapper, staked
        } else if (stakePosition && wrapPosition) {
            callData = abi.encodeWithSelector(
                this.mintSlipAndStake.selector,
                0xD74339e0F10fcE96894916B93E5Cc7dE89C98272,
                0x827922686190790b37229fd06084350E74485b72,
                data
            );
        }

        (bool success, bytes memory result) = address(this).call(callData);
        require(success, string(result));
    }

    /**
     * @notice Helper function to mint an LP token, stake and wrap it and return the ID for later usage.
     * @param assetModule The contract address of the Asset Module.
     * @param slipstreamNFT The contract address of the Slipstream NFT.
     * @param data The data to mint the Slipstream NFT with.
     * @dev Asset address and ID is temporarily stored in this contract.
     */
    function mintSlipAndStake(address assetModule, address slipstreamNFT, bytes memory data) external {
        if (msg.sender != address(this)) revert OnlyInternal();
        (bool success, bytes memory result) = slipstreamNFT.call(data);
        require(success, string(result));

        (uint256 tokenId,,,) = abi.decode(result, (uint256, uint128, uint256, uint256));

        uint256 stakedTokenId = IStakedSlipstreamAM(assetModule).mint(tokenId);

        mintedAssets.push(assetModule);
        mintedIds.push(stakedTokenId);
    }

    /**
     * @notice Helper function to stake or unstake an LP and return the ID for later usage.
     * @param assetModule The contract address of the Asset Module.
     * @param tokenId The token ID to (un)stake.
     * @param slipstreamNFT The contract address of the Slipstream NFT.
     * @param stake Whether to stake or to unstake.
     * @dev Asset address and ID is temporarily stored in this contract.
     */
    function StakeUnstakeSlip(address assetModule, uint256 tokenId, address slipstreamNFT, bool stake) external {
        if (msg.sender != address(this)) revert OnlyInternal();

        if (stake) {
            IStakedSlipstreamAM(assetModule).mint(tokenId);
            mintedAssets.push(assetModule);
        } else {
            IStakedSlipstreamAM(assetModule).burn(tokenId);
            mintedAssets.push(slipstreamNFT);
        }

        mintedIds.push(tokenId);
    }

    /**
     * @notice Helper function to wrap an Aerodrome LP token.
     * @param assetModule The contract address of the Aerodrome asset module.
     * @param pool The contract address of the Aerodrome Pool.
     * @param amount The amount of lp tokens to wrap.
     * @dev Asset address and ID is temporarily stored in this contract.
     */
    function mintAeroPosition(address assetModule, address pool, uint128 amount) external {
        if (msg.sender != address(this)) revert OnlyInternal();

        if (amount == 0) {
            amount = uint128(IERC20(pool).balanceOf(address(this)));
        }

        uint256 tokenId = IAeroAM(assetModule).mint(pool, amount);

        mintedAssets.push(assetModule);
        mintedIds.push(tokenId);
    }

    /**
     * @notice Helper function to wrap an Aerodrome LP token.
     * @param assetModule The contract address of the Staked Aerodrome/Slipstream asset module.
     * @param rewardToken The contract address of the reward token.
     * @param sendRewardsTo The address to send the rewards to.
     * @param id The id of the Staked Aerodrome/Slipstream LP token.
     */
    function claimAeroRewards(address assetModule, address rewardToken, address sendRewardsTo, uint256 id) external {
        if (msg.sender != address(this)) revert OnlyInternal();

        IStakedSlipstreamAM(assetModule).claimReward(id);
        IERC20(rewardToken).transfer(sendRewardsTo, IERC20(rewardToken).balanceOf(address(this)));
    }

    /**
     * @notice Emits an event to indicate that the MultiCall has been executed.
     * @param account The account that executed the MultiCall.
     * @param actionType The type of the action that was executed.
     */
    function emitMultiCallEvent(address account, uint16 actionType) external {
        emit MultiCallExecuted(account, actionType);
    }
}
