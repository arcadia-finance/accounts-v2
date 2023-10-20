/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Test } from "../lib/forge-std/src/Test.sol";
import { ActionMultiCallV3 } from "../src/actions/MultiCallV3.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external;
}

/// @notice Base test contract with common logic needed by all tests.
contract quickTest is Test {
    ActionMultiCallV3 actionHandler;

    constructor() {
        actionHandler = new ActionMultiCallV3();
    }

    function test_lp_return() public {
        address weth = 0x4200000000000000000000000000000000000006;
        address cbeth = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
        address router = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;

        vm.prank(address(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf));
        IERC20(cbeth).transfer(address(this), 5 * 10 ** 18);
        IERC20(cbeth).approve(router, 5 * 10 ** 18);

        vm.prank(address(0xB4885Bc63399BF5518b994c1d0C153334Ee579D0));
        IERC20(weth).transfer(address(this), 5 * 10 ** 18);
        IERC20(weth).approve(router, 5 * 10 ** 18);

        bytes memory data =
            '\x881dV\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00*\xe3\xf1\xec\x7f\x1fP\x12\xcf\xea\xb0\x18[\xfcz\xa3\xcf\r\xec"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00B\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x06\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\xf4\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xe2\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\xca\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x07\xd1\xd44\x00\x00n~\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x083\xdd\xf5w\x94\x82\xd9\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x07Y\xb8\x1cff\xce@\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x07\xb5\xe0\x00V\xce)\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00+\xf4\x0e\xb0\x04\x05\xd6+\xdf;\xbe\xf7=\x80\xbf\xbc\xc5\xd0\xb3\xae\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00e);\xe1';

        // (bool success, bytes memory result) = router.call(data);

        // (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
        //     abi.decode(result, (uint256, uint128, uint256, uint256));

        // emit log_bytes(result);
        // emit log_named_uint("tokenId", tokenId);
        // emit log_named_uint("liquidity", liquidity);
        // emit log_named_uint("amount0", amount0);
        // emit log_named_uint("amount1", amount1);

        vm.prank(address(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf));
        IERC20(cbeth).transfer(address(actionHandler), 5 * 10 ** 18);
        vm.prank(address(actionHandler));
        IERC20(cbeth).approve(router, 5 * 10 ** 18);

        vm.prank(address(0xB4885Bc63399BF5518b994c1d0C153334Ee579D0));
        IERC20(weth).transfer(address(actionHandler), 5 * 10 ** 18);
        vm.prank(address(actionHandler));
        IERC20(weth).approve(router, 5 * 10 ** 18);

        actionHandler.mintLP(router, data);
    }
}
