/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "addOracle" of contract "Registry".
 */
contract AddOracle_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addOracle_NonAssetModule(address unprivilegedAddress_) public {
        vm.assume(!registryExtension.isOracleModule(unprivilegedAddress_));

        vm.prank(users.creatorAddress);
        vm.expectRevert(RegistryErrors.OnlyOracleModule.selector);
        registryExtension.addOracle();
    }

    function testFuzz_Success_addOracle(address oracleModule_, uint256 oracleCounterLast) public {
        vm.assume(!registryExtension.isOracleModule(oracleModule_));
        vm.prank(users.creatorAddress);
        registryExtension.addOracleModule(oracleModule_);

        oracleCounterLast = bound(oracleCounterLast, 0, type(uint80).max);
        registryExtension.setOracleCounter(oracleCounterLast);

        vm.prank(oracleModule_);
        vm.expectEmit();
        emit OracleAdded(oracleCounterLast, oracleModule_);
        uint256 oracleId = registryExtension.addOracle();

        assertEq(oracleId, oracleCounterLast);
        assertEq(registryExtension.getOracleToOracleModule(oracleId), oracleModule_);
        assertEq(registryExtension.getOracleCounter(), oracleCounterLast + 1);
    }
}
