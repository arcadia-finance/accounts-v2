/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity 0.8.22;

// interfaces
import { IERC20 } from "../../../../src/interfaces/IERC20.sol";

contract StargatePoolMock {
    IERC20 public token;
    uint256 public totalLiquidity;
    uint256 public totalSupply;
    uint256 public convertRate;
    // Lowest common decimals between chains

    function setState(address token_, uint256 totalLiquidity_, uint256 totalSupply_, uint256 convertRate_) public {
        token = IERC20(token_);
        totalLiquidity = totalLiquidity_;
        totalSupply = totalSupply_;
        convertRate = convertRate_;
    }

    function setToken(address _token) public {
        token = IERC20(_token);
    }
}
