/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountStorageV2 } from "./AccountStorageV2.sol";
import { ERC20, SafeTransferLib } from "../../../../lib/solmate/src/utils/SafeTransferLib.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { IERC721 } from "../../../../src/interfaces/IERC721.sol";
import { IERC1155 } from "../../../../src/interfaces/IERC1155.sol";
import { IRegistry } from "../../../../src/interfaces/IRegistry.sol";
import { ICreditor } from "../../../../src/interfaces/ICreditor.sol";
import { IActionBase, ActionData } from "../../../../src/interfaces/IActionBase.sol";
import { IAccount } from "../../../../src/interfaces/IAccount.sol";
import { IFactory } from "../../../../src/interfaces/IFactory.sol";
import { IPermit2 } from "../../../../src/interfaces/IPermit2.sol";

/**
 * @title An Arcadia Account used to deposit a combination of all kinds of assets
 * @author Pragma Labs
 * @notice Users can use this Account to deposit assets (ERC20, ERC721, ERC1155, ...).
 * The Account will denominate all the pooled assets into one Numeraire (one unit of account, like USD or ETH).
 * An increase of value of one asset will offset a decrease in value of another asset.
 * Users can take out a credit line against the single denominated value.
 * Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
 * @dev An Account is a smart contract that will contain multiple assets.
 * Using getValue(<Numeraire>), the Account returns the combined total value of all (allowed) assets the Account contains.
 * Integrating this Account as means of collateral management for your own protocol that requires collateral is encouraged.
 * Arcadia's Account functions will guarantee you a certain value of the Account.
 * For whitelists or liquidation strategies specific to your protocol, contact: dev at arcadia.finance
 */
