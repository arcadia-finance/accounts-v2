/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { StdCheats } from "forge-std/StdCheats.sol";
import { PricingModule, StandardERC20PricingModule } from "../PricingModules/StandardERC20PricingModule.sol";
import { FloorERC721PricingModule } from "../PricingModules/FloorERC721PricingModule.sol";
import { FloorERC1155PricingModule } from "../PricingModules/FloorERC1155PricingModule.sol";
import { LogExpMath } from "../utils/LogExpMath.sol";
import { Vault, ActionData } from "../Vault.sol";
import { RiskConstants } from "../utils/RiskConstants.sol";
import { Users, MockOracles, MockERC20, MockERC721, Rates } from "./utils/Types.sol";
import { Vm } from "../../lib/forge-std/src/Vm.sol";
import "../Factory.sol";
import "../Proxy.sol";
import "../mockups/ERC20SolmateMock.sol";
import "../mockups/ERC721SolmateMock.sol";
import "../mockups/ERC1155SolmateMock.sol";
import "../MainRegistry.sol";
import "../OracleHub.sol";
import "../mockups/ArcadiaOracle.sol";
import "./utils/Constants.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Global_Test is StdCheats {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        /// Deploy the base test contracts.

        // Label the base test contracts.

        // Create users for testing
        vm.startPrank(users.tokenCreatorAddress);
        
        users = Users({
            creatorAddress: createUser("creatorAddress"),
            tokenCreatorAddress: createUser("creatorAddress"),
            oracleOwner: createUser("oracleOwner"),
            unprivilegedAddress: createUser("unprivilegedAddress"),
            vaultOwner: createUser("vaultOwner"),
            liquidityProvider: createUser("liquidityProvider"),
            defaultCreatorAddress: createUser("defaultCreatorAddress"),
            defaultTransmitter: createUser("defaultTransmitter")
        });

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        return user;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/
}
