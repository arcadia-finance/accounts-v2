/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

import { SlipstreamAM } from "../Slipstream/SlipstreamAM.sol";

/**
 * @title Asset Module for Metadex03 Concentrated Liquidity Positions
 * @author Pragma Labs
 * @notice The pricing logic and basic information for Metadex03 Concentrated Liquidity Positions.
 */
contract Metadex03CLAM is SlipstreamAM {
    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param owner_ The address of the Owner.
     * @param registry_ The contract address of the Registry.
     * @param nonFungiblePositionManager The contract address of the protocols NonFungiblePositionManager.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "2" for Metadex03 Liquidity Positions (ERC721).
     */
    constructor(address owner_, address registry_, address nonFungiblePositionManager)
        SlipstreamAM(owner_, registry_, nonFungiblePositionManager)
    { }
}