contract AccountV2 is AccountStorageV2 {
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Storage slot with the address of the current implementation.
    // This is the hardcoded keccak-256 hash of: "eip1967.proxy.implementation" subtracted by 1.
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // The maximum amount of different assets that can be used as collateral within an Arcadia Account.
    uint256 public constant ASSET_LIMIT = 15;
    // The current Account Version.
    uint256 public constant ACCOUNT_VERSION = 2;
    // The contract address of the Arcadia Accounts Factory.
    address public immutable FACTORY;
    // Uniswap Permit2 contract
    IPermit2 internal immutable permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    // Storage slot for the Account logic, a struct to avoid storage conflict when dealing with upgradeable contracts.
    struct AddressSlot {
        address value;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AssetManagerSet(address indexed owner, address indexed assetManager, bool value);
    event NumeraireSet(address indexed numeraire);
    event MarginAccountChanged(address indexed creditor, address indexed liquidator);

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
     * @dev Throws if called by any account other than the factory address.
     */
    modifier onlyFactory() {
        if (msg.sender != FACTORY) revert AccountErrors.OnlyFactory();
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert AccountErrors.OnlyOwner();
        _;
    }

    /**
     * @dev Throws if called by any account other than an Asset Manager or the owner.
     */
    modifier onlyAssetManager() {
        // A custom error would need to read out owner + creditor + isAssetManager storage
        require(
            msg.sender == owner || msg.sender == creditor || isAssetManager[owner][msg.sender], "A: Only Asset Manager"
        );
        _;
    }

    /**
     * @dev Throws if called by any account other than the Liquidator address.
     */
    modifier onlyLiquidator() {
        if (msg.sender != liquidator) revert AccountErrors.OnlyLiquidator();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param factory The contract address of the Arcadia Accounts Factory.
     */
    constructor(address factory) {
        // This will only be the owner of the Account logic implementation.
        // and will not affect any subsequent proxy implementation using this Account logic.
        owner = msg.sender;

        FACTORY = factory;
    }

    /* ///////////////////////////////////////////////////////////////
                          ACCOUNT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Initiates the variables of the Account.
     * @dev A proxy will be used to interact with the Account logic.
     * Therefore everything is initialised through an init function.
     * This function will only be called (once) in the same transaction as the proxy Account creation through the factory.
     * @param owner_ The sender of the 'createAccount' on the factory
     * @param registry_ The 'beacon' contract with the external logic.
     * @param numeraire_ The Numeraire in which the Account is denominated.
     * @param creditor_ The contract address of the creditor.
     */
    function initialize(address owner_, address registry_, address numeraire_, address creditor_) external {
        if (registry != address(0)) revert AccountErrors.AlreadyInitialized();
        if (registry_ == address(0)) revert AccountErrors.InvalidRegistry();
        owner = owner_;
        registry = registry_;
        numeraire = numeraire_;

        if (creditor_ != address(0)) {
            _openMarginAccount(creditor_);
        }

        emit NumeraireSet(numeraire_);
    }

    /**
     * @notice Updates the Account version and stores a new address in the EIP1967 implementation slot.
     * @param newImplementation The contract with the new Account logic.
     * @param newRegistry The Registry for this specific implementation (might be identical as the old registry).
     * @param data Arbitrary data, can contain instructions to execute when updating Account to new logic.
     * @param newVersion The new version of the Account logic.
     */
    function upgradeAccount(address newImplementation, address newRegistry, uint16 newVersion, bytes calldata data)
        external
        onlyFactory
    {
        if (creditor != address(0)) {
            // If a creditor is set, new version should be compatible.
            // openMarginAccount() is a view function, cannot modify state.
            (bool success,,,) = ICreditor(creditor).openMarginAccount(newVersion);
            if (!success) revert AccountErrors.InvalidAccountVersion();
        }

        // Cache old parameters
        address oldImplementation = _getAddressSlot(IMPLEMENTATION_SLOT).value;
        address oldRegistry = registry;
        uint256 oldVersion = ACCOUNT_VERSION;
        _getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
        registry = newRegistry;

        // Hook on the new logic to finalize upgrade.
        // Used to eg. Remove exposure from old Registry and Add exposure to the new Registry.
        // Extra data can be added by the factory for complex instructions.
        this.upgradeHook(oldImplementation, oldRegistry, oldVersion, data);

        // Event emitted by Factory.
    }

    /**
     * @notice Returns an `AddressSlot` with member `value` located at `slot`.
     * @param slot The slot where the address of the Logic contract is stored.
     * @return r The address stored in slot.
     */
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /* ///////////////////////////////////////////////////////////////
                        OWNERSHIP MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Transfers ownership of the contract to a new account.
     * @param newOwner The new owner of the Account.
     * @dev Can only be called by the current owner via the factory.
     * A transfer of ownership of the Account is triggered by a transfer
     * of ownership of the accompanying ERC721 Account NFT, issued by the factory.
     * Owner of Account NFT = owner of Account
     */
    function transferOwnership(address newOwner) external onlyFactory {
        if (newOwner == address(0)) revert AccountErrors.InvalidRecipient();
        _transferOwnership(newOwner);
    }

    /**
     * @notice Transfers ownership of the contract to a new account (`newOwner`).
     * @param newOwner The new owner of the Account.
     */
    function _transferOwnership(address newOwner) internal {
        owner = newOwner;

        // Event emitted by Factory.
    }

    /* ///////////////////////////////////////////////////////////////
                        BASE CURRENCY LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets the Numeraire of an Account.
     * @param numeraire_ the new Numeraire for the Account.
     * @dev First checks if there is no creditor set,
     * if there is none set, then a new Numeraire is set.
     */
    function setNumeraire(address numeraire_) external onlyOwner {
        if (creditor != address(0)) revert AccountErrors.CreditorAlreadySet();
        _setNumeraire(numeraire_);
    }

    /**
     * @notice Internal function: sets Numeraire.
     * @param numeraire_ the new Numeraire for the Account.
     */
    function _setNumeraire(address numeraire_) internal {
        if (!IRegistry(registry).inRegistry(numeraire_)) revert AccountErrors.NumeraireNotFound();
        numeraire = numeraire_;

        emit NumeraireSet(numeraire_);
    }

    /* ///////////////////////////////////////////////////////////////
                    MARGIN ACCOUNT SETTINGS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Opens a margin account on the Account for a Creditor.
     * @param creditor_ The contract address of the Creditor.
     * @dev Currently only one Creditor can be set
     * (we are working towards a single account for multiple creditors tho!).
     * @dev Only open margin accounts for protocols you trust!
     * The Creditor has significant authorisation: use margin, trigger liquidation, and manage assets.
     */
    function openMarginAccount(address creditor_) external onlyOwner {
        if (creditor != address(0)) revert AccountErrors.CreditorAlreadySet();
        _openMarginAccount(creditor_);
    }

    /**
     * @notice Internal function: Opens a margin account on the Account for a Creditor.
     * @param creditor_ The contract address of the Creditor.
     */
    function _openMarginAccount(address creditor_) internal {
        // openMarginAccount() is a view function, cannot modify state.
        (bool success, address numeraire_, address liquidator_, uint256 minimumMargin_) =
            ICreditor(creditor_).openMarginAccount(ACCOUNT_VERSION);
        if (!success) revert AccountErrors.InvalidAccountVersion();

        liquidator = liquidator_;
        creditor = creditor_;
        minimumMargin = uint96(minimumMargin_);
        if (numeraire != numeraire_) {
            _setNumeraire(numeraire_);
        }

        emit MarginAccountChanged(creditor_, liquidator_);
    }

    /**
     * @notice Closes the margin account on the Account of the trusted application..
     * @dev Currently only one creditor can be set.
     */
    function closeMarginAccount() external onlyOwner {
        // Cache creditor
        address creditor_ = creditor;
        if (creditor_ == address(0)) revert AccountErrors.CreditorNotSet();
        // closeMarginAccount() checks if there is still open position. If so, reverts.
        ICreditor(creditor_).closeMarginAccount(address(this));

        creditor = address(0);
        liquidator = address(0);
        minimumMargin = 0;

        emit MarginAccountChanged(address(0), address(0));
    }

    /* ///////////////////////////////////////////////////////////////
                          MARGIN REQUIREMENTS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Checks if the Account is healthy and still has free margin.
     * @param debtIncrease The amount with which the debt is increased.
     * @param totalOpenDebt The total open Debt against the Account.
     * @return success Boolean indicating if there is sufficient margin to back a certain amount of Debt.
     * @return creditor_ The contract address of the creditor.
     * @return accountVersion_ The Account version.
     * @dev An Account is healthy if the Collateral value is bigger than or equal to the Used Margin.
     * @dev Only one of the values can be non-zero, or we check on a certain increase of debt, or we check on a total amount of debt.
     * @dev If both values are zero, we check if the Account is currently healthy.
     */
    function isAccountHealthy(uint256 debtIncrease, uint256 totalOpenDebt)
        external
        view
        returns (bool success, address creditor_, uint256 accountVersion_)
    {
        if (totalOpenDebt > 0) {
            // Check if Account is healthy for a given amount of openDebt.
            // The total Used margin equals the sum of the given amount of openDebt and the gas cost to liquidate.
            success = getCollateralValue() >= totalOpenDebt + minimumMargin;
        } else {
            // Check if Account is still healthy after an increase of debt.
            // The gas cost to liquidate is already taken into account in getUsedMargin().
            success = getCollateralValue() >= getUsedMargin() + debtIncrease;
        }

        return (success, creditor, ACCOUNT_VERSION);
    }

    /**
     * @notice Checks if the Account can be liquidated.
     * @return success Boolean indicating if the Account can be liquidated.
     */
    function isAccountLiquidatable() external view returns (bool success) {
        // If usedMargin is equal to minimumMargin, the open liabilities are 0 and the Account is never liquidatable.
        uint256 usedMargin = getUsedMargin();
        if (usedMargin > minimumMargin) {
            // An Account can be liquidated if the Liquidation value is smaller than the Used Margin.
            success = getLiquidationValue() < usedMargin;
        }
    }

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
     * @notice Calculates the total collateral value (MTM discounted with a haircut) of the Account.
     * @return collateralValue The collateral value, returned in the decimal precision of the Numeraire.
     * @dev Returns the value denominated in the Numeraire of the Account.
     * @dev The collateral value of the Account is equal to the spot value of the underlying assets,
     * discounted by a haircut (the collateral factor). Since the value of
     * collateralized assets can fluctuate, the haircut guarantees that the Account
     * remains over-collateralized with a high confidence level (99,9%+). The size of the
     * haircut depends on the underlying risk of the assets in the Account, the bigger the volatility
     * or the smaller the onchain liquidity, the bigger the haircut will be.
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
     * @dev Returns the value denominated in the Numeraire of the Account.
     * @dev The liquidation value of the Account is equal to the spot value of the underlying assets,
     * discounted by a haircut (the liquidation factor).
     * The liquidation value takes into account that not the full value of the assets can go towards
     * repaying the debt: a fraction of the value is lost due to:
     * slippage while liquidating the assets, fees for the auction initiator and a penalty to the protocol.
     */
    function getLiquidationValue() public view returns (uint256 liquidationValue) {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        liquidationValue =
            IRegistry(registry).getLiquidationValue(numeraire, creditor, assetAddresses, assetIds, assetAmounts);
    }

    /**
     * @notice Returns the used margin of the Account.
     * @return usedMargin The total amount of Margin that is currently in use to back liabilities.
     * @dev Used Margin is the value of the assets that is currently 'locked' to back:
     *  - All the liabilities issued against the Account.
     *  - An additional fixed buffer to cover gas fees in case of a liquidation.
     * @dev The used margin is denominated in the Numeraire.
     * @dev Currently only one trusted application (Arcadia Lending) can open a margin account.
     * The open liability is fetched at the contract of the application -> only allow trusted audited creditors!!!
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

        // gas: explicit check is done to prevent underflow.
        unchecked {
            freeMargin = collateralValue > usedMargin ? collateralValue - usedMargin : 0;
        }
    }

    /* ///////////////////////////////////////////////////////////////
                          LIQUIDATION LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Checks if an Account is liquidatable and continues the liquidation flow.
     * @return assetAddresses Array of the contract addresses of the assets in Account.
     * @return assetIds Array of the IDs of the assets in Account.
     * @return assetAmounts Array with the amounts of the assets in Account.
     * @return owner_ Owner of the account.
     * @return creditor_ The creditor, address 0 if no active Creditor.
     * @return openDebt The open Debt issued against the Account.
     * @return assetAndRiskValues Array of asset values and corresponding collateral factors.
     */
    function startLiquidation(address liquidationInitiator)
        external
        nonReentrant
        onlyLiquidator
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            address owner_,
            address creditor_,
            uint256 openDebt,
            AssetValueAndRiskFactors[] memory assetAndRiskValues
        )
    {
        owner_ = owner;
        creditor_ = creditor;

        (assetAddresses, assetIds, assetAmounts) = generateAssetData();
        assetAndRiskValues =
            IRegistry(registry).getValuesInNumeraire(numeraire, creditor_, assetAddresses, assetIds, assetAmounts);

        // Since the function is only callable by the liquidator, a liquidator and a Creditor are set.
        openDebt = ICreditor(creditor).startLiquidation(liquidationInitiator, minimumMargin);
        uint256 usedMargin = openDebt + minimumMargin;

        if (openDebt == 0 || AssetValuationLib._calculateLiquidationValue(assetAndRiskValues) >= usedMargin) {
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
    ) external onlyLiquidator {
        _withdraw(assetAddresses, assetIds, assetAmounts, bidder);
    }

    /**
     * @notice Transfers all assets of the Account in case the auction did not end successful (= Bought In).
     * @param to The recipient's address to receive the assets, set by the Creditor.
     * @dev When an auction is not successful, the assets are considered "Bought In" (auction terminology):
     * Any remaining assets in the Account are transferred to a certain recipient address, set by the creditor.
     */
    function auctionBoughtIn(address to) external onlyLiquidator {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        _withdraw(assetAddresses, assetIds, assetAmounts, to);
    }

    /*///////////////////////////////////////////////////////////////
                    ASSET MANAGEMENT LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Add or remove an Asset Manager.
     * @param assetManager the address of the Asset Manager
     * @param value A boolean giving permissions to or taking permissions from an Asset Manager
     * @dev Only set trusted addresses as Asset Manager, Asset Managers can potentially steal assets (as long as the Account position remains healthy).
     * @dev No need to set the Owner as Asset Manager, owner will automatically have all permissions of an Asset Manager.
     * @dev Potential use-cases of the Asset Manager might be to:
     * - Automate actions by keeper networks,
     * - Chain interactions with the Creditor together with Account actions (eg. borrow deposit and trade in one transaction).
     */
    function setAssetManager(address assetManager, bool value) external onlyOwner {
        emit AssetManagerSet(msg.sender, assetManager, isAssetManager[msg.sender][assetManager] = value);
    }

    /**
     * @notice Calls external Action Multicall to execute and interact with external logic.
     * @param actionData A bytes object containing three actionAssetData structs, an address array and a bytes array.
     * The first struct contains the info about the assets to withdraw from this Account to the actionTarget.
     * The second struct contains the info about the owner's assets that are not in this Account and need to be transferred to the actionTarget.
     * The third struct contains the permit for the Permit2 transfer.
     * @param signature The signature to verify.
     * @param actionTarget The address of the Action Multicall.
     * @return creditor_ The contract address of the Creditor.
     * @return accountVersion_ The Account version.
     * @dev Similar to flash loans, this function optimistically calls external logic and checks for the Account state at the very end.
     * This allows users to interact with and chain together any DeFi protocol to swap, stake, claim...
     * The only requirements are that the recipient tokens of the interactions are allowlisted, deposited back into the Account and
     * that the Account is in a healthy state at the end of the transaction.
     */
    function flashAction(bytes calldata actionData, bytes calldata signature, address actionTarget)
        external
        nonReentrant
        onlyAssetManager
        returns (address, uint256)
    {
        (
            ActionData memory withdrawData,
            ActionData memory transferFromOwnerData,
            IPermit2.PermitBatchTransferFrom memory permit,
            bytes memory actionTargetData
        ) = abi.decode(actionData, (ActionData, ActionData, IPermit2.PermitBatchTransferFrom, bytes));

        // Withdraw assets to actionTarget.
        _withdraw(withdrawData.assets, withdrawData.assetIds, withdrawData.assetAmounts, actionTarget);

        // Transfer assets from owner (that are not assets in this account) to actionTarget.
        if (transferFromOwnerData.assets.length > 0) {
            _transferFromOwner(transferFromOwnerData, actionTarget);
        }

        // If the function input includes a signature and non-empty token permissions, initiate a transfer via Permit2.
        if (signature.length > 0 && permit.permitted.length > 0) {
            _transferFromOwnerWithPermit(permit, signature, actionTarget);
        }

        // Execute Action(s).
        ActionData memory depositData = IActionBase(actionTarget).executeAction(actionTargetData);

        // Deposit assets from actionTarget into Account.
        _deposit(depositData.assets, depositData.assetIds, depositData.assetAmounts, actionTarget);

        // If usedMargin is equal to minimumMargin, the open liabilities are 0 and the Account is always in a healthy state.
        uint256 usedMargin = getUsedMargin();
        // Account must be healthy after actions are executed.
        if (usedMargin > minimumMargin && getCollateralValue() < usedMargin) {
            revert AccountErrors.AccountUnhealthy();
        }

        return (creditor, ACCOUNT_VERSION);
    }

    /* ///////////////////////////////////////////////////////////////
                    ASSET DEPOSIT/WITHDRAWN LOGIC
    /////////////////////////////////////////////////////////////// */

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
     * [wETH, DAI, BAYC, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
     * [Interleave, Interleave, BAYC, BAYC, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
     */
    function deposit(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts)
        external
        onlyOwner
    {
        // No need to check that all arrays have equal length, this check is already done in the Registry.
        _deposit(assetAddresses, assetIds, assetAmounts, msg.sender);
    }

    /**
     * @notice Deposits assets into the Account.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param from The address to withdraw the assets from.
     */
    function _deposit(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        address from
    ) internal {
        // Reverts in registry if input is invalid.
        uint256[] memory assetTypes =
            IRegistry(registry).batchProcessDeposit(creditor, assetAddresses, assetIds, assetAmounts);

        uint256 assetAddressesLength = assetAddresses.length;
        for (uint256 i; i < assetAddressesLength;) {
            if (assetAmounts[i] == 0) {
                // Skip if amount is 0 to prevent storing addresses that have 0 balance.
                // ToDo silent fail or should we revert here?
                unchecked {
                    ++i;
                }
                continue;
            }

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
            unchecked {
                ++i;
            }
        }

        if (erc20Stored.length + erc721Stored.length + erc1155Stored.length > ASSET_LIMIT) {
            revert AccountErrors.TooManyAssets();
        }
    }

    /**
     * @notice Withdrawals assets from the Account to the owner.
     * @param assetAddresses Array of the contract addresses of the assets.
     * One address for each asset to be withdrawn, even if multiple assets of the same contract address are withdrawn.
     * @param assetIds Array of the IDs of the assets.
     * When withdrawing an ERC20 token, this will be disregarded, HOWEVER a value (eg. 0) must be set in the array!
     * @param assetAmounts Array with the amounts of the assets.
     * When withdrawing an ERC721 token, this will be disregarded, HOWEVER a value (eg. 1) must be set in the array!
     * @dev All arrays should be of same length, each index in each array corresponding
     * to the same asset that will get withdrawn. If multiple asset IDs of the same contract address
     * are to be withdrawn, the assetAddress must be repeated in assetAddresses.
     * Example inputs:
     * [wETH, DAI, BAYC, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
     * [Interleave, Interleave, BAYC, BAYC, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
     * @dev Will fail if the value is in an unhealthy state after withdrawal (collateral value is smaller than the Used Margin).
     * If no debt is taken yet on this Account, users are free to withdraw any asset at any time.
     */
    function withdraw(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts)
        external
        onlyOwner
    {
        // No need to check that all arrays have equal length, this check is already done in the Registry.
        _withdraw(assetAddresses, assetIds, assetAmounts, msg.sender);

        uint256 usedMargin = getUsedMargin();
        // If usedMargin is equal to minimumMargin, the open liabilities are 0 and all assets can be withdrawn.
        if (usedMargin > minimumMargin && getCollateralValue() < usedMargin) {
            revert AccountErrors.AccountUnhealthy();
        }
    }

    /**
     * @notice Withdrawals assets from the Account to the owner.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param to The address to withdraw to.
     */
    function _withdraw(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        address to
    ) internal {
        // Reverts in registry if input is invalid.
        uint256[] memory assetTypes =
            IRegistry(registry).batchProcessWithdrawal(creditor, assetAddresses, assetIds, assetAmounts); // reverts in registry if invalid input

        uint256 assetAddressesLength = assetAddresses.length;
        for (uint256 i; i < assetAddressesLength;) {
            if (assetAmounts[i] == 0) {
                // Skip if amount is 0 to prevent transferring 0 balances.
                unchecked {
                    ++i;
                }
                continue;
            }

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
            unchecked {
                ++i;
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
        for (uint256 i; i < assetAddressesLength;) {
            if (transferFromOwnerData.assetAmounts[i] == 0) {
                // Skip if amount is 0 to prevent transferring 0 balances.
                unchecked {
                    ++i;
                }
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
            unchecked {
                ++i;
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
        bytes calldata signature,
        address to_
    ) internal {
        uint256 tokenPermissionsLength = permit.permitted.length;
        IPermit2.SignatureTransferDetails[] memory transferDetails =
            new IPermit2.SignatureTransferDetails[](tokenPermissionsLength);

        for (uint256 i; i < tokenPermissionsLength;) {
            transferDetails[i].to = to_;
            transferDetails[i].requestedAmount = permit.permitted[i].amount;

            unchecked {
                ++i;
            }
        }

        permit2.permitTransferFrom(permit, transferDetails, owner, signature);
    }

    /**
     * @notice Internal function to deposit ERC20 tokens.
     * @param from Address the tokens should be transferred from. This address must have approved the Account.
     * @param ERC20Address The contract address of the asset.
     * @param amount The amount of ERC20 tokens.
     * @dev Used for all tokens type == 0.
     * @dev If the token has not yet been deposited, the ERC20 token address is stored.
     */
    function _depositERC20(address from, address ERC20Address, uint256 amount) internal {
        ERC20(ERC20Address).safeTransferFrom(from, address(this), amount);

        uint256 currentBalance = erc20Balances[ERC20Address];

        if (currentBalance == 0) {
            erc20Stored.push(ERC20Address);
        }

        unchecked {
            erc20Balances[ERC20Address] += amount;
        }
    }

    /**
     * @notice Internal function to deposit ERC721 tokens.
     * @param from Address the tokens should be transferred from. This address must have approved the Account.
     * @param ERC721Address The contract address of the asset.
     * @param id The ID of the ERC721 token.
     * @dev Used for all tokens type == 1.
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
     * @dev Used for all tokens type == 2.
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
            erc1155Balances[ERC1155Address][id] += amount;
        }
    }

    /**
     * @notice Internal function to withdraw ERC20 tokens.
     * @param to Address the tokens should be sent to.
     * @param ERC20Address The contract address of the asset.
     * @param amount The amount of ERC20 tokens.
     * @dev Used for all tokens type == 0.
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
                for (uint256 i; i < erc20StoredLength;) {
                    if (erc20Stored[i] == ERC20Address) {
                        erc20Stored[i] = erc20Stored[erc20StoredLength - 1];
                        erc20Stored.pop();
                        break;
                    }
                    unchecked {
                        ++i;
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
     * @dev Used for all tokens type == 1.
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
            for (i; i < tokenIdLength;) {
                if (erc721TokenIds[i] == id && erc721Stored[i] == ERC721Address) {
                    erc721TokenIds[i] = erc721TokenIds[tokenIdLength - 1];
                    erc721TokenIds.pop();
                    erc721Stored[i] = erc721Stored[tokenIdLength - 1];
                    erc721Stored.pop();
                    break;
                }
                unchecked {
                    ++i;
                }
            }
            // For loop should break, otherwise we never went into the if-branch, meaning the token being withdrawn
            // is unknown and not properly deposited.
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
     * @dev Used for all tokens types = 2.
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
                for (uint256 i; i < tokenIdLength;) {
                    if (erc1155TokenIds[i] == id) {
                        if (erc1155Stored[i] == ERC1155Address) {
                            erc1155TokenIds[i] = erc1155TokenIds[tokenIdLength - 1];
                            erc1155TokenIds.pop();
                            erc1155Stored[i] = erc1155Stored[tokenIdLength - 1];
                            erc1155Stored.pop();
                            break;
                        }
                    }
                    unchecked {
                        ++i;
                    }
                }
            }
        }

        IERC1155(ERC1155Address).safeTransferFrom(address(this), to, id, amount, "");
    }

    /**
     * @notice Skims non-deposited assets from the Account.
     * @param token The contract address of the asset.
     * @param id The ID of the asset.
     * @param type_ The asset type of the asset.
     * @dev Function can retrieve assets that were transferred to the Account but not deposited.
     * or can be used to claim yield for rebasing tokens.
     */
    function skim(address token, uint256 id, uint256 type_) public onlyOwner {
        if (token == address(0)) {
            payable(owner).transfer(address(this).balance);
            return;
        }

        if (type_ == 0) {
            uint256 balance = ERC20(token).balanceOf(address(this));
            uint256 balanceStored = erc20Balances[token];
            if (balance > balanceStored) {
                ERC20(token).safeTransfer(owner, balance - balanceStored);
            }
        } else if (type_ == 1) {
            bool isStored;
            uint256 erc721StoredLength = erc721Stored.length;
            for (uint256 i; i < erc721StoredLength;) {
                if (erc721Stored[i] == token && erc721TokenIds[i] == id) {
                    isStored = true;
                    break;
                }
                unchecked {
                    ++i;
                }
            }

            if (!isStored) {
                IERC721(token).safeTransferFrom(address(this), owner, id);
            }
        } else if (type_ == 2) {
            uint256 balance = IERC1155(token).balanceOf(address(this), id);
            uint256 balanceStored = erc1155Balances[token][id];

            if (balance > balanceStored) {
                IERC1155(token).safeTransferFrom(address(this), owner, id, balance - balanceStored, "");
            }
        }
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

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
        } // Cannot realistically overflow. No max(uint256) contracts deployed.
        assetAddresses = new address[](totalLength);
        assetIds = new uint256[](totalLength);
        assetAmounts = new uint256[](totalLength);

        uint256 i;
        uint256 erc20StoredLength = erc20Stored.length;
        address cacheAddr;
        for (; i < erc20StoredLength;) {
            cacheAddr = erc20Stored[i];
            assetAddresses[i] = cacheAddr;
            // assetIds[i] = 0; // gas: no need to store 0, index will continue anyway.
            assetAmounts[i] = erc20Balances[cacheAddr];
            unchecked {
                ++i;
            }
        }

        uint256 j;
        uint256 erc721StoredLength = erc721Stored.length;
        for (; j < erc721StoredLength;) {
            cacheAddr = erc721Stored[j];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = erc721TokenIds[j];
            assetAmounts[i] = 1;
            unchecked {
                ++i;
            }
            unchecked {
                ++j;
            }
        }

        uint256 k;
        uint256 erc1155StoredLength = erc1155Stored.length;
        uint256 cacheId;
        for (; k < erc1155StoredLength;) {
            cacheAddr = erc1155Stored[k];
            cacheId = erc1155TokenIds[k];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = cacheId;
            assetAmounts[i] = erc1155Balances[cacheAddr][cacheId];
            unchecked {
                ++i;
            }
            unchecked {
                ++k;
            }
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    fallback() external {
        revert AccountErrors.NoFallback();
    }

    function returnFive() public pure returns (uint256) {
        return 5;
    }

    /**
     * @notice Finalizes the Upgrade to a new Account version on the new Logic Contract.
     * param oldImplementation The contract with the new old logic.
     * @param oldRegistry The Registry of the old version (might be identical as the new registry)
     * param oldVersion The old version of the Account logic.
     * param data Arbitrary data, can contain instructions to execute in this function.
     * @dev If upgradeHook() is implemented, it MUST be verify that msg.sender == address(this).
     */
    function upgradeHook(address, address oldRegistry, uint256, bytes calldata) external {
        require(msg.sender == address(this), "Not the right address");
        IRegistry(oldRegistry).batchProcessWithdrawal(address(0), new address[](0), new uint256[](0), new uint256[](0));
        IRegistry(registry).batchProcessDeposit(address(0), new address[](0), new uint256[](0), new uint256[](0));

        storageV2 = returnFive();
    }
}
