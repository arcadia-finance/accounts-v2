/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

// interfaces
import { IERC20 } from "../../../../src/interfaces/IERC20.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";

contract AerodromePoolMock is ERC20Mock {
    address public token0;
    address public token1;
    uint256 public reserve0;
    uint256 public reserve1;

    constructor() ERC20Mock("", "", 18) { }

    function tokens() public view returns (address, address) {
        return (token0, token1);
    }

    function setReserves(uint256 reserve0_, uint256 reserve1_) public {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
    }

    function getReserves() public view returns (uint256, uint256, uint256) {
        return (reserve0, reserve1, 1);
    }

    function setTokens(address token0_, address token1_) public {
        token0 = token0_;
        token1 = token1_;
    }
}
