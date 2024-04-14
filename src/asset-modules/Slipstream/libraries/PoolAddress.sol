// https://github.com/velodrome-finance/slipstream/blob/main/contracts/periphery/libraries/PoolAddress.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.22;

import { ICLFactory } from "../interfaces/ICLFactory.sol";

/// @title Provides functions for deriving a pool address from the factory, tokens, and the tickSpacing
library PoolAddress {
    /// @notice The identifying key of the pool
    struct PoolKey {
        address token0;
        address token1;
        int24 tickSpacing;
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Slipstream factory contract address
    /// @param token0 Contract address of token0.
    /// @param token1 Contract address of token1.
    /// @param tickSpacing The tick spacing of the pool
    /// @return pool The contract address of the pool
    function computeAddress(address factory, address token0, address token1, int24 tickSpacing)
        internal
        view
        returns (address pool)
    {
        require(token0 < token1);
        pool = predictDeterministicAddress({
            master: ICLFactory(factory).poolImplementation(),
            salt: keccak256(abi.encode(token0, token1, tickSpacing)),
            deployer: factory
        });
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(address master, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, master))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000)
            mstore(add(ptr, 0x38), shl(0x60, deployer))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            predicted := keccak256(add(ptr, 0x37), 0x55)
        }
    }
}
