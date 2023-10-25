/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { ERC721 } from "../../../lib/solmate/src/tokens/ERC721.sol";

contract NonfungiblePositionManagerMock is ERC721 {
    uint256 public id;

    constructor() ERC721("Uniswap V3 Mock", "UNI-V3") { }

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

    function mint(MintParams memory params)
        public
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        _mint(params.recipient, (id++));

        return (id, 10 ** 18, 10 ** 18, 10 ** 18);
    }

    function factory() external pure returns (address) {
        return address(123);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return string("https://ipfs.io/ipfs/");
    }
}
