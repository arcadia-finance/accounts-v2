/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { MultiCallV2_Fuzz_Test } from "./_MultiCallV2.fuzz.t.sol";

import { ERC20Mock } from "../../.././utils/mocks/tokens/ERC20Mock.sol";
import { AerodromeAMMock } from "../../.././utils/mocks/Aerodrome/AerodromeAMMock.sol";

/**
 * @notice Fuzz tests for the "mintUniV3LP" function of contract "MultiCall".
 */
contract MintAeroPosition_MultiCallV2_Fuzz_Test is MultiCallV2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    ERC20Mock poolMock;
    AerodromeAMMock aerodromeAMMock;

    uint24 fee = 300;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(MultiCallV2_Fuzz_Test) {
        MultiCallV2_Fuzz_Test.setUp();
        aerodromeAMMock = new AerodromeAMMock();
        poolMock = new ERC20Mock("Token 0", "TOK0", 18);
        poolMock.mint(address(action), 10 ** 22);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_mintAeroPosition_MintLP(uint128 amount) public {
        uint256 startBalance = poolMock.balanceOf(address(action));
        amount = uint128(bound(amount, 0, startBalance));

        vm.startPrank(address(action));
        poolMock.approve(address(aerodromeAMMock), amount > 0 ? amount : startBalance);
        action.mintAeroPosition(address(aerodromeAMMock), address(poolMock), amount);
        vm.stopPrank();

        uint256 tokenId = aerodromeAMMock.tokenId();
        address[] memory assetArr = new address[](1);
        assetArr[0] = address(aerodromeAMMock);
        uint256[] memory idArr = new uint256[](1);
        idArr[0] = tokenId;

        assertEq(action.assets(), assetArr);
        assertEq(action.ids(), idArr);

        if (amount > 0) {
            assertEq(poolMock.balanceOf(address(action)), startBalance - amount);
        } else {
            assertEq(poolMock.balanceOf(address(action)), 0);
        }
    }
}
