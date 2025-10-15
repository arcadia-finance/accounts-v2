/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccessControlManager } from "../../../../lib/merkl-contracts/contracts/AccessControlManager.sol";
import { DistributionCreator } from "../../../../lib/merkl-contracts/contracts/DistributionCreator.sol";
import { DistributorExtension } from "./extensions/DistributorExtension.sol";
import { ERC1967Proxy } from "../../../../lib/openzeppelin-contracts-v4.9/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IAccessControlManager } from "../../../../lib/merkl-contracts/contracts/interfaces/IAccessControlManager.sol";
import { ProxyAdmin } from "../../../../lib/openzeppelin-contracts-v4.9/contracts/proxy/transparent/ProxyAdmin.sol";
import { Test } from "../../../../lib/forge-std/src/Test.sol";
import {
    TransparentUpgradeableProxy
} from "../../../../lib/openzeppelin-contracts-v4.9/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MerklFixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccessControlManager internal accessControlManager;
    DistributionCreator internal distributionCreator;
    DistributorExtension internal distributor;
    ProxyAdmin internal proxyAdmin;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function deployMerkl(address owner) internal {
        // Deploy ProxyAdmin.
        proxyAdmin = new ProxyAdmin();
        proxyAdmin.transferOwnership(owner);

        // Deploy AccessControlManager.
        AccessControlManager implementation = new AccessControlManager();
        bytes memory initData = abi.encodeCall(AccessControlManager.initialize, (address(this), owner));
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(implementation), address(proxyAdmin), initData);
        accessControlManager = AccessControlManager(address(proxy));
        accessControlManager.addGovernor(owner);

        // Deploy Distributor.
        DistributorExtension implementation_ = new DistributorExtension();
        ERC1967Proxy proxy_ = new ERC1967Proxy(address(implementation_), "");
        distributor = DistributorExtension(address(proxy_));
        distributor.initialize(IAccessControlManager(address(accessControlManager)));

        // Deploy DistributionCreator.
        DistributionCreator implementation__ = new DistributionCreator();
        proxy_ = new ERC1967Proxy(address(implementation__), "");
        distributionCreator = DistributionCreator(address(proxy_));
        distributionCreator.initialize(
            IAccessControlManager(address(accessControlManager)),
            address(distributor),
            0.03 gwei // 0.03 gwei
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
}
