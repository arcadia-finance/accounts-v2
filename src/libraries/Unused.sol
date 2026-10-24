/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

/**
 * @title Unused.
 * @author Pragma Labs
 * @notice Stand-in values for constructor arguments a contract inherits but does not use.
 */
library Unused {
    // For an inherited immutable the contract never reads.
    address internal constant IMMUTABLE = 0x000000000000000000000000000000000000dEaD;
}
