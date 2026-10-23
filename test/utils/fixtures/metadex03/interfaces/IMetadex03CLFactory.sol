// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03CLFactory {
    struct FeeTier {
        int24 tickSpacing;
        uint24 fee;
    }

    struct ConstructorParams {
        address owner;
        address swapFeeManager;
        address unstakedFeeManager;
        address voter;
        address poolImplementation;
        address positionManager;
        address factoryRegistry;
        address defaultSwapHook;
        address discountRegistryManager;
        address clPoolTapeManager;
        FeeTier[] initialFeeTiers;
    }

    function createPool(address tokenA, address tokenB, int24 tickSpacing, uint160 sqrtPriceX96)
        external
        returns (address pool);
    function getPool(address tokenA, address tokenB, int24 tickSpacing) external view returns (address pool);
    function poolImplementation() external view returns (address);
    function setPoolSwapHook(address[] calldata pools, address[] calldata swapHooks) external;
    function setDefaultSwapHook(address swapHook) external;
}
