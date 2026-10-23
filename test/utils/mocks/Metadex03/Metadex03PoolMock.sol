/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

contract Metadex03PoolMock {
    // forge-lint: disable-next-line(mixed-case-variable)
    bytes32 public POOL_TYPE;
    address internal token0;
    address internal token1;

    function setPoolType(bytes32 poolType) external {
        POOL_TYPE = poolType;
    }

    function setTokens(address token0_, address token1_) external {
        token0 = token0_;
        token1 = token1_;
    }

    function tokens() external view returns (address, address) {
        return (token0, token1);
    }
}
