/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

library ArcadiaContractAddresses {
    // Todo: Update these addresses
    address public constant registry = address(0);
    address public constant factory = address(0);
    address public constant liquidator = address(0);
    address public constant riskModule = address(0);
    address public constant erc20PrimaryAM = address(0);
    address public constant chainlinkOM = address(0);
}

library ArcadiaAddresses {
    // Todo: Update these addresses
    address public constant multiSig1 = address(0);
    address public constant multiSig2 = address(0);
    address public constant multiSig3 = address(0);

    address public constant registryOwner = multiSig1;
    address public constant factoryOwner = multiSig1;
    address public constant liquidatorOwner = multiSig1;
    address public constant erc20PrimaryAMOwner = multiSig1;
    address public constant chainlinkOMOwner = multiSig1;
}
