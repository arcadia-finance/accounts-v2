// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { IUniswapV3Pool } from "../../src/asset-modules/UniswapV3/interfaces/IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from
    "../../src/asset-modules/UniswapV3/interfaces/INonfungiblePositionManager.sol";

interface IUniswapV3PoolExtension is IUniswapV3Pool {
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;

    function maxLiquidityPerTick() external view returns (uint128 maxLiquidityPerTick);

    function token0() external view returns (address token0);

    function token1() external view returns (address token1);

    function fee() external view returns (uint24 fee);
}

interface INonfungiblePositionManagerExtension is INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        returns (address pool);

    function mint(MintParams calldata params)
        external
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        returns (uint256 amount0, uint256 amount1);
}

interface IPermit2 {
    /**
     * @notice The token and amount details for a transfer signed in the permit transfer signature
     */
    struct TokenPermissions {
        // ERC20 token address
        address token;
        // the maximum amount that can be spent
        uint256 amount;
    }

    /**
     * @notice Used to reconstruct the signed permit message for multiple token transfers
     * @dev Do not need to pass in spender address as it is required that it is msg.sender
     * @dev Note that a user still signs over a spender address
     */
    struct PermitBatchTransferFrom {
        // the tokens and corresponding amounts permitted for a transfer
        TokenPermissions[] permitted;
        // a unique value for every token owner's signature to prevent signature replays
        uint256 nonce;
        // deadline on the permit signature
        uint256 deadline;
    }

    /**
     * @notice Specifies the recipient address and amount for batched transfers.
     * @dev Recipients and amounts correspond to the index of the signed token permissions array.
     * @dev Reverts if the requested amount is greater than the permitted signed amount.
     */
    struct SignatureTransferDetails {
        // recipient address
        address to;
        // spender requested amount
        uint256 requestedAmount;
    }

    /**
     * @notice Transfers multiple tokens using a signed permit message
     * @param permit The permit data signed over by the owner
     * @param owner The owner of the tokens to transfer
     * @param transferDetails Specifies the recipient and requested amount for the token transfer
     * @param signature The signature to verify
     */
    function permitTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    /**
     * @notice Returns the domain separator for the current chain.
     * @dev Uses cached version if chainid and address are unchanged from construction.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
