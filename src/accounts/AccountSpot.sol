/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountErrors } from "../libraries/Errors.sol";
import { AccountStorageV1 } from "./AccountStorageV1.sol";
import { ActionData, IActionBase } from "../interfaces/IActionBase.sol";
import { ERC20, SafeTransferLib } from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import { IAccount } from "../interfaces/IAccount.sol";
import { IERC721 } from "../interfaces/IERC721.sol";
import { IERC1155 } from "../interfaces/IERC1155.sol";
import { IPermit2 } from "../interfaces/IPermit2.sol";

/**
 * @title Arcadia Spot Account
 * @author Pragma Labs
 * @notice Arcadia Spot Accounts enables individuals, DAOs, and other protocols to deposit and manage a variety of assets easily through Asset Managers.
 * Asset Managers are selected by Spot Account holders and can facilitate automation for tasks such as Liquidity Management and Compounding, among others.
 */
contract AccountSpot is AccountStorageV1, IAccount {
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The current Account Version.
    uint256 public constant ACCOUNT_VERSION = 2;
    // The cool-down period after an account action, that might be disadvantageous for a new Owner,
    // during which ownership cannot be transferred to prevent the old Owner from frontrunning a transferFrom().
    uint256 public constant COOL_DOWN_PERIOD = 5 minutes;
    // Storage slot with the address of the current implementation.
    // This is the hardcoded keccak-256 hash of: "eip1967.proxy.implementation" subtracted by 1.
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // The contract address of the Arcadia Accounts Factory.
    address public immutable FACTORY;
    // Uniswap Permit2 contract
    IPermit2 internal immutable PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    // Storage slot for the Account implementation, a struct to avoid storage conflict when dealing with upgradeable contracts.
    struct AddressSlot {
        address value;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AssetManagerSet(address indexed owner, address indexed assetManager, bool value);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Throws if function is reentered.
     */
    modifier nonReentrant() {
        if (locked != 1) revert AccountErrors.NoReentry();
        locked = 2;
        _;
        locked = 1;
    }

    /**
     * @dev Throws if called by any address other than an Asset Manager or the owner.
     */
    modifier onlyAssetManager() {
        // A custom error would need to read out owner + isAssetManager storage
        require(msg.sender == owner || isAssetManager[owner][msg.sender], "A: Only Asset Manager");
        _;
    }

    /**
     * @dev Throws if called by any address other than the Factory address.
     */
    modifier onlyFactory() {
        if (msg.sender != FACTORY) revert AccountErrors.OnlyFactory();
        _;
    }

    /**
     * @dev Throws if called by any address other than the owner.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert AccountErrors.OnlyOwner();
        _;
    }

    /**
     * @dev Starts the cool-down period during which ownership cannot be transferred.
     * This prevents the old Owner from frontrunning a transferFrom().
     */
    modifier updateActionTimestamp() {
        lastActionTimestamp = uint32(block.timestamp);
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param factory The contract address of the Arcadia Accounts Factory.
     */
    constructor(address factory) {
        // This will only be the owner of the Account implementation.
        // and will not affect any subsequent proxy implementation using this Account implementation.
        owner = msg.sender;

        FACTORY = factory;
    }

    /* ///////////////////////////////////////////////////////////////
                          ACCOUNT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Initiates the variables of the Account.
     * @param owner_ The sender of the 'createAccount' on the Factory
     * @param registry_ The 'beacon' contract with the external logic to price assets.
     * @dev A proxy will be used to interact with the Account implementation.
     * This function will only be called (once) in the same transaction as the proxy Account creation through the Factory.
     * @dev initialize has implicitly a nonReentrant guard, since the "locked" variable has value zero until the end of the function.
     * @dev The Registry is not used in spot accounts, but a valid registry must be set to be compatible with V1 Accounts.
     */
    function initialize(address owner_, address registry_, address) external onlyFactory {
        if (registry_ == address(0)) revert AccountErrors.InvalidRegistry();
        owner = owner_;
        registry = registry_;

        locked = 1;
    }

    /**
     * @notice Upgrades the Account version and stores a new address in the EIP1967 implementation slot.
     * @param newImplementation The new contract address of the Account implementation.
     * @param newRegistry The Registry for this specific newImplementation.
     * @param data Arbitrary data, can contain instructions to execute when updating Account to new implementation.
     * @dev This function MUST be added to new Account implementations.
     */
    function upgradeAccount(address newImplementation, address newRegistry, uint256, bytes calldata data)
        external
        onlyFactory
        nonReentrant
        updateActionTimestamp
    {
        // Cache old parameters.
        address oldImplementation = _getAddressSlot(IMPLEMENTATION_SLOT).value;
        uint256 oldVersion = ACCOUNT_VERSION;

        // Store new parameters.
        _getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
        registry = newRegistry;

        // Hook on the new logic to finalize upgrade.
        // Used to eg. Remove exposure from old Registry and add exposure to the new RegistryL2.
        // Extra data can be added by the Factory for complex instructions.
        this.upgradeHook(oldImplementation, address(0), oldVersion, data);

        // Event emitted by Factory.
    }

    /**
     * @notice Returns the "AddressSlot" with member "value" located at "slot".
     * @param slot The slot where the address of the Logic contract is stored.
     * @return r The address stored in slot.
     */
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @notice Finalizes the Upgrade from a different Account version to this version.
     * param oldImplementation The old contract address of the Account implementation.
     * param oldRegistry The Registry of the old version (might be identical to the new registry)
     * param oldVersion The old version of the Account implementation.
     * param data Arbitrary data, can contain instructions to execute in this function.
     * @dev If upgradeHook() is implemented, it MUST verify that msg.sender == address(this).
     * @dev We delete the deprecated AccountStorageV1 variables.
     */
    function upgradeHook(address, address, uint256, bytes calldata) external {
        if (msg.sender != address(this)) revert AccountErrors.OnlySelf();
        if (registry == address(0)) revert AccountErrors.InvalidRegistry();

        // Require that no creditor is set and no auctions are ongoing.
        // (This should always be enforced in the old Version we upgrade from, but we do a redundant safety check).
        if (creditor != address(0) || inAuction) revert AccountErrors.InvalidUpgrade();

        // Delete margin account related storage data (should normally already be empty).
        delete liquidator;
        delete minimumMargin;
        delete numeraire;

        // Delete asset related storage data.
        uint256 erc20StoredLength = erc20Stored.length;
        for (uint256 i = 0; i < erc20StoredLength; ++i) {
            delete erc20Balances[erc20Stored[i]];
        }
        delete erc20Stored;

        delete erc721Stored;
        delete erc721TokenIds;

        uint256 erc1155StoredLength = erc1155Stored.length;
        for (uint256 j = 0; j < erc1155StoredLength; ++j) {
            delete erc1155Balances[erc1155Stored[j]][erc1155TokenIds[j]];
        }
        delete erc1155Stored;
        delete erc1155TokenIds;
    }

    /* ///////////////////////////////////////////////////////////////
                        OWNERSHIP MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Transfers ownership of the contract to a new Account.
     * @param newOwner The new owner of the Account.
     * @dev Can only be called by the current owner via the Factory.
     * A transfer of ownership of the Account is triggered by a transfer
     * of ownership of the accompanying ERC721 Account NFT, issued by the Factory.
     * Owner of Account NFT = owner of Account
     * @dev Function uses a cool-down period during which ownership cannot be transferred.
     * Cool-down period is triggered after any account action, that might be disadvantageous for a new Owner.
     * This prevents the old Owner from frontrunning a transferFrom().
     */
    function transferOwnership(address newOwner) external onlyFactory {
        if (block.timestamp <= lastActionTimestamp + COOL_DOWN_PERIOD) revert AccountErrors.CoolDownPeriodNotPassed();

        // The Factory will check that the new owner is not address(0).
        owner = newOwner;
    }

    /*///////////////////////////////////////////////////////////////
                       ASSET MANAGER ACTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Add or remove an Asset Manager.
     * @param assetManager The address of the Asset Manager.
     * @param value A boolean giving permissions to or taking permissions from an Asset Manager.
     * @dev Only set trusted addresses as Asset Manager. Asset Managers have full control over assets in the Account.
     * @dev No need to set the Owner as Asset Manager as they will automatically have all permissions of an Asset Manager.
     * @dev Potential use-cases of the Asset Manager might be to:
     * - Liquidity Management.
     * - Do flash actions (optimistic actions).
     * - Compounding.
     * - Chain multiple interactions together.
     * @dev Anyone can set the Asset Manager for themselves, this will not impact the current owner of the Account
     * since the combination of "stored owner -> asset manager" is used in authentication checks.
     * This guarantees that when the ownership of the Account is transferred, the asset managers of the old owner have no
     * impact on the new owner. But the new owner can still remove any existing asset managers before the transfer.
     */
    function setAssetManager(address assetManager, bool value) external {
        emit AssetManagerSet(msg.sender, assetManager, isAssetManager[msg.sender][assetManager] = value);
    }

    /**
     * @notice Executes a flash action.
     * @param actionTarget The contract address of the actionTarget to execute external logic.
     * @param actionData A bytes object containing three structs and two bytes objects.
     * The first struct contains the info about the assets to withdraw from this Account to the actionTarget.
     * The second struct contains the info about the owner's assets that need to be transferred from the owner to the actionTarget.
     * The third struct contains the permit for the Permit2 transfer.
     * The first bytes object contains the signature for the Permit2 transfer.
     * The second bytes object contains the encoded input for the actionTarget.
     * @dev This function optimistically chains multiple actions together (= do a flash action):
     * - It can optimistically withdraw assets from the Account to the actionTarget.
     * - It can transfer assets directly from the owner to the actionTarget.
     * - It can execute external logic on the actionTarget, and interact with any DeFi protocol to swap, stake, claim...
     * - It can deposit all recipient tokens from the actionTarget back into the Account.
     */
    function flashAction(address actionTarget, bytes calldata actionData)
        external
        payable
        onlyAssetManager
        nonReentrant
        updateActionTimestamp
    {
        // Decode flash action data.
        (
            ActionData memory withdrawData,
            ActionData memory transferFromOwnerData,
            IPermit2.PermitBatchTransferFrom memory permit,
            bytes memory signature,
            bytes memory actionTargetData
        ) = abi.decode(actionData, (ActionData, ActionData, IPermit2.PermitBatchTransferFrom, bytes, bytes));

        // Withdraw assets to the actionTarget.
        _withdraw(
            withdrawData.assets, withdrawData.assetIds, withdrawData.assetAmounts, withdrawData.assetTypes, actionTarget
        );

        // Transfer assets from owner (that are not assets in this account) to the actionTarget.
        if (transferFromOwnerData.assets.length > 0) {
            _transferFromOwner(transferFromOwnerData, actionTarget);
        }

        // If the function input includes a signature and non-empty token permissions,
        // initiate a transfer from the owner to the actionTarget via Permit2.
        if (signature.length > 0 && permit.permitted.length > 0) {
            _transferFromOwnerWithPermit(permit, signature, actionTarget);
        }

        // Execute external logic on the actionTarget.
        ActionData memory depositData = IActionBase(actionTarget).executeAction(actionTargetData);

        // Deposit assets from actionTarget into Account.
        _deposit(
            depositData.assets, depositData.assetIds, depositData.assetAmounts, depositData.assetTypes, actionTarget
        );
    }

    /*///////////////////////////////////////////////////////////////
                          ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits assets into the Account.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param assetTypes Array of the asset types.
     */
    function deposit(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        uint256[] memory assetTypes
    ) external payable onlyOwner nonReentrant {
        _deposit(assetAddresses, assetIds, assetAmounts, assetTypes, msg.sender);
    }

    /**
     * @notice Deposits assets into the Account.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param assetTypes Array of the asset types.
     * @param from The assets deposited into the Account will come from this address.
     */
    function _deposit(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        uint256[] memory assetTypes,
        address from
    ) internal {
        for (uint256 i; i < assetAddresses.length; ++i) {
            // Skip if amount is 0 to prevent transferring addresses that have 0 balance.
            if (assetAmounts[i] == 0) continue;

            if (assetTypes[i] == 1) {
                ERC20(assetAddresses[i]).safeTransferFrom(from, address(this), assetAmounts[i]);
            } else if (assetTypes[i] == 2) {
                IERC721(assetAddresses[i]).safeTransferFrom(from, address(this), assetIds[i]);
            } else if (assetTypes[i] == 3) {
                IERC1155(assetAddresses[i]).safeTransferFrom(from, address(this), assetIds[i], assetAmounts[i], "");
            } else {
                revert AccountErrors.UnknownAssetType();
            }
        }
    }

    /**
     * @notice Withdraws assets from the Account to the owner.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param assetTypes Array of the asset types.
     */
    function withdraw(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        uint256[] memory assetTypes
    ) public onlyOwner nonReentrant updateActionTimestamp {
        _withdraw(assetAddresses, assetIds, assetAmounts, assetTypes, msg.sender);
    }

    /**
     * @notice Withdraws assets from the Account.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param assetTypes Array of the asset types.
     * @param to The address to withdraw to.
     */
    function _withdraw(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        uint256[] memory assetTypes,
        address to
    ) internal {
        for (uint256 i; i < assetAddresses.length; ++i) {
            // Skip if amount is 0 to prevent transferring addresses that have 0 balance.
            if (assetAmounts[i] == 0) continue;

            if (assetAddresses[i] == address(0)) {
                (bool success, bytes memory result) = payable(to).call{ value: assetAmounts[i] }("");
                require(success, string(result));
            } else if (assetTypes[i] == 1) {
                ERC20(assetAddresses[i]).safeTransfer(to, assetAmounts[i]);
            } else if (assetTypes[i] == 2) {
                IERC721(assetAddresses[i]).safeTransferFrom(address(this), to, assetIds[i]);
            } else if (assetTypes[i] == 3) {
                IERC1155(assetAddresses[i]).safeTransferFrom(address(this), to, assetIds[i], assetAmounts[i], "");
            } else {
                revert AccountErrors.UnknownAssetType();
            }
        }
    }

    /**
     * @notice Transfers assets directly from the owner to the actionTarget contract.
     * @param transferFromOwnerData A struct containing the info of all assets transferred from the owner that are not in this account.
     * @param to The address to withdraw to.
     */
    function _transferFromOwner(ActionData memory transferFromOwnerData, address to) internal {
        uint256 assetAddressesLength = transferFromOwnerData.assets.length;
        address owner_ = owner;
        for (uint256 i; i < assetAddressesLength; ++i) {
            // Skip if amount is 0 to prevent transferring 0 balances.
            if (transferFromOwnerData.assetAmounts[i] == 0) continue;

            if (transferFromOwnerData.assetTypes[i] == 1) {
                ERC20(transferFromOwnerData.assets[i]).safeTransferFrom(
                    owner_, to, transferFromOwnerData.assetAmounts[i]
                );
            } else if (transferFromOwnerData.assetTypes[i] == 2) {
                IERC721(transferFromOwnerData.assets[i]).safeTransferFrom(owner_, to, transferFromOwnerData.assetIds[i]);
            } else if (transferFromOwnerData.assetTypes[i] == 3) {
                IERC1155(transferFromOwnerData.assets[i]).safeTransferFrom(
                    owner_, to, transferFromOwnerData.assetIds[i], transferFromOwnerData.assetAmounts[i], ""
                );
            } else {
                revert AccountErrors.UnknownAssetType();
            }
        }
    }

    /**
     * @notice Transfers assets from the owner to the actionTarget contract via Permit2.
     * @param permit Data specifying the terms of the transfer.
     * @param signature The signature to verify.
     * @param to_ The address to withdraw to.
     */
    function _transferFromOwnerWithPermit(
        IPermit2.PermitBatchTransferFrom memory permit,
        bytes memory signature,
        address to_
    ) internal {
        uint256 tokenPermissionsLength = permit.permitted.length;
        IPermit2.SignatureTransferDetails[] memory transferDetails =
            new IPermit2.SignatureTransferDetails[](tokenPermissionsLength);

        for (uint256 i; i < tokenPermissionsLength; ++i) {
            transferDetails[i].to = to_;
            transferDetails[i].requestedAmount = permit.permitted[i].amount;
        }

        PERMIT2.permitTransferFrom(permit, transferDetails, owner, signature);
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    /* 
    @notice Returns the onERC721Received selector.
    @dev Needed to receive ERC721 tokens.
    */
    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /*
    @notice Returns the onERC1155Received selector.
    @dev Needed to receive ERC1155 tokens.
    */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /*
    @notice Called when function selector doesn't match any other.
    @dev No fallback allowed.
    */
    fallback() external {
        revert AccountErrors.NoFallback();
    }

    /*
    @notice Called on a plain ETH transfer.
    */
    receive() external payable { }
}
