/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WETH9Fixture } from "../weth9/WETH9Fixture.f.sol";

import { ICLFactoryExtension } from "./extensions/interfaces/ICLFactoryExtension.sol";
import { INonfungiblePositionManagerExtension } from "./extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { Utils } from "../../../utils/Utils.sol";

contract SlipstreamFixture is WETH9Fixture {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    // Slipstream is a for of UniswapV3 -> use existing interfaces.
    ICLFactoryExtension internal cLFactory;
    INonfungiblePositionManagerExtension internal nonfungiblePositionManager;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        WETH9Fixture.setUp();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function deploySlipstream(address voter) internal {
        // Since Slipstream uses different a pragma version as us, we can't directly deploy the code
        // -> use getCode to get bytecode from artefacts and deploy directly.

        // Deploy CLPool.
        bytes memory args = abi.encode();
        bytes memory bytecode = abi.encodePacked(vm.getCode("CLPool.sol"), args);
        address cLPool_ = Utils.deployBytecode(bytecode);

        // Deploy the CLFactory.
        args = abi.encode(voter, cLPool_);
        bytecode = abi.encodePacked(vm.getCode("CLFactory.sol"), args);
        address cLFactory_ = Utils.deployBytecode(bytecode);
        cLFactory = ICLFactoryExtension(cLFactory_);

        // Deploy the NonfungiblePositionManager, pass zero address for the NonfungibleTokenPositionDescriptor.
        args = abi.encode(cLFactory_, address(weth9), address(0), "", "");
        bytecode = abi.encodePacked(vm.getCode("periphery/NonfungiblePositionManager.sol"), args);
        address nonfungiblePositionManager_ = Utils.deployBytecode(bytecode);
        nonfungiblePositionManager = INonfungiblePositionManagerExtension(nonfungiblePositionManager_);
    }
}
