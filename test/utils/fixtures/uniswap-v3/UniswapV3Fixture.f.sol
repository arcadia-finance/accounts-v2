/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WETH9Fixture } from "../weth9/WETH9Fixture.f.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { INonfungiblePositionManagerExtension } from "./extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3Factory } from "./extensions/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3PoolExtension } from "./extensions/interfaces/IUniswapV3PoolExtension.sol";
import { Utils } from "../../../utils/Utils.sol";

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
        bytecode = Utils.veryBadBytesReplacer(bytecode, POOL_INIT_CODE_HASH, poolExtensionInitCodeHash);

        // Deploy NonfungiblePositionManagerExtension with modified bytecode.
        address nonfungiblePositionManager_ = Utils.deployBytecode(bytecode);
        nonfungiblePositionManager = INonfungiblePositionManagerExtension(nonfungiblePositionManager_);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function createPool(address token0, address token1, uint24 fee, uint160 sqrtPriceX96, uint16 observationCardinality)
        public
        returns (IUniswapV3PoolExtension uniV3Pool_)
    {
        address poolAddress =
            nonfungiblePositionManager.createAndInitializePoolIfNecessary(token0, token1, fee, sqrtPriceX96);
        uniV3Pool_ = IUniswapV3PoolExtension(poolAddress);
        uniV3Pool_.increaseObservationCardinalityNext(observationCardinality);
    }

    function addLiquidity(
        IUniswapV3PoolExtension pool_,
        uint256 amount0,
        uint256 amount1,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper
    ) public returns (uint256 tokenId, uint256 amount0_, uint256 amount1_) {
        address token0 = pool_.token0();
        address token1 = pool_.token1();
        uint24 fee = pool_.fee();

        deal(token0, liquidityProvider_, amount0, true);
        deal(token1, liquidityProvider_, amount1, true);
        vm.startPrank(liquidityProvider_);
        ERC20(token0).approve(address(nonfungiblePositionManager), type(uint256).max);
        ERC20(token1).approve(address(nonfungiblePositionManager), type(uint256).max);
        (tokenId,, amount0_, amount1_) = nonfungiblePositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: liquidityProvider_,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();
    }
}
