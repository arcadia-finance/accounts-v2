/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountErrors } from "../libraries/Errors.sol";
import { AccountStorageV1 } from "./AccountStorageV1.sol";
import { ERC20, SafeTransferLib } from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import { IERC721 } from "../interfaces/IERC721.sol";
import { IERC1155 } from "../interfaces/IERC1155.sol";
import { IActionBase, ActionData } from "../interfaces/IActionBase.sol";
import { IAccount } from "../interfaces/IAccount.sol";
import { IFactory } from "../interfaces/IFactory.sol";
import { IPermit2 } from "../interfaces/IPermit2.sol";

/**
 * @title Arcadia Accounts
 * @author Pragma Labs
 * @notice Arcadia Accounts are smart contracts that act as onchain, decentralized and composable margin accounts.
 * They provide individuals, DAOs, and other protocols with a simple and flexible way to deposit and manage multiple assets as collateral.
 * The total combination of assets can be used as margin to back liabilities issued by any financial protocol (lending, leverage, futures...).
 * @dev Users can use this Account to deposit assets (fungible, non-fungible, LP positions, yiel bearing assets...).
 * The Account will denominate all the deposited assets into one Numeraire (one unit of account, like USD or ETH).
 * Users can use the single denominated value of all their assets to take margin (take credit line, financing for leverage...).
 * An increase of value of one asset will offset a decrease in value of another asset.
 * Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
 * @dev Integrating this Account as means of margin/collateral management for your own protocol that requires collateral is encouraged.
 * Arcadia's Account functions will guarantee you a certain value of the Account.
 * For allowlists or liquidation strategies specific to your protocol, contact pragmalabs.dev
 */
