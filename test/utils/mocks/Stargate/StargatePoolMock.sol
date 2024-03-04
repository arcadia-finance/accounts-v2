/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { IERC20 } from "../../../../src/interfaces/IERC20.sol";
import { ERC20Mock } from "../tokens/ERC20Mock.sol";

contract StargatePoolMock is ERC20Mock {
    IERC20 public token;
    uint256 public totalLiquidity;
    uint256 public convertRate;

    constructor(uint8 decimals_) ERC20Mock("StargatePoolMock", "SPM", decimals_) { }

    function setState(address token_, uint256 totalLiquidity_, uint256 totalSupply_, uint256 convertRate_) public {
        token = IERC20(token_);
        totalLiquidity = totalLiquidity_;
        totalSupply = totalSupply_;
        convertRate = convertRate_;
    }

    function setToken(address _token) public {
        token = IERC20(_token);
    }

    function setConvertRate(uint256 convertRate_) public {
        convertRate = convertRate_;
    }

    function amountLPtoLD(uint256 _amountLP) external view returns (uint256) {
        return amountSDtoLD(_amountLPtoSD(_amountLP));
    }

    function _amountLPtoSD(uint256 _amountLP) internal view returns (uint256) {
        require(totalSupply > 0, "Stargate: cant convert LPtoSD when totalSupply == 0");
        return _amountLP * totalLiquidity / totalSupply;
    }

    function amountSDtoLD(uint256 _amount) internal view returns (uint256) {
        return _amount * convertRate;
    }
}
