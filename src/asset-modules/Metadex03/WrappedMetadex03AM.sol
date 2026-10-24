/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

import { IMetadex03Pool } from "./interfaces/IMetadex03Pool.sol";
import { WrappedAerodromeAM } from "../Aerodrome-Finance/WrappedAerodromeAM.sol";

/**
 * @title Asset Module for Wrapped Metadex03 pools
 * @author Pragma Labs
 * @notice The pricing logic and basic information for Wrapped Metadex03 Pools.
 */
contract WrappedMetadex03AM is WrappedAerodromeAM {
    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param owner_ The address of the Owner.
     * @param registry The address of the Registry.
     */
    constructor(address owner_, address registry) WrappedAerodromeAM(owner_, registry) { }

    /**
     * @inheritdoc WrappedAerodromeAM
     */
    function _tokenName() internal pure override returns (string memory name_) {
        name_ = "Arcadia Wrapped Metadex03 Positions";
    }

    /**
     * @inheritdoc WrappedAerodromeAM
     */
    function _tokenSymbol() internal pure override returns (string memory symbol_) {
        symbol_ = "aWMDEXP";
    }

    /* ///////////////////////////////////////////////////////////////
                     INTERACTIONS METADEX03 POOL
    /////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc WrappedAerodromeAM
     */
    function _claimFees(address pool) internal override returns (uint256 fee0, uint256 fee1) {
        (fee0, fee1) = IMetadex03Pool(pool).claimFees(address(this));
    }
}