contract AccountV1 is AccountStorageV1, IAccount {
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The current Account Version.
    uint256 public constant ACCOUNT_VERSION = 100;
    // The cool-down period after an account action, that might be disadvantageous for a new Owner,
    // during which ownership cannot be transferred to prevent the old Owner from frontrunning a transferFrom().
    // TODO : still needed ?
    uint256 internal constant COOL_DOWN_PERIOD = 5 minutes;
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
     * @dev Throws if called when the Account is in an auction.
     */
    modifier notDuringAuction() {
        if (inAuction == true) revert AccountErrors.AccountInAuction();
        _;
    }

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
     * @dev A proxy will be used to interact with the Account implementation.
     * Therefore everything is initialised through an init function.
     * This function will only be called (once) in the same transaction as the proxy Account creation through the Factory.
     * @dev The Creditor will only be set if it's a non-zero address, in this case the numeraire_ passed as input will be ignored.
     * @dev initialize has implicitly a nonReentrant guard, since the "locked" variable has value zero until the end of the function.
     */
    function initialize(address owner_, address, address) external onlyFactory {
        owner = owner_;

        locked = 1;
    }

    /**
     * @notice Upgrades the Account version and stores a new address in the EIP1967 implementation slot.
     * @param newImplementation The new contract address of the Account implementation.
     * @param newRegistry The Registry for this specific implementation (might be identical to the old registry).
     * @param data Arbitrary data, can contain instructions to execute when updating Account to new implementation.
     * @param newVersion The new version of the Account implementation.
     * @dev This function MUST be added to new Account implementations.
     */
    function upgradeAccount(address newImplementation, address newRegistry, uint256 newVersion, bytes calldata data)
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
        // Used to eg. Remove exposure from old Registry and add exposure to the new Registry.
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
     * @notice Finalizes the Upgrade to a new Account version on the new implementation Contract.
     * @param oldImplementation The old contract address of the Account implementation.
     * @param oldRegistry The Registry of the old version (might be identical to the new registry)
     * @param oldVersion The old version of the Account implementation.
     * @param data Arbitrary data, can contain instructions to execute in this function.
     * @dev If upgradeHook() is implemented, it MUST verify that msg.sender == address(this).
     */
    function upgradeHook(address oldImplementation, address oldRegistry, uint256 oldVersion, bytes calldata data)
        external
    { }

    /* ///////////////////////////////////////////////////////////////
                          DEPOSIT / WITHDRAW LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Withdraws assets to the Account owner.
     */
    function withdraw(
        address[] memory assets,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        uint256[] memory assetTypes
    ) public onlyOwner nonReentrant updateActionTimestamp {
        for (uint256 i; i < assets.length; ++i) {
            if (assets[i] == address(0)) {
                (bool success, bytes memory result) = payable(msg.sender).call{ value: assetAmounts[i] }("");
                require(success, string(result));
            } else if (assetTypes[i] == 1) {
                ERC20(assets[i]).safeTransfer(msg.sender, assetAmounts[i]);
            } else if (assetTypes[i] == 2) {
                IERC721(assets[i]).safeTransferFrom(address(this), msg.sender, assetIds[i]);
            } else if (assetTypes[i] == 3) {
                IERC1155(assets[i]).safeTransferFrom(address(this), msg.sender, assetIds[i], assetAmounts[i], "");
            }
        }
    }

    function _deposit(ActionData memory depositData, address from) internal {
        for (uint256 i; i < depositData.assets.length; ++i) {
            // Skip if amount is 0 to prevent storing addresses that have 0 balance.
            if (depositData.assetAmounts[i] == 0) continue;

            if (depositData.assetTypes[i] == 1) {
                if (depositData.assetIds[i] != 0) revert AccountErrors.InvalidERC20Id();
                ERC20(depositData.assets[i]).safeTransferFrom(from, address(this), depositData.assetAmounts[i]);
            } else if (depositData.assetTypes[i] == 2) {
                if (depositData.assetAmounts[i] != 1) revert AccountErrors.InvalidERC721Amount();
                IERC721(depositData.assets[i]).safeTransferFrom(from, address(this), depositData.assetIds[i]);
            } else if (depositData.assetTypes[i] == 3) {
                IERC1155(depositData.assets[i]).safeTransferFrom(
                    from, address(this), depositData.assetIds[i], depositData.assetAmounts[i], ""
                );
            } else {
                revert AccountErrors.UnknownAssetType();
            }
        }
    }

    /**
     * @notice Withdraws assets from the Account to the owner.
     * @param to The address to withdraw to.
     * @dev (batch)ProcessWithdrawal handles the accounting of assets in the Registry.
     */
    function _withdraw(ActionData memory withdrawData, address to) internal {
        for (uint256 i; i < withdrawData.assets.length; ++i) {
            // Skip if amount is 0 to prevent transferring 0 balances.
            if (withdrawData.assetAmounts[i] == 0) continue;

            if (withdrawData.assetTypes[i] == 1) {
                if (withdrawData.assetIds[i] != 0) revert AccountErrors.InvalidERC20Id();
                ERC20(withdrawData.assets[i]).safeTransfer(to, withdrawData.assetAmounts[i]);
            } else if (withdrawData.assetTypes[i] == 2) {
                if (withdrawData.assetAmounts[i] != 1) revert AccountErrors.InvalidERC721Amount();
                IERC721(withdrawData.assets[i]).safeTransferFrom(address(this), to, withdrawData.assetIds[i]);
            } else if (withdrawData.assetTypes[i] == 3) {
                IERC1155(withdrawData.assets[i]).safeTransferFrom(
                    address(this), to, withdrawData.assetIds[i], withdrawData.assetAmounts[i], ""
                );
            } else {
                revert AccountErrors.UnknownAssetType();
            }
        }
    }

    // remove nonReentrant ?
    function withdrawERC20(address to, address ERC20Address, uint256 amount) external onlyOwner nonReentrant {
        ERC20(ERC20Address).safeTransfer(to, amount);
    }

    // remove nonReentrant ?
    function _withdrawERC721(address to, address ERC721Address, uint256 id) external onlyOwner nonReentrant {
        IERC721(ERC721Address).safeTransferFrom(address(this), to, id);
    }

    // remove nonReentrant ?
    function _withdrawERC1155(address to, address ERC1155Address, uint256 id, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        IERC1155(ERC1155Address).safeTransferFrom(address(this), to, id, amount, "");
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

    function _transferOwnership(address newOwner) internal {
        // The Factory will check that the new owner is not address(0).
        owner = newOwner;
        IFactory(FACTORY).safeTransferAccount(newOwner);
    }

    /*///////////////////////////////////////////////////////////////
                       ASSET MANAGER ACTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Add or remove an Asset Manager.
     * @param assetManager The address of the Asset Manager.
     * @param value A boolean giving permissions to or taking permissions from an Asset Manager.
     * @dev Only set trusted addresses as Asset Manager. Asset Managers have full control over assets in the Account,
     * as long as the Account position remains healthy.
     * @dev No need to set the Owner as Asset Manager as they will automatically have all permissions of an Asset Manager.
     * @dev Potential use-cases of the Asset Manager might be to:
     * - Automate actions by keeper networks.
     * - Do flash actions (optimistic actions).
     * - Chain multiple interactions together (eg. deposit and trade in one transaction).
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
     * At the very end of the flash action, the following check is performed:
     * - The Account is in a healthy state (collateral value is greater than open liabilities).
     * If a check fails, the whole transaction reverts.
     */
    function flashAction(address actionTarget, bytes calldata actionData)
        external
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
        _withdraw(withdrawData, actionTarget);

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
        _deposit(depositData, actionTarget);
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
            if (transferFromOwnerData.assetAmounts[i] == 0) {
                // Skip if amount is 0 to prevent transferring 0 balances.
                continue;
            }

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
}
