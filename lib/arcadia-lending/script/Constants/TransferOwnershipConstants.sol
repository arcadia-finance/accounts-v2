/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

library ArcadiaContractAddresses {
    // Todo: Update these addresses
    address public constant lendingPoolUSDC = address(0);
    address public constant lendingPoolWETH = address(0);
}

library ArcadiaAddresses {
    // Todo: Update these addresses
    address public constant multiSig1 = address(0);
    address public constant multiSig2 = address(0);
    address public constant multiSig3 = address(0);

    address public constant lendingPoolUSDCOwner = multiSig1;
    address public constant lendingPoolWETHOwner = multiSig1;
    address public constant guardian = multiSig2;
}
