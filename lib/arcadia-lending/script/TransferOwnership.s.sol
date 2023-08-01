/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { ArcadiaAddresses, ArcadiaContractAddresses } from "./Constants/TransferOwnershipConstants.sol";
import "../lib/forge-std/src/Script.sol";
import "../src/LendingPool.sol";

contract ArcadiaLendingTransferOwnership is Script {
    LendingPool public lendingPoolUSDC;
    LendingPool public lendingPoolWETH;

    constructor() {
        lendingPoolUSDC = LendingPool(ArcadiaContractAddresses.lendingPoolUSDC);
        lendingPoolWETH = LendingPool(ArcadiaContractAddresses.lendingPoolWETH);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);
        // Transfer ownership to respected addresses
        lendingPoolUSDC.transferOwnership(ArcadiaAddresses.lendingPoolUSDCOwner);
        lendingPoolWETH.transferOwnership(ArcadiaAddresses.lendingPoolWETHOwner);

        // Set guardian
        lendingPoolUSDC.changeGuardian(ArcadiaAddresses.guardian);
        lendingPoolWETH.changeGuardian(ArcadiaAddresses.guardian);

        vm.stopBroadcast();
    }
}
