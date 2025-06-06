/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { ArcadiaOracle } from "../utils/mocks/oracles/ArcadiaOracle.sol";
import { ERC20Mock } from "../utils/mocks/tokens/ERC20Mock.sol";
import { ERC721Mock } from "../utils/mocks/tokens/ERC721Mock.sol";
import { ERC1155Mock } from "../utils/mocks/tokens/ERC1155Mock.sol";

struct Users {
    address payable accountOwner;
    address payable guardian;
    address payable liquidityProvider;
    address payable oracleOwner;
    address payable owner;
    address payable riskManager;
    address payable swapper;
    address payable tokenCreator;
    address payable treasury;
    address payable transmitter;
    address payable unprivilegedAddress;
}

struct MockOracles {
    ArcadiaOracle stable1ToUsd;
    ArcadiaOracle stable2ToUsd;
    ArcadiaOracle token1ToUsd;
    ArcadiaOracle token2ToUsd;
    ArcadiaOracle token3ToToken4;
    ArcadiaOracle token4ToUsd;
    ArcadiaOracle nft1ToToken1;
    ArcadiaOracle nft2ToUsd;
    ArcadiaOracle nft3ToToken1;
    ArcadiaOracle sft1ToToken1;
    ArcadiaOracle sft2ToUsd;
}

struct MockERC20 {
    ERC20Mock stable1;
    ERC20Mock stable2;
    ERC20Mock token1;
    ERC20Mock token2;
    ERC20Mock token3;
    ERC20Mock token4;
}

struct MockERC721 {
    ERC721Mock nft1;
    ERC721Mock nft2;
    ERC721Mock nft3;
}

struct MockERC1155 {
    ERC1155Mock sft1;
    ERC1155Mock sft2;
}

struct Rates {
    uint256 stable1ToUsd;
    uint256 stable2ToUsd;
    uint256 token1ToUsd;
    uint256 token2ToUsd;
    uint256 token3ToToken4;
    uint256 token4ToUsd;
    uint256 nft1ToToken1;
    uint256 nft2ToUsd;
    uint256 nft3ToToken1;
    uint256 sft1ToToken1;
    uint256 sft2ToUsd;
}
