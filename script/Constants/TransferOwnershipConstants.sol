/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

library ArcadiaContractAddresses {
    // Todo: Update these addresses
    address public constant registry = address(0xd0690557600eb8Be8391D1d97346e2aab5300d5f);
    address public constant factory = address(0xDa14Fdd72345c4d2511357214c5B89A919768e59);
    address public constant erc20PrimaryAM = address(0xfBecEaFC96ed6fc800753d3eE6782b6F9a60Eed7);
    address public constant chainlinkOM = address(0x6a5485E3ce6913890ae5e8bDc08a868D432eEB31);
    address public constant uniswapV3AM = address(0x21bd524cC54CA78A7c48254d4676184f781667dC);
    address public constant stargateAM = address(0x20f7903290bF98716B62Dc1c9DA634291b8cfeD4);
    address public constant stakedStargateAM = address(0xae909e19fd13C01c28d5Ee439D403920CF7f9Eea);
}

library ArcadiaAddresses {
    address public constant owner = address(0xb4d72B1c91e640e4ED7d7397F3244De4D8ACc50B);
    address public constant guardian = address(0xEdD41f9740b06eCBfe1CE9194Ce2715C28263187);
}
