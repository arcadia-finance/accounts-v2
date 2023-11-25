/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AssetModule_Fuzz_Test } from "./_UniswapV2AssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "syncFee" of contract "UniswapV2AssetModule".
 */
contract SyncFee_UniswapV2AssetModule_Fuzz_Test is UniswapV2AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_syncFee_FeeOffToFeeOff(address sender) public {
        //Given: feeOn is false
        assertTrue(!uniswapV2AssetModule.feeOn());
        //And: feeTo on the UniswapV2 factory is the zero-address (fees are off)
        assertEq(uniswapV2Factory.feeTo(), address(0));

        //When: a random address calls syncFee()
        vm.prank(sender);
        uniswapV2AssetModule.syncFee();

        //Then: feeOn is false
        assertTrue(!uniswapV2AssetModule.feeOn());
    }

    function testFuzz_Success_syncFee_FeeOffToFeeOn(address sender, address feeTo) public {
        //Given: feeOn is false
        assertTrue(!uniswapV2AssetModule.feeOn());
        //And: feeTo on the UniswapV2 factory is not the zero-address (fees are on)
        vm.assume(feeTo != address(0));
        vm.prank(haydenAdams);
        uniswapV2Factory.setFeeTo(feeTo);

        //When: a random address calls syncFee()
        vm.prank(sender);
        uniswapV2AssetModule.syncFee();

        //Then: feeOn is true
        assertTrue(uniswapV2AssetModule.feeOn());
    }

    function testFuzz_Success_syncFee_FeeOnToFeeOn(address sender, address feeTo) public {
        //Given: feeTo on the UniswapV2 factory is not the zero-address (fees are on)
        vm.assume(feeTo != address(0));
        vm.prank(haydenAdams);
        uniswapV2Factory.setFeeTo(feeTo);
        //And: feeOn is true
        uniswapV2AssetModule.syncFee();
        assertTrue(uniswapV2AssetModule.feeOn());

        //When: a random address calls syncFee()
        vm.prank(sender);
        uniswapV2AssetModule.syncFee();

        //Then: feeOn is true
        assertTrue(uniswapV2AssetModule.feeOn());
    }

    function testFuzz_Success_syncFee_FeeOnToFeeOff(address sender, address feeTo) public {
        //Given: feeOn is true
        vm.assume(feeTo != address(0));
        vm.prank(haydenAdams);
        uniswapV2Factory.setFeeTo(feeTo);
        uniswapV2AssetModule.syncFee();
        assertTrue(uniswapV2AssetModule.feeOn());
        //And: feeTo on the UniswapV2 factory is the zero-address (fees are on)
        vm.prank(haydenAdams);
        uniswapV2Factory.setFeeTo(address(0));

        //When: a random address calls syncFee()
        vm.prank(sender);
        uniswapV2AssetModule.syncFee();

        //Then: feeOn is false
        assertTrue(!uniswapV2AssetModule.feeOn());
    }
}
