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
import { MerkleProofLib } from "../lib/solmate/src/utils/MerkleProofLib.sol";
import { FactoryGuardian } from "./guardians/FactoryGuardian.sol";
import { FactoryErrors } from "./libraries/Errors.sol";

/**
 * @title Factory
 * @author Pragma Labs
 * @notice The Factory manages the deployment, upgrades and transfers of Arcadia Accounts.
 * @dev The Factory is an ERC721 contract that maps each id to an Arcadia Account.
 */
contract Factory is IFactory, ERC721, FactoryGuardian {
    using Strings for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The latest Account version, newly deployed Account use the latest version by default.
    uint16 public latestAccountVersion;
    // The baseURI of the ERC721 tokens.
    string public baseURI;

    // The Merkle root of the Merkle tree of all the compatible Account versions.
    bytes32 public versionRoot;

    // Array of all Arcadia Account contract addresses.
    address[] public allAccounts;

    // Map accountVersion => blocked status.
    mapping(uint256 => bool) public accountVersionBlocked;
    // Map accountAddress => accountIndex.
    mapping(address => uint256) public accountIndex;
    // Map accountVersion => version information.
    mapping(uint256 => VersionInformation) public versionInformation;

    // Struct with additional information for a specific Account version.
    struct VersionInformation {
        // The contract address of the Registry.
        address registry;
        // The contract address of the Account logic.
        address logic;
        // Arbitrary data, can contain instructions to execute when updating Account to new logic.
        bytes data;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AccountUpgraded(address indexed accountAddress, uint16 indexed newVersion);
    event AccountVersionAdded(uint16 indexed version, address indexed registry, address indexed logic);
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
     * @dev If accountVersion == 0, the newest version will be used.
     */
    function createAccount(uint256 salt, uint16 accountVersion, address baseCurrency, address creditor)
        external
        whenCreateNotPaused
        returns (address account)
    {
        accountVersion = accountVersion == 0 ? latestAccountVersion : accountVersion;

        if (accountVersion > latestAccountVersion) revert FactoryErrors.InvalidAccountVersion();
        if (accountVersionBlocked[accountVersion]) revert FactoryErrors.AccountVersionBlocked();

        // Hash tx.origin with the user provided salt to avoid front-running Account deployment with an identical salt.
        // We use tx.origin instead of msg.sender so that deployments through a third party contract are not vulnerable to front-running.
        account = address(
            new Proxy{ salt: keccak256(abi.encodePacked(salt, tx.origin)) }(versionInformation[accountVersion].logic)
        );

        IAccount(account).initialize(msg.sender, versionInformation[accountVersion].registry, baseCurrency, creditor);

        allAccounts.push(account);
        accountIndex[account] = allAccounts.length;

        _mint(msg.sender, allAccounts.length);

        emit AccountUpgraded(account, accountVersion);
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
     * @param proofs The Merkle proofs that prove the compatibility of the upgrade from current to new account version.
     * @dev As each Account is a proxy, the implementation of the proxy can be changed by the owner of the Account.
     * Checks are done such that only compatible versions can be upgraded to.
     * Merkle proofs and their leaves can be found on https://www.github.com/arcadia-finance.
     */
    function upgradeAccountVersion(address account, uint16 version, bytes32[] calldata proofs) external {
        if (_ownerOf[accountIndex[account]] != msg.sender) revert FactoryErrors.OnlyAccountOwner();
        if (accountVersionBlocked[version]) revert FactoryErrors.AccountVersionBlocked();

        uint256 currentVersion = IAccount(account).ACCOUNT_VERSION();
        bool canUpgrade =
            MerkleProofLib.verify(proofs, versionRoot, keccak256(abi.encodePacked(currentVersion, uint256(version))));

        if (!canUpgrade) revert FactoryErrors.InvalidUpgrade();

        IAccount(account).upgradeAccount(
            versionInformation[version].logic,
            versionInformation[version].registry,
            version,
            versionInformation[version].data
        );

        emit AccountUpgraded(account, version);
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
     * @dev This method overwrites the transferFrom function in ERC721.sol to also transfer the Account proxy contract to the new owner.
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
     * @param registry The contract address of the Registry.
     * @param logic The contract address of the Account logic.
     * @param versionRoot_ The Merkle root of the Merkle tree of all the compatible Account versions.
     * @param data Arbitrary data, can contain instructions to execute when updating Account to new logic.
     * @dev Changing any of the contracts does NOT change the contracts for existing deployed Accounts,
     * unless the Account owner explicitly chooses to upgrade their Account to a newer version.
     */
    function setNewAccountInfo(address registry, address logic, bytes32 versionRoot_, bytes calldata data)
        external
        onlyOwner
    {
        if (versionRoot_ == bytes32(0)) revert FactoryErrors.VersionRootIsZero();
        if (logic == address(0)) revert FactoryErrors.LogicIsZero();

        uint256 latestAccountVersion_;
        unchecked {
            // Update and cache the new latestAccountVersion.
            latestAccountVersion_ = ++latestAccountVersion;
        }

        if (IAccount(logic).ACCOUNT_VERSION() != latestAccountVersion) revert FactoryErrors.VersionMismatch();

        versionRoot = versionRoot_;
        versionInformation[latestAccountVersion_] = VersionInformation({ registry: registry, logic: logic, data: data });

        emit AccountVersionAdded(uint16(latestAccountVersion_), registry, logic);
    }

    /**
     * @notice Function to block a certain Account logic version from being created as a new Account.
     * @param version The Account version to be phased out.
     * @dev Should any Account logic version be phased out,
     * this function can be used to block it from being created for new Accounts.
     */
    function blockAccountVersion(uint256 version) external onlyOwner {
        if (version == 0 || version > latestAccountVersion) revert FactoryErrors.InvalidAccountVersion();
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
     * @param newBaseURI The new base URI to store.
     * @dev tokenURI's of Arcadia Accounts are not meant to be immutable
     * and might be updated later to allow users to choose/create their own Account art,
     * as such no URI freeze is added.
     */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    /**
     * @notice Function that returns the token URI as defined in the ERC721 standard.
     * @param tokenId The id of the Account.
     * @return uri The token URI.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }
}
