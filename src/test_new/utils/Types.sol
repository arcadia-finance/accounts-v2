/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../mockups/ArcadiaOracle.sol";
import "../../mockups/ERC20SolmateMock.sol";
import "../../mockups/ERC721SolmateMock.sol";

struct Users {
    address payable creatorAddress;
    address payable tokenCreatorAddress;
    address payable oracleOwner;
    address payable unprivilegedAddress;
    address payable vaultOwner;
    address payable liquidityProvider;
    address payable defaultCreatorAddress;
    address payable defaultTransmitter;
}

struct MockOracles {
    ArcadiaOracle stable1ToUsd;
    ArcadiaOracle stable2ToUsd;
    ArcadiaOracle token1ToUsd;
    ArcadiaOracle token2ToUsd;
    ArcadiaOracle token3ToUsd;
    ArcadiaOracle token4ToUsd;
    ArcadiaOracle nft1ToEth;
    ArcadiaOracle nft2ToEth;
    ArcadiaOracle nft3ToEth;
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

struct Rates {
    uint256 stable1ToUsd;
    uint256 stable2ToUsd;
    uint256 token1ToUsd;
    uint256 token2ToUsd;
    uint256 token3ToUsd;
    uint256 token4ToUsd;
    uint256 nft1ToETH;
    uint256 nft2ToETH;
    uint256 nft3ToETH;
}
