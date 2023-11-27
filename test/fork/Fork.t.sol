/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Test } from "../Base.t.sol";

import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";

/**
 * @notice Common logic needed by all fork tests.
 * @dev Each function that interacts with an external and deployed contract, must be fork tested with the actual deployed bytecode of said contract.
 * @dev While not always possible (since unlike with the fuzz tests, it is not possible to work with extension with the necessary getters and setter),
 * as much of the possible state configurations must be tested.
 */
abstract contract Fork_Test is Base_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    ERC20 internal constant USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 internal constant DAI = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ERC20 internal constant WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    string internal RPC_URL = vm.envString("RPC_URL");

    /*///////////////////////////////////////////////////////////////
                            VARIABLES
    ///////////////////////////////////////////////////////////////*/

    uint256 internal fork;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        Base_Test.setUp();
    }
}
