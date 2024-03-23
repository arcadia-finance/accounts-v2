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
    // Todo: Update these addresses
    address public constant multiSig1 = address(0);
    address public constant multiSig2 = address(0);

    address public constant registryOwner = multiSig1;
    address public constant factoryOwner = multiSig1;
    address public constant erc20PrimaryAMOwner = multiSig1;
    address public constant chainlinkOMOwner = multiSig1;
    address public constant uniswapV3AMOwner = multiSig1;
    address public constant stargateAMOwner = multiSig1;
    address public constant stakedStargateAMOwner = multiSig1;

    address public constant guardian = multiSig2;
}
