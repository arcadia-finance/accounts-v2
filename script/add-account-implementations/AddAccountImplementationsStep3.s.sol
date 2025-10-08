/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Base_Script } from "../Base.s.sol";
import { Safes } from "../utils/constants/Shared.sol";

contract AddAccountImplementationsStep3 is Base_Script {
    /// forge-lint: disable-next-line(mixed-case-variable)
    address internal SAFE = Safes.OWNER;

    function run() public {
        // Block Account versions 1 and 2.
        addToBatch(SAFE, address(factory), abi.encodeCall(factory.blockAccountVersion, (1)));
        addToBatch(SAFE, address(factory), abi.encodeCall(factory.blockAccountVersion, (2)));

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }
}
