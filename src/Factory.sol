/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Proxy } from "./Proxy.sol";
import { IAccount } from "./interfaces/IAccount.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { ERC721 } from "../lib/solmate/src/tokens/ERC721.sol";
import { Strings } from "./libraries/Strings.sol";
import { MerkleProofLib } from "./libraries/MerkleProofLib.sol";
import { FactoryGuardian } from "./guardians/FactoryGuardian.sol";

/**
 * @title Factory.
 * @author Pragma Labs
 * @notice The Factory has the logic to deploy and upgrade Arcadia Accounts.
 * @dev The Factory is an ERC721 contract that maps each id to an Arcadia Account.
 */
contract Factory is IFactory, ERC721, FactoryGuardian {
    using Strings for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The latest Account version, new deployed Account use the latest version by default.
    uint16 public latestAccountVersion;
    // The baseURI of the ERC721 tokens.
    string public baseURI;
    // Array of all Arcadia Account contract addresses.
    address[] public allAccounts;

    // Map accountVersion => flag.
    mapping(uint256 => bool) public accountVersionBlocked;
    // Map accountAddress => accountIndex.
    mapping(address => uint256) public accountIndex;
    // Map accountVersion => versionInfo.
    mapping(uint256 => AccountVersionInfo) public accountDetails;

    // Struct with additional information for a specific Account version.
    struct AccountVersionInfo {
        address registry; // The contract address of the MainRegistry.
        address logic; // The contract address of the Account logic.
        bytes32 versionRoot; // The Merkle root of the merkle tree of all the compatible Account versions.
        bytes data; // Arbitrary data, can contain instructions to execute when updating Account to new logic.
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AccountUpgraded(address indexed accountAddress, uint16 oldVersion, uint16 indexed newVersion);
    event AccountVersionAdded(
        uint16 indexed version, address indexed registry, address indexed logic, bytes32 versionRoot
    );
    event AccountVersionBlocked(uint16 version);

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() ERC721("Arcadia Account", "ARCADIA") { }

    /*///////////////////////////////////////////////////////////////
                          ACCOUNT MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to create a new Account.
     * @param salt A salt to be used to generate the hash.
     * @param accountVersion The Account version.
     * @param baseCurrency The Base-currency in which the Account is denominated.
     * @param creditor The contract address of the creditor.
     * @return account The contract address of the proxy contract of the newly deployed Account.
     * @dev Safe to cast a uint256 to a bytes32 since the space of both is 2^256.
     */
    function createAccount(uint256 salt, uint16 accountVersion, address baseCurrency, address creditor)
        external
        whenCreateNotPaused
        returns (address account)
    {
        accountVersion = accountVersion == 0 ? latestAccountVersion : accountVersion;

        require(accountVersion <= latestAccountVersion, "FTRY_CV: Unknown Account version");
        require(!accountVersionBlocked[accountVersion], "FTRY_CV: Account version blocked");

        // Hash tx.origin with the user provided salt to avoid front-running Account deployment with an identical salt.
        // We use tx.origin instead of msg.sender so that deployments through a third party contract is not vulnerable to front-running.
        account =
            address(new Proxy{salt: keccak256(abi.encodePacked(salt, tx.origin))}(accountDetails[accountVersion].logic));

        IAccount(account).initialize(msg.sender, accountDetails[accountVersion].registry, baseCurrency, creditor);

        allAccounts.push(account);
        accountIndex[account] = allAccounts.length;

        _mint(msg.sender, allAccounts.length);

        emit AccountUpgraded(account, 0, accountVersion);
    }

    /**
     * @notice View function returning if an address is an Account.
     * @param account The address to be checked.
     * @return bool Whether the address is an Account or not.
     */
    function isAccount(address account) public view returns (bool) {
        return accountIndex[account] > 0;
    }

    /**
     * @notice Returns the owner of an Account.
     * @param account The Account address.
     * @return owner_ The Account owner.
     * @dev Function does not revert when a non-existing Account is passed, but returns zero-address as owner.
     */
    function ownerOfAccount(address account) external view returns (address owner_) {
        owner_ = _ownerOf[accountIndex[account]];
    }

    /**
     * @notice This function allows Account owners to upgrade the logic of the Account.
     * @param account Account that needs to be upgraded.
     * @param version The accountVersion to upgrade to.
     * @param proofs The merkle proofs that prove the compatibility of the upgrade from current to new accountVersion.
     * @dev As each Account is a proxy, the implementation of the proxy can be changed by the owner of the Account.
     * Checks are done such that only compatible versions can be upgraded to.
     * Merkle proofs and their leaves can be found on https://www.github.com/arcadia-finance.
     */
    function upgradeAccountVersion(address account, uint16 version, bytes32[] calldata proofs) external {
        require(_ownerOf[accountIndex[account]] == msg.sender, "FTRY_UVV: Only Owner");
        require(!accountVersionBlocked[version], "FTRY_UVV: Account version blocked");
        uint256 currentVersion = IAccount(account).ACCOUNT_VERSION();

        bool canUpgrade = MerkleProofLib.verify(
            proofs, getAccountVersionRoot(), keccak256(abi.encodePacked(currentVersion, uint256(version)))
        );

        require(canUpgrade, "FTR_UVV: Version not allowed");

        IAccount(account).upgradeAccount(
            accountDetails[version].logic, accountDetails[version].registry, version, accountDetails[version].data
        );

        emit AccountUpgraded(account, uint16(currentVersion), version);
    }

    /**
     * @notice Function to get the latest versioning root.
     * @return The latest versioning root.
     * @dev The versioning root is the root of the merkle tree of all the compatible Account versions.
     * The root is updated every time a new Account version added. The root is used to verify the
     * proofs when an Account is being upgraded.
     */
    function getAccountVersionRoot() public view returns (bytes32) {
        return accountDetails[latestAccountVersion].versionRoot;
    }

    /**
     * @notice Function used to transfer an Account between users.
     * @param from The sender.
     * @param to The target.
     * @param account The address of the Account that is transferred.
     * @dev This method transfers an Account not on id but on address and also transfers the Account proxy contract to the new owner.
     */
    function safeTransferFrom(address from, address to, address account) public {
        uint256 id = accountIndex[account];
        IAccount(allAccounts[id - 1]).transferOwnership(to);
        super.safeTransferFrom(from, to, id);
    }

    /**
     * @notice Function used to transfer an Account between users.
     * @param from The sender.
     * @param to The target.
     * @param id The id of the Account that is about to be transferred.
     * @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the Account proxy contract to the new owner.
     */
    function safeTransferFrom(address from, address to, uint256 id) public override {
        IAccount(allAccounts[id - 1]).transferOwnership(to);
        super.safeTransferFrom(from, to, id);
    }

    /**
     * @notice Function used to transfer an Account between users.
     * @param from The sender.
     * @param to The target.
     * @param id The id of the Account that is about to be transferred.
     * @param data additional data, only used for onERC721Received.
     * @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the Account proxy contract to the new owner.
     */
    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public override {
        IAccount(allAccounts[id - 1]).transferOwnership(to);
        super.safeTransferFrom(from, to, id, data);
    }

    /**
     * @notice Function used to transfer an Account between users.
     * @param from The sender.
     * @param to The target.
     * @param id The id of the Account that is about to be transferred.
     * @dev This method overwrites the safeTransferFrom function in ERC721.sol to also transfer the Account proxy contract to the new owner.
     */
    function transferFrom(address from, address to, uint256 id) public override {
        IAccount(allAccounts[id - 1]).transferOwnership(to);
        super.transferFrom(from, to, id);
    }

    /*///////////////////////////////////////////////////////////////
                    ACCOUNT VERSION MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to set a new Account version with the contracts to be used for new deployed Accounts.
     * @param registry The contract address of the Main Registry.
     * @param logic The contract address of the Account logic.
     * @param versionRoot The Merkle root of the merkle tree of all the compatible Account versions.
     * @param data Arbitrary data, can contain instructions to execute when updating Account to new logic.
     * @dev Changing any of the contracts does NOT change the contracts for existing deployed Accounts,
     * unless the Account owner explicitly chooses to upgrade their Account to a newer version.
     */
    function setNewAccountInfo(address registry, address logic, bytes32 versionRoot, bytes calldata data)
        external
        onlyOwner
    {
        require(versionRoot != bytes32(0), "FTRY_SNVI: version root is zero");
        require(logic != address(0), "FTRY_SNVI: logic address is zero");

        unchecked {
            ++latestAccountVersion;
        }

        require(IAccount(logic).ACCOUNT_VERSION() == latestAccountVersion, "FTRY_SNVI: vault version mismatch");

        accountDetails[latestAccountVersion].registry = registry;
        accountDetails[latestAccountVersion].logic = logic;
        accountDetails[latestAccountVersion].versionRoot = versionRoot;
        accountDetails[latestAccountVersion].data = data;

        emit AccountVersionAdded(latestAccountVersion, registry, logic, versionRoot);
    }

    /**
     * @notice Function to block a certain Account logic version from being created as a new Account.
     * @param version The Account version to be phased out.
     * @dev Should any Account logic version be phased out,
     * this function can be used to block it from being created for new Accounts.
     */
    function blockAccountVersion(uint256 version) external onlyOwner {
        require(version > 0 && version <= latestAccountVersion, "FTRY_BVV: Invalid version");
        accountVersionBlocked[version] = true;

        emit AccountVersionBlocked(uint16(version));
    }

    /*///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function returns the total number of Accounts.
     * @return numberOfAccounts The total number of Accounts.
     */
    function allAccountsLength() external view returns (uint256 numberOfAccounts) {
        numberOfAccounts = allAccounts.length;
    }

    /*///////////////////////////////////////////////////////////////
                        ERC-721 LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function that stores a new base URI.
     * @dev tokenURI's of Arcadia Accounts are not meant to be immutable
     * and might be updated later to allow users to
     * choose/create their own Account art,
     * as such no URI freeze is added.
     * @param newBaseURI The new base URI to store.
     */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    /**
     * @notice Function that returns the token URI as defined in the erc721 standard.
     * @param tokenId The id if the Account.
     * @return uri The token uri.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        require(_ownerOf[tokenId] != address(0), "ERC721Metadata: URI query for nonexistent token");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }
}
