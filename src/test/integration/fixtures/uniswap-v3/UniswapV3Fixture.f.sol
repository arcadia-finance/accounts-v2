/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Utils } from "../../../utils/Utils.sol";
import { WETH9Fixture } from "../weth9/WETH9Fixture.f.sol";

import { INonfungiblePositionManagerExtension } from
    "../../../../test_old/interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3Factory } from "../../../../test_old/interfaces/IUniswapV3Factory.sol";

contract UniswapV3Fixture is WETH9Fixture {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IUniswapV3Factory internal uniswapV3Factory;
    INonfungiblePositionManagerExtension internal nonfungiblePositionManager;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        WETH9Fixture.setUp();

        // Since Uniswap uses different a pragma version as us, we can't directly deploy the code
        // -> use getCode to get bytecode from artefacts and deploy directly.

        // Deploy the uniswapV3Factory.
        bytes memory args = abi.encode();
        bytes memory bytecode = abi.encodePacked(vm.getCode("UniswapV3FactoryExtension.sol"), args);
        address uniswapV3Factory_ = Utils.deployBytecode(bytecode);
        uniswapV3Factory = IUniswapV3Factory(uniswapV3Factory_);
        // Add fee 100 with tickspacing 1.
        uniswapV3Factory.enableFeeAmount(100, 1);

        // Get the bytecode of the UniswapV3PoolExtension.
        args = abi.encode();
        bytecode = abi.encodePacked(vm.getCode("UniswapV3PoolExtension.sol"), args);
        bytes32 poolExtensionInitCodeHash = keccak256(bytecode);

        // Get the bytecode of NonfungiblePositionManagerExtension, pass zero address for the NonfungibleTokenPositionDescriptor.
        args = abi.encode(uniswapV3Factory_, address(weth9), address(0));
        bytecode = abi.encodePacked(vm.getCode("NonfungiblePositionManagerExtension.sol"), args);

        // Overwrite constant in bytecode of NonfungiblePositionManager.
        // -> Replace the code hash of UniswapV3Pool.sol with the code hash of UniswapV3PoolExtension.sol
        bytes32 POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytecode = veryBadBytesReplacer(bytecode, POOL_INIT_CODE_HASH, poolExtensionInitCodeHash);

        // Deploy NonfungiblePositionManagerExtension with modified bytecode.
        address nonfungiblePositionManager_ = Utils.deployBytecode(bytecode);
        nonfungiblePositionManager = INonfungiblePositionManagerExtension(nonfungiblePositionManager_);
    }

    function veryBadBytesReplacer(bytes memory bytecode, bytes32 target, bytes32 replacement)
        internal
        returns (bytes memory result)
    {
        bytes memory target_ = abi.encodePacked(target);
        bytes memory replacement_ = abi.encodePacked(replacement);

        uint256 lengthTarget = target_.length;
        uint256 lengthBytecode = bytecode.length - lengthTarget + 1;
        uint256 i;
        for (i; i < lengthBytecode;) {
            uint256 j = 0;
            for (j; j < lengthTarget;) {
                if (bytecode[i + j] == target_[j]) {
                    if (j == lengthTarget - 1) {
                        emit log_string('check');
                        // Break loop
                        return result = replace(bytecode, replacement_, i);
                    }
                } else {
                    break;
                }
                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
        // Should always find one single match. -> revert if not.
        revert();
    }

    function replace(bytes memory bytecode, bytes memory replacement, uint256 startPosition)
        internal pure
        returns (bytes memory)
    {
        uint256 lengthReplacement = replacement.length;
        for (uint256 j; j < lengthReplacement;) {
            bytecode[startPosition + j] = replacement[j];

            unchecked {
                ++j;
            }
        }
        return bytecode;
    }
}
