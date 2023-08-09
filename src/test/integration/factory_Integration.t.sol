/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test } from "../Base_IntegrationAndUnit.t.sol";
import { Vault } from "../../Vault.sol";
import "../utils/Constants.sol";

contract Factory_Integration_Test is Base_IntegrationAndUnit_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testFuzz_createVault_DeployVaultWithNoCreditor(uint256 salt) public {
        // We assume that salt > 0 as we already deployed a vault with all inputs to 0
        vm.assume(salt > 0);
        uint256 amountBefore = factory.allVaultsLength();

        vm.expectEmit();
        emit Transfer(address(0), address(this), amountBefore + 1);
        vm.expectEmit(false, true, true, true);
        emit VaultUpgraded(address(0), 0, 1);

        // Here we create a vault with no specific trusted creditor
        address actualDeployed = factory.createVault(salt, 0, address(0), address(0));

        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(actualDeployed, factory.allVaults(factory.allVaultsLength() - 1));
        assertEq(factory.vaultIndex(actualDeployed), (factory.allVaultsLength()));
        assertEq(Vault(actualDeployed).trustedCreditor(), address(0));
        assertEq(Vault(actualDeployed).isTrustedCreditorSet(), false);
        assertEq(Vault(actualDeployed).owner(), address(this));
    }

    function testFuzz_createVault_DeployVaultWithCreditor(uint256 salt) public {
        // We assume that salt > 0 as we already deployed a vault with all inputs to 0
        vm.assume(salt > 0);
        uint256 amountBefore = factory.allVaultsLength();

        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditorWithParamsInit), Constants.initLiquidator);
        vm.expectEmit();
        emit Transfer(address(0), address(this), amountBefore + 1);
        vm.expectEmit(false, true, true, true);
        emit VaultUpgraded(address(0), 0, 1);

        // Here we create a vault by specifying the trusted creditor address
        address actualDeployed = factory.createVault(salt, 0, address(0), address(trustedCreditorWithParamsInit));

        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(actualDeployed, factory.allVaults(factory.allVaultsLength() - 1));
        assertEq(factory.vaultIndex(actualDeployed), (factory.allVaultsLength()));
        assertEq(Vault(actualDeployed).trustedCreditor(), address(trustedCreditorWithParamsInit));
        assertEq(Vault(actualDeployed).isTrustedCreditorSet(), true);
    }

    function testFuzz_createVault_DeployNewProxyWithLogicOwner(uint256 salt, address sender) public {
        // We assume that salt > 0 as we already deployed a vault with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender != address(0));
        uint256 amountBefore = factory.allVaultsLength();
        vm.prank(sender);
        address actualDeployed = factory.createVault(salt, 0, address(0), address(0));
        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(Vault(actualDeployed).owner(), address(sender));
    }

    function testFuzz_createVault_CreationCannotBeFrontRunnedWithIdenticalSalt(
        uint256 salt,
        address sender0,
        address sender1
    ) public {
        // We assume that salt > 0 as we already deployed a vault with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender0 != sender1);
        vm.assume(sender0 != address(0));
        vm.assume(sender1 != address(0));

        //Broadcast changes the tx.origin, prank only changes the msg.sender, not tx.origin
        vm.broadcast(sender0);
        address proxy0 = factory.createVault(salt, 0, address(0), address(0));

        vm.broadcast(sender1);
        address proxy1 = factory.createVault(salt, 0, address(0), address(0));

        assertTrue(proxy0 != proxy1);
    }

    function testFuzz_Revert_createVault_CreateNonExistingVaultVersion(uint16 vaultVersion) public {
        uint256 currentVersion = factory.latestVaultVersion();
        vm.assume(vaultVersion > currentVersion);

        vm.expectRevert("FTRY_CV: Unknown vault version");
        factory.createVault(
            uint256(keccak256(abi.encodePacked(vaultVersion, block.timestamp))), vaultVersion, address(0), address(0)
        );
    }

    function testFuzz_Revert_createVault_FromBlockedVersion(
        uint16 vaultVersion,
        uint16 versionsToMake,
        uint16[] calldata versionsToBlock
    ) public {
        vm.assume(versionsToBlock.length < 10 && versionsToBlock.length > 0);
        vm.assume(uint256(versionsToMake) + 1 < type(uint16).max);
        vm.assume(vaultVersion <= versionsToMake + 1);
        for (uint256 i; i < versionsToMake; ++i) {
            vm.prank(users.creatorAddress);
            factory.setNewVaultInfo(address(mainRegistryExtension), address(vault), Constants.upgradeRoot1To2, "");
        }

        for (uint256 y; y < versionsToBlock.length; ++y) {
            if (versionsToBlock[y] == 0 || versionsToBlock[y] > factory.latestVaultVersion()) {
                continue;
            }
            vm.prank(users.creatorAddress);
            factory.blockVaultVersion(versionsToBlock[y]);
        }

        for (uint256 z; z < versionsToBlock.length; ++z) {
            if (versionsToBlock[z] == 0 || versionsToBlock[z] > factory.latestVaultVersion()) {
                continue;
            }
            vm.expectRevert("FTRY_CV: Vault version blocked");
            factory.createVault(
                uint256(keccak256(abi.encodePacked(versionsToBlock[z], block.timestamp))),
                versionsToBlock[z],
                address(0),
                address(0)
            );
        }
    }

    function testFuzz_Revert_createVault_Paused(uint256 salt, address sender, address guardian) public {
        // We assume that salt > 0 as we already deployed a vault with all inputs to 0
        vm.assume(salt > 0);
        vm.assume(sender != address(0));
        vm.assume(guardian != address(0));
        vm.assume(sender != guardian);

        // Given: variables and initialization
        vm.startPrank(users.creatorAddress);
        factory.changeGuardian(guardian);
        vm.stopPrank();
        vm.warp(35 days);

        // When: guardian pauses the contract
        vm.prank(guardian);
        factory.pause();

        // Then: Reverted
        vm.prank(sender);
        vm.expectRevert(FunctionIsPaused.selector);
        factory.createVault(salt, 0, address(0), address(0));
    }

    function test_isVault_positive() public {
        address newVault = factory.createVault(1, 0, address(0), address(0));

        bool expectedReturn = factory.isVault(address(newVault));
        bool actualReturn = true;

        assertEq(expectedReturn, actualReturn);
    }
}
