/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Test } from "../Base.t.sol";

import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";

/**
 * @notice Common logic needed by all fork tests.
 * @dev Each function that interacts with an external and deployed contract, must be fork tested with the actual deployed bytecode of said contract.
 * @dev While not always possible (since unlike with the fuzz tests, it is not possible to work with extension with the necessary getters and setter),
 * as much of the possible state configurations must be tested.
 */
abstract contract Fork_Test is Base_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    ERC20 internal constant USDC = ERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    ERC20 internal constant USDBC = ERC20(0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA);
    ERC20 internal constant DAI = ERC20(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);
    ERC20 internal constant WETH = ERC20(0x4200000000000000000000000000000000000006);

    // The Chainlink USDC oracle on Base
    address oracleUSDC = 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B;
    // The Chainlink DAI oracle on Base
    address oracleDAI = 0x591e79239a7d679378eC8c847e5038150364C78F;
    // The Chainlink WETH oracle on Base
    address oracleETH = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;

    string internal RPC_URL = vm.envString("RPC_URL");

    /*///////////////////////////////////////////////////////////////
                            VARIABLES
    ///////////////////////////////////////////////////////////////*/

    uint256 internal fork;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        Base_Test.setUp();

        vm.startPrank(users.creatorAddress);
        // Add USDC to the protocol (same oracle will be used for USDBC).
        uint256 oracleId = chainlinkOM.addOracle(oracleUSDC, "USDC", "USD", 2 days);
        bool[] memory boolValues = new bool[](1);
        boolValues[0] = true;
        uint80[] memory uintValues = new uint80[](1);
        uintValues[0] = uint80(oracleId);
        bytes32 oracleSequence = BitPackingLib.pack(boolValues, uintValues);
        erc20AssetModule.addAsset(address(USDC), oracleSequence);
        erc20AssetModule.addAsset(address(USDBC), oracleSequence);

        // Add DAI to the protocol.
        oracleId = chainlinkOM.addOracle(oracleDAI, "DAI", "USD", 2 days);
        uintValues[0] = uint80(oracleId);
        oracleSequence = BitPackingLib.pack(boolValues, uintValues);
        erc20AssetModule.addAsset(address(DAI), oracleSequence);

        // Add WETH to the protocol.
        oracleId = chainlinkOM.addOracle(oracleETH, "WETH", "USD", 2 days);
        uintValues[0] = uint80(oracleId);
        oracleSequence = BitPackingLib.pack(boolValues, uintValues);
        erc20AssetModule.addAsset(address(WETH), oracleSequence);

        vm.stopPrank();

        vm.label({ account: address(USDC), newLabel: "USDC" });
        vm.label({ account: address(USDBC), newLabel: "USDBC" });
        vm.label({ account: address(DAI), newLabel: "DAI" });
        vm.label({ account: address(WETH), newLabel: "WETH" });
    }
}
