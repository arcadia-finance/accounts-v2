/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

// interfaces
import { IERC20 } from "../../../../src/interfaces/IERC20.sol";

contract AerodromePoolMock {
    address public token0;
    address public token1;
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalSupply;

    mapping(address user => uint256 balance) public balanceOf;

    function tokens() public view returns (address, address) {
        return (token0, token1);
    }

    function setTotalSupply() public view returns (uint256) {
        return totalSupply;
    }

    function setReserves(uint256 reserve0_, uint256 reserve1_) public {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
    }

    function getReserves() public view returns (uint256, uint256, uint256) {
        return (reserve0, reserve1, 1);
    }

    function mint(uint256 amount0, uint256 amount1) public {
        balanceOf[msg.sender] = amount0 + amount1;
        reserve0 += amount0;
        reserve1 += amount1;
        totalSupply += amount0 + amount1;
    }

    function setTokens(address token0_, address token1_) public {
        token0 = token0_;
        token1 = token1_;
    }
}
