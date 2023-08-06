/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_Global_Test } from "./Base_Global.t.sol";
import { MockOracles, MockERC20, MockERC721, MockERC1155, Rates } from "./utils/Types.sol";
import "../Proxy.sol";
import "../mockups/ERC20SolmateMock.sol";
import "../mockups/ERC721SolmateMock.sol";
import "../mockups/ERC1155SolmateMock.sol";
import "../OracleHub.sol";
import "../mockups/ArcadiaOracle.sol";
import "./utils/Constants.sol";

/// @notice Common logic needed by all integration tests.
abstract contract Base_IntegrationAndUnit_Test is Base_Global_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    MockOracles internal mockOracles;
    MockERC20 internal mockERC20;
    MockERC721 internal mockERC721;
    MockERC1155 internal mockERC1155;
    Rates internal rates;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Global_Test.setUp();

        // Create mock ERC20 tokens for testing
        vm.startPrank(users.tokenCreatorAddress);

        mockERC20 = MockERC20({
            stable1: new ERC20Mock("STABLE1", "S1", uint8(Constants.stableDecimals)),
            stable2: new ERC20Mock("STABLE2", "S2", uint8(Constants.stableDecimals)),
            token1: new ERC20Mock("TOKEN1", "T1", uint8(Constants.tokenDecimals)),
            token2: new ERC20Mock("TOKEN2", "T2", uint8(Constants.tokenDecimals)),
            token3: new ERC20Mock("TOKEN3", "T3", uint8(Constants.tokenDecimals)),
            token4: new ERC20Mock("TOKEN4", "T4", uint8(Constants.tokenDecimals))
        });

        // Create mock ERC721 tokens for testing
        mockERC721 = MockERC721({
            nft1: new ERC721Mock("NFT1", "NFT1"),
            nft2: new ERC721Mock("NFT2", "NFT2"),
            nft3: new ERC721Mock("NFT3", "NFT3")
        });

        // Create a mock ERC1155 token for testing
        mockERC1155 = MockERC1155({ erc1155: new ERC1155Mock("ERC1155", "1155") });

        // Label the deployed tokens
        vm.label({ account: address(mockERC20.stable1), newLabel: "STABLE1" });
        vm.label({ account: address(mockERC20.stable2), newLabel: "STABLE2" });
        vm.label({ account: address(mockERC20.token1), newLabel: "TOKEN1" });
        vm.label({ account: address(mockERC20.token2), newLabel: "TOKEN2" });
        vm.label({ account: address(mockERC20.token3), newLabel: "TOKEN3" });
        vm.label({ account: address(mockERC20.token3), newLabel: "TOKEN4" });
        vm.label({ account: address(mockERC721.nft1), newLabel: "NFT1" });
        vm.label({ account: address(mockERC721.nft2), newLabel: "NFT2" });
        vm.label({ account: address(mockERC721.nft3), newLabel: "NFT3" });
        vm.label({ account: address(mockERC1155.erc1155), newLabel: "ERC1155" });

        // Set rates
        rates = Rates({
            stable1ToUsd: 1 * 10 ** Constants.stableOracleDecimals,
            stable2ToUsd: 1 * 10 ** Constants.stableOracleDecimals,
            token1ToUsd: 6000 * 10 ** Constants.tokenOracleDecimals,
            token2ToUsd: 50 * 10 ** Constants.tokenOracleDecimals,
            token3ToToken1: 4 * 10 ** Constants.tokenOracleDecimals,
            token4ToUsd: 3 * 10 ** (Constants.tokenOracleDecimals - 2),
            nft1ToToken1: 50 * 10 ** Constants.nftOracleDecimals,
            nft2ToUsd: 7 * 10 ** Constants.nftOracleDecimals,
            nft3ToToken1: 1 * 10 ** (Constants.nftOracleDecimals - 1),
            erc1155ToToken1: 1 * 10 ** (Constants.erc1155OracleDecimals - 2)
        });

        // Mint tokens
        // Mint STABLE1 to Liquidity Provider
        mockERC20.stable1.mint(users.liquidityProvider, 10_000_000 * 10 ** Constants.stableDecimals);
        // Mint next tokens to tokenCreatorAddress
        mockERC20.stable2.mint(users.tokenCreatorAddress, 200_000 * 10 ** Constants.stableDecimals);
        mockERC20.token1.mint(users.tokenCreatorAddress, 200_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token2.mint(users.tokenCreatorAddress, 200_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token3.mint(users.tokenCreatorAddress, 200_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token4.mint(users.tokenCreatorAddress, 200_000 * 10 ** Constants.tokenDecimals);

        for (uint8 i = 0; i <= 5; i++) {
            mockERC721.nft1.mint(users.tokenCreatorAddress, i);
            mockERC721.nft2.mint(users.tokenCreatorAddress, i);
            mockERC721.nft3.mint(users.tokenCreatorAddress, i);
        }

        mockERC1155.erc1155.mint(users.tokenCreatorAddress, 1, 100_000);

        // Transfer tokens
        mockERC20.stable2.transfer(users.vaultOwner, 100_000 * 10 ** Constants.stableDecimals);
        mockERC20.token1.transfer(users.vaultOwner, 100_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token2.transfer(users.vaultOwner, 100_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token3.transfer(users.vaultOwner, 100_000 * 10 ** Constants.tokenDecimals);
        mockERC20.token4.transfer(users.vaultOwner, 100_000 * 10 ** Constants.tokenDecimals);

        // Transfer mock ERC20 token to the unprivileged address
        mockERC20.token1.transfer(users.unprivilegedAddress, 1000 * 10 ** Constants.tokenDecimals);

        // Transfer 3 first token ID's from each ERC721 contract to the vaultOwner
        for (uint8 i = 0; i <= 2; i++) {
            mockERC721.nft1.transferFrom(users.tokenCreatorAddress, users.vaultOwner, i);
            mockERC721.nft2.transferFrom(users.tokenCreatorAddress, users.vaultOwner, i);
            mockERC721.nft3.transferFrom(users.tokenCreatorAddress, users.vaultOwner, i);
        }

        mockERC1155.erc1155.safeTransferFrom(
            users.tokenCreatorAddress,
            users.vaultOwner,
            1,
            100_000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );

        vm.stopPrank();

        // Deploy Oracles
        mockOracles = MockOracles({
            stable1ToUsd: initMockedOracle(uint8(Constants.stableOracleDecimals), "STABLE1 / USD"),
            stable2ToUsd: initMockedOracle(uint8(Constants.stableOracleDecimals), "STABLE2 / USD"),
            token1ToUsd: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN1 / USD"),
            token2ToUsd: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN2 / USD"),
            token3ToToken1: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN3 / TOKEN1"),
            token4ToUsd: initMockedOracle(uint8(Constants.tokenOracleDecimals), "TOKEN4 / USD"),
            nft1ToToken1: initMockedOracle(uint8(Constants.nftOracleDecimals), "NFT1 / TOKEN1"),
            nft2ToUsd: initMockedOracle(uint8(Constants.nftOracleDecimals), "NFT2 / USD"),
            nft3ToToken1: initMockedOracle(uint8(Constants.nftOracleDecimals), "NFT3 / TOKEN1"),
            erc1155ToToken1: initMockedOracle(uint8(Constants.erc1155OracleDecimals), "ERC1155 / TOKEN1")
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

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
