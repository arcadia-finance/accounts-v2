/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountErrors } from "../libraries/Errors.sol";
import { AccountStorageV1 } from "./AccountStorageV1.sol";
import { ERC20, SafeTransferLib } from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../libraries/AssetValuationLib.sol";
import { IERC721 } from "../interfaces/IERC721.sol";
import { IERC1155 } from "../interfaces/IERC1155.sol";
import { IRegistry } from "../interfaces/IRegistry.sol";
import { ICreditor } from "../interfaces/ICreditor.sol";
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
    using AssetValuationLib for AssetValueAndRiskFactors[];
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The current Account Version.
    uint256 public constant ACCOUNT_VERSION = 1;
    // The maximum amount of different assets that can be used as collateral within an Arcadia Account.
    uint256 public constant ASSET_LIMIT = 15;
    // The cool-down period after an account action, that might be disadvantageous for a new Owner,
    // during which ownership cannot be transferred to prevent the old Owner from frontrunning a transferFrom().
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
    event MarginAccountChanged(address indexed creditor, address indexed liquidator);
    event NumeraireSet(address indexed numeraire);

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
     * @dev Throws if called when the Account is in an auction.
     */
    modifier notDuringAuction() {
        if (inAuction == true) revert AccountErrors.AccountInAuction();
        _;
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
     * @dev Throws if called by any address other than the Creditor.
     */
    modifier onlyCreditor() {
        if (msg.sender != creditor) revert AccountErrors.OnlyCreditor();
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
     * @dev Throws if called by any address other than the Liquidator address.
     */
    modifier onlyLiquidator() {
        if (msg.sender != liquidator) revert AccountErrors.OnlyLiquidator();
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
     * @param creditor_ The contract address of the Creditor.
     * @dev A proxy will be used to interact with the Account implementation.
     * Therefore everything is initialised through an init function.
     * This function will only be called (once) in the same transaction as the proxy Account creation through the Factory.
     * @dev The Creditor will only be set if it's a non-zero address, in this case the numeraire_ passed as input will be ignored.
     * @dev initialize has implicitly a nonReentrant guard, since the "locked" variable has value zero until the end of the function.
     */
    function initialize(address owner_, address registry_, address creditor_) external {
        if (registry != address(0)) revert AccountErrors.AlreadyInitialized();
        if (registry_ == address(0)) revert AccountErrors.InvalidRegistry();
        owner = owner_;
        registry = registry_;

        if (creditor_ != address(0)) _openMarginAccount(creditor_);

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
        notDuringAuction
        updateActionTimestamp
    {
        // Cache old parameters.
        address oldImplementation = _getAddressSlot(IMPLEMENTATION_SLOT).value;
        address oldRegistry = registry;
        uint256 oldVersion = ACCOUNT_VERSION;

        // Store new parameters.
        _getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
        registry = newRegistry;

        // Prevent that Account is upgraded to a new version where the Numeraire can't be priced.
        if (newRegistry != oldRegistry && !IRegistry(newRegistry).inRegistry(numeraire)) {
            revert AccountErrors.InvalidRegistry();
        }

        // If a Creditor is set, new version should be compatible.
        if (creditor != address(0)) {
            (bool success,,,) = ICreditor(creditor).openMarginAccount(newVersion);
            if (!success) revert AccountErrors.InvalidAccountVersion();
        }

        // Hook on the new logic to finalize upgrade.
        // Used to eg. Remove exposure from old Registry and add exposure to the new Registry.
        // Extra data can be added by the Factory for complex instructions.
        this.upgradeHook(oldImplementation, oldRegistry, oldVersion, data);

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
    function transferOwnership(address newOwner) external onlyFactory notDuringAuction {
        if (block.timestamp <= lastActionTimestamp + COOL_DOWN_PERIOD) revert AccountErrors.CoolDownPeriodNotPassed();

        // The Factory will check that the new owner is not address(0).
        owner = newOwner;
    }

    function _transferOwnership(address newOwner) internal {
        // The Factory will check that the new owner is not address(0).
        owner = newOwner;
        IFactory(FACTORY).safeTransferAccount(newOwner);
    }

    /* ///////////////////////////////////////////////////////////////
                        NUMERAIRE LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets the Numeraire of the Account.
     * @param numeraire_ The new Numeraire for the Account.
     */
    function setNumeraire(address numeraire_) external onlyOwner nonReentrant {
        if (creditor != address(0)) revert AccountErrors.CreditorAlreadySet();
        _setNumeraire(numeraire_);
    }

    /**
     * @notice Sets the Numeraire of the Account.
     * @param numeraire_ The new Numeraire for the Account.
     */
    function _setNumeraire(address numeraire_) internal {
        if (!IRegistry(registry).inRegistry(numeraire_)) revert AccountErrors.NumeraireNotFound();

        emit NumeraireSet(numeraire = numeraire_);
    }

    /* ///////////////////////////////////////////////////////////////
                    MARGIN ACCOUNT SETTINGS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Opens a margin account on the Account for a new Creditor.
     * @param newCreditor The contract address of the Creditor.
     * @dev Currently only one Creditor can be set
     * (we are working towards a single account for multiple Creditors tho!).
     * @dev Only open margin accounts for Creditors you trust!
     * The Creditor has significant authorization: use margin, trigger liquidation, and manage assets.
     */
    function openMarginAccount(address newCreditor)
        external
        onlyOwner
        nonReentrant
        notDuringAuction
        updateActionTimestamp
    {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();

        // Cache old Creditor.
        address oldCreditor = creditor;
        if (oldCreditor == newCreditor) revert AccountErrors.CreditorAlreadySet();

        // Remove the exposures of the Account for the old Creditor.
        if (oldCreditor != address(0)) {
            IRegistry(registry).batchProcessWithdrawal(oldCreditor, assetAddresses, assetIds, assetAmounts);
        }

        // Check if all assets in the Account are allowed by the new Creditor
        // and add the exposure of the account for the new Creditor.
        IRegistry(registry).batchProcessDeposit(newCreditor, assetAddresses, assetIds, assetAmounts);

        // Open margin account for the new Creditor.
        _openMarginAccount(newCreditor);

        // A margin account can only be opened for one Creditor at a time.
        // If set, close the margin account for the old Creditor.
        if (oldCreditor != address(0)) {
            // closeMarginAccount() checks if there is still an open position (open liabilities) of the Account for the old Creditor.
            // If so, the function reverts.
            ICreditor(oldCreditor).closeMarginAccount(address(this));
        }
    }

    /**
     * @notice Internal function: Opens a margin account for a new Creditor.
     * @param creditor_ The contract address of the Creditor.
     */
    function _openMarginAccount(address creditor_) internal {
        (bool success, address numeraire_, address liquidator_, uint256 minimumMargin_) =
            ICreditor(creditor_).openMarginAccount(ACCOUNT_VERSION);
        if (!success) revert AccountErrors.InvalidAccountVersion();

        minimumMargin = uint96(minimumMargin_);
        if (numeraire != numeraire_) _setNumeraire(numeraire_);

        emit MarginAccountChanged(creditor = creditor_, liquidator = liquidator_);
    }

    /**
     * @notice Closes the margin account of the Creditor.
     * @dev Currently only one Creditor can be set.
     */
    function closeMarginAccount() external onlyOwner nonReentrant notDuringAuction {
        // Cache creditor.
        address creditor_ = creditor;
        if (creditor_ == address(0)) revert AccountErrors.CreditorNotSet();

        creditor = address(0);
        liquidator = address(0);
        minimumMargin = 0;

        // Remove the exposures of the Account for the old Creditor.
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        IRegistry(registry).batchProcessWithdrawal(creditor_, assetAddresses, assetIds, assetAmounts);

        // closeMarginAccount() checks if there is still an open position (open liabilities) for the Account.
        // If so, the function reverts.
        ICreditor(creditor_).closeMarginAccount(address(this));

        emit MarginAccountChanged(address(0), address(0));
    }

    /**
     * @notice Sets an approved Creditor.
     * @param creditor_ The contract address of the approved Creditor.
     * @dev An approved Creditor is a Creditor for which no margin Account is immediately opened.
     * But the approved Creditor itself can open the margin Account later in time to e.g. refinance liabilities.
     * @dev Potential use-cases of the approved Creditor might be to:
     * - Refinance liabilities (change creditor) without having to sell collateral to close the current position first.
     * @dev Anyone can set the approved creditor for themselves, this will not impact the current owner of the Account
     * since the combination of "current owner -> approved creditor" is used in authentication checks.
     * This guarantees that when the ownership of the Account is transferred, the approved Creditor of the old owner has no
     * impact on the new owner. But the new owner can still remove any existing approved Creditors before the transfer.
     */
    function setApprovedCreditor(address creditor_) external {
        approvedCreditor[msg.sender] = creditor_;
    }

    /* ///////////////////////////////////////////////////////////////
                          MARGIN REQUIREMENTS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Calculates the total collateral value (MTM discounted with a haircut) of the Account.
     * @return collateralValue The collateral value, returned in the decimal precision of the Numeraire.
     * @dev Returns the value denominated in the Numeraire of the Account.
     * @dev The collateral value of the Account is equal to the spot value of the underlying assets,
     * discounted by a haircut (the collateral factor). Since the value of
     * collateralized assets can fluctuate, the haircut guarantees that the Account
     * remains over-collateralized with a high confidence level.
     * The size of the haircut depends on the underlying risk of the assets in the Account.
     * The bigger the volatility or the smaller the onchain liquidity, the bigger the haircut will be.
     */
    function getCollateralValue() public view returns (uint256 collateralValue) {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        collateralValue =
            IRegistry(registry).getCollateralValue(numeraire, creditor, assetAddresses, assetIds, assetAmounts);
    }

    /**
     * @notice Calculates the total liquidation value (MTM discounted with a factor to account for slippage) of the Account.
     * @return liquidationValue The liquidation value, returned in the decimal precision of the Numeraire.
     * @dev The liquidation value of the Account is equal to the spot value of the underlying assets,
     * discounted by a haircut (the liquidation factor).
     * The liquidation value takes into account that not the full value of the assets can go towards
     * repaying the liabilities: a fraction of the value is lost due to:
     * slippage while liquidating the assets,
     * fees for the auction initiator,
     * fees for the auction terminator and
     * a penalty to the protocol.
     */
    function getLiquidationValue() public view returns (uint256 liquidationValue) {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        liquidationValue =
            IRegistry(registry).getLiquidationValue(numeraire, creditor, assetAddresses, assetIds, assetAmounts);
    }

    /**
     * @notice Returns the used margin of the Account.
     * @return usedMargin The total amount of margin that is currently in use to back liabilities.
     * @dev Used Margin is the value of the assets that is currently 'locked' to back:
     *  - All the liabilities issued against the Account.
     *  - An additional fixed buffer to cover gas fees in case of a liquidation.
     * @dev The used margin is denominated in the Numeraire.
     * @dev Currently only one Creditor at a time can open a margin account.
     * The open liability is fetched at the contract of the Creditor -> only allow trusted audited Creditors!!!
     */
    function getUsedMargin() public view returns (uint256 usedMargin) {
        // Cache creditor
        address creditor_ = creditor;
        if (creditor_ == address(0)) return 0;

        // getOpenPosition() is a view function, cannot modify state.
        usedMargin = ICreditor(creditor_).getOpenPosition(address(this)) + minimumMargin;
    }

    /**
     * @notice Calculates the remaining margin the owner of the Account can use.
     * @return freeMargin The remaining amount of margin a user can take.
     * @dev Free Margin is the value of the assets that is still free to back additional liabilities.
     * @dev The free margin is denominated in the Numeraire.
     */
    function getFreeMargin() public view returns (uint256 freeMargin) {
        uint256 collateralValue = getCollateralValue();
        uint256 usedMargin = getUsedMargin();

        unchecked {
            freeMargin = collateralValue > usedMargin ? collateralValue - usedMargin : 0;
        }
    }

    /**
     * @notice Checks if the Account is unhealthy.
     * @return isUnhealthy Boolean indicating if the Account is unhealthy.
     */
    function isAccountUnhealthy() public view returns (bool isUnhealthy) {
        // If usedMargin is equal to minimumMargin, the open liabilities are 0 and the Account is always healthy.
        // An Account is unhealthy if the collateral value is smaller than the used margin.
        uint256 usedMargin = getUsedMargin();
        isUnhealthy = usedMargin > minimumMargin && getCollateralValue() < usedMargin;
    }

    /**
     * @notice Checks if the Account can be liquidated.
     * @return success Boolean indicating if the Account can be liquidated.
     */
    function isAccountLiquidatable() external view returns (bool success) {
        // If usedMargin is equal to minimumMargin, the open liabilities are 0 and the Account is never liquidatable.
        // An Account can be liquidated if the liquidation value is smaller than the used margin.
        uint256 usedMargin = getUsedMargin();
        success = usedMargin > minimumMargin && getLiquidationValue() < usedMargin;
    }

    /* ///////////////////////////////////////////////////////////////
                          LIQUIDATION LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Checks if an Account is liquidatable and continues the liquidation flow.
     * @param initiator The address of the liquidation initiator.
     * @return assetAddresses Array of the contract addresses of the assets in Account.
     * @return assetIds Array of the IDs of the assets in Account.
     * @return assetAmounts Array with the amounts of the assets in Account.
     * @return creditor_ The contract address of the Creditor.
     * @return minimumMargin_ The minimum margin.
     * @return openPosition The open position (liabilities) issued against the Account.
     * @return assetAndRiskValues Array of asset values and corresponding collateral and liquidation factors.
     */
    function startLiquidation(address initiator)
        external
        onlyLiquidator
        nonReentrant
        updateActionTimestamp
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            address creditor_,
            uint96 minimumMargin_,
            uint256 openPosition,
            AssetValueAndRiskFactors[] memory assetAndRiskValues
        )
    {
        inAuction = true;
        creditor_ = creditor;
        minimumMargin_ = minimumMargin;

        (assetAddresses, assetIds, assetAmounts) = generateAssetData();
        assetAndRiskValues =
            IRegistry(registry).getValuesInNumeraire(numeraire, creditor_, assetAddresses, assetIds, assetAmounts);

        // Since the function is only callable by the Liquidator, we know that a liquidator and a Creditor are set.
        openPosition = ICreditor(creditor_).startLiquidation(initiator, minimumMargin_);
        uint256 usedMargin = openPosition + minimumMargin_;

        if (openPosition == 0 || assetAndRiskValues._calculateLiquidationValue() >= usedMargin) {
            revert AccountErrors.AccountNotLiquidatable();
        }
    }

    /**
     * @notice Transfers the asset bought by a bidder during a liquidation event.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param bidder The address of the bidder.
     */
    function auctionBid(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        address bidder
    ) external onlyLiquidator nonReentrant {
        _withdraw(assetAddresses, assetIds, assetAmounts, bidder);
    }

    /**
     * @notice Transfers all assets of the Account in case the auction did not end successful (= Bought In).
     * @param recipient The recipient address to receive the assets, set by the Creditor.
     * @dev When an auction is not successful, the Account is considered "Bought In":
     * The whole Account including any remaining assets are transferred to a certain recipient address, set by the Creditor.
     */
    function auctionBoughtIn(address recipient) external onlyLiquidator nonReentrant {
        _transferOwnership(recipient);
    }

    /**
     * @notice Sets the "inAuction" flag to false when an auction ends.
     */
    function endAuction() external onlyLiquidator nonReentrant {
        inAuction = false;
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
        notDuringAuction
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
        _withdraw(withdrawData.assets, withdrawData.assetIds, withdrawData.assetAmounts, actionTarget);

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
        _deposit(depositData.assets, depositData.assetIds, depositData.assetAmounts, actionTarget);

        // Account must be healthy after actions are executed.
        if (isAccountUnhealthy()) revert AccountErrors.AccountUnhealthy();
    }

    /*///////////////////////////////////////////////////////////////
                        CREDITOR ACTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the actionTimestamp.
     * @dev Used to avoid frontrunning transfers of the account with actions in the Creditor.
     */
    function updateActionTimestampByCreditor() external onlyCreditor updateActionTimestamp { }

    /**
     * @notice Checks that the increase of the open position is allowed.
     * @param openPosition The new open position.
     * @return accountVersion The current Account version.
     * @dev The Account performs the following checks when an open position (liabilities) are increased:
     *  - The caller is indeed a Creditor for which a margin account is opened.
     *  - The Account is still healthy after given the new open position.
     */
    function increaseOpenPosition(uint256 openPosition)
        external
        onlyCreditor
        nonReentrant
        notDuringAuction
        updateActionTimestamp
        returns (uint256 accountVersion)
    {
        // If the open position is 0, the Account is always healthy.
        // An Account is unhealthy if the collateral value is smaller than the used margin.
        // The used margin equals the sum of the given open position and the minimum margin.
        if (openPosition > 0 && getCollateralValue() < openPosition + minimumMargin) {
            revert AccountErrors.AccountUnhealthy();
        }

        accountVersion = ACCOUNT_VERSION;
    }

    /**
     * @notice Executes a flash action initiated by a Creditor.
     * @param actionTarget actionTarget The contract address of the actionTarget to execute external logic.
     * @param actionData A bytes object containing three structs and two bytes objects.
     * The first struct contains the info about the assets to withdraw from this Account to the actionTarget.
     * The second struct contains the info about the owner's assets that need to be transferred from the owner to the actionTarget.
     * The third struct contains the permit for the Permit2 transfer.
     * The first bytes object contains the signature for the Permit2 transfer.
     * The second bytes object contains the encoded input for the actionTarget.
     * @return accountVersion The current Account version.
     * @dev This function optimistically chains multiple actions together (= do a flash action):
     * - Before calling this function, a Creditor can execute arbitrary logic (e.g. give a flashloan to the actionTarget).
     * - A margin Account can be opened for a new Creditor, if the new Creditor is approved by the Account Owner.
     * - It can optimistically withdraw assets from the Account to the actionTarget.
     * - It can transfer assets directly from the owner to the actionTarget.
     * - It can execute external logic on the actionTarget, and interact with any DeFi protocol to swap, stake, claim...
     * - It can deposit all recipient tokens from the actionTarget back into the Account.
     * At the very end of the flash action, the following checks are performed:
     * - The Account is in a healthy state (collateral value is greater than open liabilities).
     * - If a new margin Account is opened for a new Creditor, then the Account has no open positions anymore with the old Creditor.
     * If a check fails, the whole transaction reverts.
     * @dev This function can be used to refinance liabilities between different Creditors,
     * without the need to first sell collateral to close the open position of the old Creditor.
     */
    function flashActionByCreditor(address actionTarget, bytes calldata actionData)
        external
        nonReentrant
        notDuringAuction
        updateActionTimestamp
        returns (uint256 accountVersion)
    {
        // Cache the current Creditor.
        address currentCreditor = creditor;

        // The caller has to be or the Creditor of the Account, or an approved Creditor.
        if (msg.sender != currentCreditor && msg.sender != approvedCreditor[owner]) revert AccountErrors.OnlyCreditor();

        // Decode flash action data.
        (
            ActionData memory withdrawData,
            ActionData memory transferFromOwnerData,
            IPermit2.PermitBatchTransferFrom memory permit,
            bytes memory signature,
            bytes memory actionTargetData
        ) = abi.decode(actionData, (ActionData, ActionData, IPermit2.PermitBatchTransferFrom, bytes, bytes));

        // Withdraw assets to the actionTarget.
        _withdraw(withdrawData.assets, withdrawData.assetIds, withdrawData.assetAmounts, actionTarget);

        if (msg.sender != currentCreditor) {
            // If the caller is the approved Creditor, a margin Account must be opened for the approved Creditor.
            // And the exposures for the current and approved Creditors need to be updated.
            approvedCreditor[owner] = address(0);

            (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
                generateAssetData();

            // Remove the exposures of the Account for the current Creditor.
            if (currentCreditor != address(0)) {
                IRegistry(registry).batchProcessWithdrawal(currentCreditor, assetAddresses, assetIds, assetAmounts);
            }

            // Check if all assets in the Account are allowed by the approved Creditor
            // and add the exposure of the account for the approved Creditor.
            IRegistry(registry).batchProcessDeposit(msg.sender, assetAddresses, assetIds, assetAmounts);

            // Open margin account for the approved Creditor.
            _openMarginAccount(msg.sender);
        }

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
        _deposit(depositData.assets, depositData.assetIds, depositData.assetAmounts, actionTarget);

        if (currentCreditor != address(0) && msg.sender != currentCreditor) {
            // If the caller is the approved Creditor, the margin Account for the current Creditor (if set) must be closed.
            // closeMarginAccount() checks if there is still an open position (open liabilities) of the Account for the old Creditor.
            // If so, the function reverts.
            ICreditor(currentCreditor).closeMarginAccount(address(this));
        }

        // Account must be healthy after actions are executed.
        if (isAccountUnhealthy()) revert AccountErrors.AccountUnhealthy();

        accountVersion = ACCOUNT_VERSION;
    }

    /*///////////////////////////////////////////////////////////////
                          ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits assets into the Account.
     * @param assetAddresses Array of the contract addresses of the assets.
     * One address for each asset to be deposited, even if multiple assets of the same contract address are deposited.
     * @param assetIds Array of the IDs of the assets.
     * When depositing an ERC20 token, this will be disregarded, HOWEVER a value (eg. 0) must be set in the array!
     * @param assetAmounts Array with the amounts of the assets.
     * When depositing an ERC721 token, this will be disregarded, HOWEVER a value (eg. 1) must be set in the array!
     * @dev All arrays should be of same length, each index in each array corresponding
     * to the same asset that will get deposited. If multiple asset IDs of the same contract address
     * are deposited, the assetAddress must be repeated in assetAddresses.
     * Example inputs:
     * [wETH, DAI, BAYC, SandboxASSET], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
     * [SandboxASSET, SandboxASSET, BAYC, BAYC, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
     */
    function deposit(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts)
        external
        onlyOwner
        nonReentrant
        notDuringAuction
    {
        // No need to check that all arrays have equal length, this check will be done in the Registry.
        _deposit(assetAddresses, assetIds, assetAmounts, msg.sender);
    }

    /**
     * @notice Deposits assets into the Account.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param from The assets deposited into the Account will come from this address.
     */
    function _deposit(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        address from
    ) internal {
        // If no Creditor is set, batchProcessDeposit only checks if the assets can be priced.
        // If a Creditor is set, batchProcessDeposit will also update the exposures of assets and underlying assets for the Creditor.
        uint256[] memory assetTypes =
            IRegistry(registry).batchProcessDeposit(creditor, assetAddresses, assetIds, assetAmounts);

        for (uint256 i; i < assetAddresses.length; ++i) {
            // Skip if amount is 0 to prevent storing addresses that have 0 balance.
            if (assetAmounts[i] == 0) continue;

            if (assetTypes[i] == 0) {
                if (assetIds[i] != 0) revert AccountErrors.InvalidERC20Id();
                _depositERC20(from, assetAddresses[i], assetAmounts[i]);
            } else if (assetTypes[i] == 1) {
                if (assetAmounts[i] != 1) revert AccountErrors.InvalidERC721Amount();
                _depositERC721(from, assetAddresses[i], assetIds[i]);
            } else if (assetTypes[i] == 2) {
                _depositERC1155(from, assetAddresses[i], assetIds[i], assetAmounts[i]);
            } else {
                revert AccountErrors.UnknownAssetType();
            }
        }

        if (erc20Stored.length + erc721Stored.length + erc1155Stored.length > ASSET_LIMIT) {
            revert AccountErrors.TooManyAssets();
        }
    }

    /**
     * @notice Withdraws assets from the Account to the owner.
     * @param assetAddresses Array of the contract addresses of the assets.
     * One address for each asset to be withdrawn, even if multiple assets of the same contract address are withdrawn.
     * @param assetIds Array of the IDs of the assets.
     * For ERC20 assets, the id must be 0.
     * @param assetAmounts Array with the amounts of the assets.
     * For ERC721 assets, the amount must be 1.
     * @dev All arrays should be of same length, each index in each array corresponding
     * to the same asset that will get withdrawn. If multiple asset IDs of the same contract address
     * are to be withdrawn, the assetAddress must be repeated in assetAddresses.
     * Example inputs:
     * [wETH, DAI, BAYC, SandboxASSET], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
     * [SandboxASSET, SandboxASSET, BAYC, BAYC, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
     * @dev Will fail if the Account is in an unhealthy state after withdrawal (collateral value is smaller than the used margin).
     * If the Account has no open position (liabilities), users are free to withdraw any asset at any time.
     */
    function withdraw(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts)
        external
        onlyOwner
        nonReentrant
        notDuringAuction
        updateActionTimestamp
    {
        // No need to check that all arrays have equal length, this check is will be done in the Registry.
        _withdraw(assetAddresses, assetIds, assetAmounts, msg.sender);

        // Account must be healthy after assets are withdrawn.
        if (isAccountUnhealthy()) revert AccountErrors.AccountUnhealthy();
    }

    /**
     * @notice Withdraws assets from the Account to the owner.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param to The address to withdraw to.
     * @dev (batch)ProcessWithdrawal handles the accounting of assets in the Registry.
     */
    function _withdraw(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        address to
    ) internal {
        // If a Creditor is set, batchProcessWithdrawal will also update the exposures of assets and underlying assets for the Creditor.
        uint256[] memory assetTypes =
            IRegistry(registry).batchProcessWithdrawal(creditor, assetAddresses, assetIds, assetAmounts);

        for (uint256 i; i < assetAddresses.length; ++i) {
            // Skip if amount is 0 to prevent transferring 0 balances.
            if (assetAmounts[i] == 0) continue;

            if (assetTypes[i] == 0) {
                if (assetIds[i] != 0) revert AccountErrors.InvalidERC20Id();
                _withdrawERC20(to, assetAddresses[i], assetAmounts[i]);
            } else if (assetTypes[i] == 1) {
                if (assetAmounts[i] != 1) revert AccountErrors.InvalidERC721Amount();
                _withdrawERC721(to, assetAddresses[i], assetIds[i]);
            } else if (assetTypes[i] == 2) {
                _withdrawERC1155(to, assetAddresses[i], assetIds[i], assetAmounts[i]);
            } else {
                revert AccountErrors.UnknownAssetType();
            }
        }
    }

    /**
     * @notice Internal function to deposit ERC20 assets.
     * @param from Address the tokens should be transferred from. This address must have approved the Account.
     * @param ERC20Address The contract address of the asset.
     * @param amount The amount of ERC20 assets.
     * @dev Used for all asset type == 0.
     * @dev If the token has not yet been deposited, the ERC20 token address is stored.
     */
    function _depositERC20(address from, address ERC20Address, uint256 amount) internal {
        ERC20(ERC20Address).safeTransferFrom(from, address(this), amount);

        uint256 currentBalance = erc20Balances[ERC20Address];

        if (currentBalance == 0) {
            erc20Stored.push(ERC20Address);
        }

        unchecked {
            erc20Balances[ERC20Address] = currentBalance + amount;
        }
    }

    /**
     * @notice Internal function to deposit ERC721 tokens.
     * @param from Address the tokens should be transferred from. This address must have approved the Account.
     * @param ERC721Address The contract address of the asset.
     * @param id The ID of the ERC721 token.
     * @dev Used for all asset type == 1.
     * @dev After successful transfer, the function pushes the ERC721 address to the stored token and stored ID array.
     * This may cause duplicates in the ERC721 stored addresses array, but this is intended.
     */
    function _depositERC721(address from, address ERC721Address, uint256 id) internal {
        IERC721(ERC721Address).safeTransferFrom(from, address(this), id);

        erc721Stored.push(ERC721Address);
        erc721TokenIds.push(id);
    }

    /**
     * @notice Internal function to deposit ERC1155 tokens.
     * @param from The Address the tokens should be transferred from. This address must have approved the Account.
     * @param ERC1155Address The contract address of the asset.
     * @param id The ID of the ERC1155 tokens.
     * @param amount The amount of ERC1155 tokens.
     * @dev Used for all asset type == 2.
     * @dev After successful transfer, the function checks whether the combination of address & ID has already been stored.
     * If not, the function pushes the new address and ID to the stored arrays.
     * This may cause duplicates in the ERC1155 stored addresses array, this is intended.
     */
    function _depositERC1155(address from, address ERC1155Address, uint256 id, uint256 amount) internal {
        IERC1155(ERC1155Address).safeTransferFrom(from, address(this), id, amount, "");

        uint256 currentBalance = erc1155Balances[ERC1155Address][id];

        if (currentBalance == 0) {
            erc1155Stored.push(ERC1155Address);
            erc1155TokenIds.push(id);
        }

        unchecked {
            erc1155Balances[ERC1155Address][id] = currentBalance + amount;
        }
    }

    /**
     * @notice Internal function to withdraw ERC20 assets.
     * @param to Address the tokens should be sent to.
     * @param ERC20Address The contract address of the asset.
     * @param amount The amount of ERC20 assets.
     * @dev Used for all asset type == 0.
     * @dev The function checks whether the Account has any leftover balance of said asset.
     * If not, it will pop() the ERC20 asset address from the stored addresses array.
     * Note: this shifts the order of erc20Stored!
     * @dev This check is done using a loop:
     * gas usage of writing it in a mapping vs extra loops is in favor of extra loops in this case.
     */
    function _withdrawERC20(address to, address ERC20Address, uint256 amount) internal {
        erc20Balances[ERC20Address] -= amount;

        if (erc20Balances[ERC20Address] == 0) {
            uint256 erc20StoredLength = erc20Stored.length;

            if (erc20StoredLength == 1) {
                // There was only one ERC20 stored on the contract, safe to remove from array.
                erc20Stored.pop();
            } else {
                for (uint256 i; i < erc20StoredLength; ++i) {
                    if (erc20Stored[i] == ERC20Address) {
                        erc20Stored[i] = erc20Stored[erc20StoredLength - 1];
                        erc20Stored.pop();
                        break;
                    }
                }
            }
        }

        ERC20(ERC20Address).safeTransfer(to, amount);
    }

    /**
     * @notice Internal function to withdraw ERC721 tokens.
     * @param to Address the tokens should be sent to.
     * @param ERC721Address The contract address of the asset.
     * @param id The ID of the ERC721 token.
     * @dev Used for all asset type == 1.
     * @dev The function checks whether any other ERC721 is deposited in the Account.
     * If not, it pops the stored addresses and stored IDs (pop() of two arrays is 180 gas cheaper than deleting).
     * If there are, it loops through the stored arrays and searches the ID that's withdrawn,
     * then replaces it with the last index, followed by a pop().
     * @dev Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
     */
    function _withdrawERC721(address to, address ERC721Address, uint256 id) internal {
        uint256 tokenIdLength = erc721TokenIds.length;

        uint256 i;
        if (tokenIdLength == 1) {
            // There was only one ERC721 stored on the contract, safe to remove both lists.
            if (erc721TokenIds[0] != id || erc721Stored[0] != ERC721Address) revert AccountErrors.UnknownAsset();
            erc721TokenIds.pop();
            erc721Stored.pop();
        } else {
            for (; i < tokenIdLength; ++i) {
                if (erc721TokenIds[i] == id && erc721Stored[i] == ERC721Address) {
                    erc721TokenIds[i] = erc721TokenIds[tokenIdLength - 1];
                    erc721TokenIds.pop();
                    erc721Stored[i] = erc721Stored[tokenIdLength - 1];
                    erc721Stored.pop();
                    break;
                }
            }
            // For loop should break, otherwise we never went into the if-branch, meaning the token being withdrawn
            // is unknown and not properly deposited.
            // i + 1 is done after loop, so i reaches tokenIdLength.
            if (i == tokenIdLength) revert AccountErrors.UnknownAsset();
        }

        IERC721(ERC721Address).safeTransferFrom(address(this), to, id);
    }

    /**
     * @notice Internal function to withdraw ERC1155 tokens.
     * @param to Address the tokens should be sent to.
     * @param ERC1155Address The contract address of the asset.
     * @param id The ID of the ERC1155 tokens.
     * @param amount The amount of ERC1155 tokens.
     * @dev Used for all asset types = 2.
     * @dev After successful transfer, the function checks whether there is any balance left for that ERC1155.
     * If there is, it simply transfers the tokens.
     * If not, it checks whether it can pop() (used for gas savings vs delete) the stored arrays.
     * If there are still other ERC1155's on the contract, it looks for the ID and token address to be withdrawn
     * and then replaces it with the last index, followed by a pop().
     * @dev Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
     */
    function _withdrawERC1155(address to, address ERC1155Address, uint256 id, uint256 amount) internal {
        uint256 tokenIdLength = erc1155TokenIds.length;

        erc1155Balances[ERC1155Address][id] -= amount;

        if (erc1155Balances[ERC1155Address][id] == 0) {
            if (tokenIdLength == 1) {
                erc1155TokenIds.pop();
                erc1155Stored.pop();
            } else {
                for (uint256 i; i < tokenIdLength; ++i) {
                    if (erc1155TokenIds[i] == id) {
                        if (erc1155Stored[i] == ERC1155Address) {
                            erc1155TokenIds[i] = erc1155TokenIds[tokenIdLength - 1];
                            erc1155TokenIds.pop();
                            erc1155Stored[i] = erc1155Stored[tokenIdLength - 1];
                            erc1155Stored.pop();
                            break;
                        }
                    }
                }
            }
        }

        IERC1155(ERC1155Address).safeTransferFrom(address(this), to, id, amount, "");
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

            if (transferFromOwnerData.assetTypes[i] == 0) {
                ERC20(transferFromOwnerData.assets[i]).safeTransferFrom(
                    owner_, to, transferFromOwnerData.assetAmounts[i]
                );
            } else if (transferFromOwnerData.assetTypes[i] == 1) {
                IERC721(transferFromOwnerData.assets[i]).safeTransferFrom(owner_, to, transferFromOwnerData.assetIds[i]);
            } else if (transferFromOwnerData.assetTypes[i] == 2) {
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

    /**
     * @notice Skims non-deposited assets from the Account.
     * @param token The contract address of the asset.
     * @param id The ID of the asset.
     * @param type_ The asset type of the asset.
     * @dev Function can retrieve assets that were transferred to the Account but not deposited
     * or can be used to claim yield for strictly upwards rebasing tokens.
     */
    function skim(address token, uint256 id, uint256 type_) public onlyOwner nonReentrant updateActionTimestamp {
        if (token == address(0)) {
            (bool success, bytes memory result) = payable(msg.sender).call{ value: address(this).balance }("");
            require(success, string(result));
            return;
        }

        if (type_ == 0) {
            uint256 balance = ERC20(token).balanceOf(address(this));
            uint256 balanceStored = erc20Balances[token];
            if (balance > balanceStored) {
                ERC20(token).safeTransfer(msg.sender, balance - balanceStored);
            }
        } else if (type_ == 1) {
            bool isStored;
            uint256 erc721StoredLength = erc721Stored.length;
            for (uint256 i; i < erc721StoredLength; ++i) {
                if (erc721Stored[i] == token && erc721TokenIds[i] == id) {
                    isStored = true;
                    break;
                }
            }

            if (!isStored) {
                IERC721(token).safeTransferFrom(address(this), msg.sender, id);
            }
        } else if (type_ == 2) {
            uint256 balance = IERC1155(token).balanceOf(address(this), id);
            uint256 balanceStored = erc1155Balances[token][id];

            if (balance > balanceStored) {
                IERC1155(token).safeTransferFrom(address(this), msg.sender, id, balance - balanceStored, "");
            }
        }
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Returns the total value (mark to market) of the Account in a specific Numeraire
     * @param numeraire_ The Numeraire to return the value in.
     * @return accountValue Total value stored in the account, denominated in Numeraire.
     * @dev Fetches all stored assets with their amounts.
     * Using a specified Numeraire, fetches the value of all assets in said Numeraire.
     */
    function getAccountValue(address numeraire_) external view returns (uint256 accountValue) {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        accountValue = IRegistry(registry).getTotalValue(numeraire_, creditor, assetAddresses, assetIds, assetAmounts);
    }

    /**
     * @notice Generates three arrays of all the stored assets in the Account.
     * @return assetAddresses Array of the contract addresses of the assets.
     * @return assetIds Array of the IDs of the assets.
     * @return assetAmounts Array with the amounts of the assets.
     * @dev Balances are stored on the contract to prevent working around the deposit limits.
     * @dev Loops through the stored asset addresses and fills the arrays.
     * @dev There is no importance of the order in the arrays, but all indexes of the arrays correspond to the same asset.
     */
    function generateAssetData()
        public
        view
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        uint256 totalLength;
        unchecked {
            totalLength = erc20Stored.length + erc721Stored.length + erc1155Stored.length;
        } // Cannot realistically overflow.
        assetAddresses = new address[](totalLength);
        assetIds = new uint256[](totalLength);
        assetAmounts = new uint256[](totalLength);

        uint256 i;
        uint256 erc20StoredLength = erc20Stored.length;
        address cacheAddr;
        for (; i < erc20StoredLength; ++i) {
            cacheAddr = erc20Stored[i];
            assetAddresses[i] = cacheAddr;
            // Gas: no need to store 0, index will continue anyway.
            // assetIds[i] = 0;
            assetAmounts[i] = erc20Balances[cacheAddr];
        }

        uint256 j;
        uint256 erc721StoredLength = erc721Stored.length;
        for (; j < erc721StoredLength; ++j) {
            cacheAddr = erc721Stored[j];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = erc721TokenIds[j];
            assetAmounts[i] = 1;
            unchecked {
                ++i;
            }
        }

        uint256 k;
        uint256 erc1155StoredLength = erc1155Stored.length;
        uint256 cacheId;
        for (; k < erc1155StoredLength; ++k) {
            cacheAddr = erc1155Stored[k];
            cacheId = erc1155TokenIds[k];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = cacheId;
            assetAmounts[i] = erc1155Balances[cacheAddr][cacheId];
            unchecked {
                ++i;
            }
        }
    }

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
