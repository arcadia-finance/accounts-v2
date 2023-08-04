/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { StdCheats } from "forge-std/StdCheats.sol";
import { PricingModule, StandardERC20PricingModule } from "../PricingModules/StandardERC20PricingModule.sol";
import { FloorERC721PricingModule } from "../PricingModules/FloorERC721PricingModule.sol";
import { FloorERC1155PricingModule } from "../PricingModules/FloorERC1155PricingModule.sol";
import { Liquidator, LogExpMath } from "../Liquidator.sol";
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
abstract contract Base_Test is StdCheats {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Users internal users;
    MockOracles internal mockOracles;
    MockERC20 internal mockERC20;
    MockERC721 internal mockNFT;
    Rates internal rates;
    Factory public factory;
    Vault public vault;
    Vault public proxy;
    address public proxyAddr;
    ERC1155Mock public interleave;
    OracleHub public oracleHub;
    StandardERC20PricingModule public standardERC20PricingModule;
    FloorERC721PricingModule public floorERC721PricingModule;
    FloorERC1155PricingModule public floorERC1155PricingModule;
    Liquidator public liquidator;

    uint16 public collateralFactor = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    uint16 public liquidationFactor = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;

    PricingModule.RiskVarInput[] emptyRiskVarInput;
    PricingModule.RiskVarInput[] riskVars;

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

        // Create oracles for testing
        mockOracles = MockOracles({
            stable1ToUsd: initMockedOracle(uint8(Constants.stableOracleDecimals), "STABLE1 / USD"),
            stable2ToUsd: initMockedOracle(uint8(Constants.stableOracleDecimals), "STABLE2 / USD"),
            token1ToUsd: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN1 / USD"),
            token2ToUsd: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN2 / USD"),
            token3ToUsd: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN1 / USD"),
            token4ToUsd: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN2 / USD"),
            nft1ToEth: initMockedOracle(uint8(Constants.nftOracleDecimals), "NFT1 / ETH"),
            nft2ToEth: initMockedOracle(uint8(Constants.nftOracleDecimals), "NFT2 / ETH"),
            nft3ToEth: initMockedOracle(uint8(Constants.nftOracleDecimals), "NFT3 / ETH")
        });

        // Create mock ERC20 tokens for testing
        mockERC20 = MockERC20({
            stable1: new ERC20Mock("STABLE1", "S1", uint8(Constants.stableDecimals)),
            stable2: new ERC20Mock("STABLE2", "S2", uint8(Constants.stableDecimals)),
            token1: new ERC20Mock("TOKEN1", "T1", uint8(Constants.tokenDecimals)),
            token2: new ERC20Mock("TOKEN2", "T2", uint8(Constants.tokenDecimals)),
            token3: new ERC20Mock("TOKEN3", "T3", uint8(Constants.tokenDecimals)),
            token4: new ERC20Mock("TOKEN4", "T4", uint8(Constants.tokenDecimals))
        });

        // Create mock ERC721 tokens for testing
        mockNFT = MockERC721({
            nft1: new ERC721Mock("NFT1", "NFT1"),
            nft2: new ERC721Mock("NFT2", "NFT2"),
            nft3: new ERC721Mock("NFT3", "NFT3")
        });

        // Set rates
        rates = Rates({
            stable1ToUsd: 1 * 10 ** Constants.stableOracleDecimals,
            stable2ToUsd: 1 * 10 ** Constants.stableOracleDecimals,
            token1ToUsd: 6000 * 10 ** Constants.tokenOracleDecimals,
            token2ToUsd: 50 * 10 ** Constants.tokenOracleDecimals,
            token3ToUsd: 4 * 10 ** Constants.tokenOracleDecimals,
            token4ToUsd: 3 * 10 ** (Constants.tokenOracleDecimals - 2),
            nft1ToETH: 50 * 10 ** Constants.nftOracleDecimals,
            nft2ToETH: 7 * 10 ** Constants.nftOracleDecimals,
            nft3ToETH: 1 * 10 ** (Constants.nftOracleDecimals - 1)
        });

        // Mint tokens
        mockERC20.stable1.mint(users.liquidityProvider, 10_000_000 * 10 ** Constants.stableDecimals);
        mockERC20.stable2.mint(users.tokenCreatorAddress, 200_000 * 10 ** Constants.stableDecimals);
        mockERC20.token1.mint(users.tokenCreatorAddress, 200_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token2.mint(users.tokenCreatorAddress, 200_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token3.mint(users.tokenCreatorAddress, 200_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token4.mint(users.tokenCreatorAddress, 200_000 * 10 ** Constants.tokenDecimals);

        for (uint8 i = 0; i <= 5; i++) {
            mockNFT.nft1.mint(users.tokenCreatorAddress, i);
            mockNFT.nft2.mint(users.tokenCreatorAddress, i);
            mockNFT.nft3.mint(users.tokenCreatorAddress, i);
        }

        // Transfer tokens
        mockERC20.stable1.transfer(users.vaultOwner, 100_000 * 10 ** Constants.stableDecimals);
        mockERC20.stable2.transfer(users.vaultOwner, 100_000 * 10 ** Constants.stableDecimals);
        mockERC20.token1.transfer(users.vaultOwner, 100_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token2.transfer(users.vaultOwner, 100_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token3.transfer(users.vaultOwner, 100_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token4.transfer(users.vaultOwner, 100_000 * 10 ** Constants.tokenDecimals);

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

    function initOracle(uint8 decimals, string memory description, address asset_address)
        public
        returns (ArcadiaOracle)
    {
        vm.startPrank(users.defaultCreatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(
            uint8(decimals),
            description,
            asset_address
        );
        oracle.setOffchainTransmitter(users.defaultTransmitter);
        vm.stopPrank();
        return oracle;
    }

    function initOracle(
        address creatorAddress,
        uint8 decimals,
        string memory description,
        address asset_address,
        address transmitterAddress
    ) public returns (ArcadiaOracle) {
        vm.startPrank(creatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(
            uint8(decimals),
            description,
            asset_address
        );
        oracle.setOffchainTransmitter(transmitterAddress);
        vm.stopPrank();
        return oracle;
    }

    function initMockedOracle(uint8 decimals, string memory description, uint256 answer)
        public
        returns (ArcadiaOracle)
    {
        vm.startPrank(users.defaultCreatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(
            uint8(decimals),
            description,
            address(73)
        );
        oracle.setOffchainTransmitter(users.defaultTransmitter);
        vm.stopPrank();
        vm.startPrank(users.defaultTransmitter);
        int256 convertedAnswer = int256(answer);
        oracle.transmit(convertedAnswer);
        vm.stopPrank();
        return oracle;
    }

    function initMockedOracle(uint8 decimals, string memory description) public returns (ArcadiaOracle) {
        vm.startPrank(users.defaultCreatorAddress);
        ArcadiaOracle oracle = new ArcadiaOracle(
            uint8(decimals),
            description,
            address(73)
        );
        oracle.setOffchainTransmitter(users.defaultTransmitter);
        vm.stopPrank();
        return oracle;
    }

    function transmitOracle(ArcadiaOracle oracle, int256 answer, address transmitter) public {
        vm.startPrank(transmitter);
        oracle.transmit(answer);
        vm.stopPrank();
    }

    function transmitOracle(ArcadiaOracle oracle, int256 answer) public {
        vm.startPrank(users.defaultTransmitter);
        oracle.transmit(answer);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/
}
