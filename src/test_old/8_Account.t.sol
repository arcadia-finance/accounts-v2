/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import "./fixtures/ArcadiaAccountsFixture.f.sol";

import { TrustedCreditorMock } from "../mockups/TrustedCreditorMock.sol";
import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";
import { ActionMultiCall } from "../actions/MultiCall.sol";
import "../actions/utils/ActionData.sol";
import { MultiActionMock } from "../mockups/MultiActionMock.sol";

contract AccountTestExtension is AccountV1 {
    constructor(address mainReg_) AccountV1() {
        registry = mainReg_;
    }

    function getLengths() external view returns (uint256, uint256, uint256, uint256) {
        return (erc20Stored.length, erc721Stored.length, erc721TokenIds.length, erc1155Stored.length);
    }

    function setTrustedCreditor(address trustedCreditor_) public {
        trustedCreditor = trustedCreditor_;
    }

    function setIsTrustedCreditorSet(bool set) public {
        isTrustedCreditorSet = set;
    }

    function setFixedLiquidationCost(uint96 fixedLiquidationCost_) public {
        fixedLiquidationCost = fixedLiquidationCost_;
    }

    function setOwner(address newOwner) public {
        owner = newOwner;
    }

    function setRegistry(address registry_) public {
        registry = registry_;
    }

    function setLocked(uint256 locked_) public {
        locked = locked_;
    }
}

abstract contract accountTests is DeployArcadiaAccounts {
    using stdStorage for StdStorage;

    AccountTestExtension public account_;
    TrustedCreditorMock trustedCreditor;

    bytes3 public emptyBytes3;

    address public liquidator = address(8);

    struct Assets {
        address[] assetAddresses;
        uint256[] assetIds;
        uint256[] assetAmounts;
    }

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);

    //this is a before
    constructor() DeployArcadiaAccounts() {
        trustedCreditor = new TrustedCreditorMock();
        trustedCreditor.setBaseCurrency(address(dai));
        trustedCreditor.setLiquidator(liquidator);
    }

    //this is a before each
    function setUp() public virtual {
        vm.prank(accountOwner);
        account_ = new AccountTestExtension(address(mainRegistry));
        account_.setLocked(1);
    }

    /* ///////////////////////////////////////////////////////////////
                    HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function deployFactory() internal {
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(account_)).checked_write(
            true
        );
        stdstore.target(address(factory)).sig(factory.accountIndex.selector).with_key(address(account_)).checked_write(
            10
        );
        factory.setOwnerOf(accountOwner, 10);
    }

    function openMarginAccount() internal {
        vm.startPrank(accountOwner);
        account_.openTrustedMarginAccount(address(trustedCreditor));
        dai.approve(address(account_), type(uint256).max);
        bayc.setApprovalForAll(address(account_), true);
        mayc.setApprovalForAll(address(account_), true);
        dickButs.setApprovalForAll(address(account_), true);
        interleave.setApprovalForAll(address(account_), true);
        eth.approve(address(account_), type(uint256).max);
        link.approve(address(account_), type(uint256).max);
        snx.approve(address(account_), type(uint256).max);
        safemoon.approve(address(account_), type(uint256).max);
        vm.stopPrank();
    }

    function depositEthAndTakeMaxCredit(uint128 amountEth) public returns (uint256) {
        depositERC20InAccount(eth, amountEth, accountOwner);
        uint256 remainingCredit = account_.getFreeMargin();
        trustedCreditor.setOpenPosition(address(account_), amountEth);

        return remainingCredit;
    }

    function depositERC20InAccount(ERC20Mock token, uint128 amount, address sender)
        public
        virtual
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        vm.startPrank(sender);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositEthInAccount(uint8 amount, address sender) public returns (Assets memory assetInfo) {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.ethDecimals;

        vm.startPrank(sender);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        assetInfo = Assets({ assetAddresses: assetAddresses, assetIds: assetIds, assetAmounts: assetAmounts });
    }

    function depositLinkInAccount(uint8 amount, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(link);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount * 10 ** Constants.linkDecimals;

        vm.startPrank(sender);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function depositBaycInAccount(uint128[] memory tokenIds, address sender)
        public
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](tokenIds.length);
        assetIds = new uint256[](tokenIds.length);
        assetAmounts = new uint256[](tokenIds.length);

        uint256 tokenIdToWorkWith;
        for (uint256 i; i < tokenIds.length; ++i) {
            tokenIdToWorkWith = tokenIds[i];
            while (bayc.getOwnerOf(tokenIdToWorkWith) != address(0)) {
                tokenIdToWorkWith++;
            }

            bayc.mint(sender, tokenIdToWorkWith);
            assetAddresses[i] = address(bayc);
            assetIds[i] = tokenIdToWorkWith;
            assetAmounts[i] = 1;
        }

        vm.startPrank(sender);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function generateERC721DepositList(uint8 length)
        public
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            uint256[] memory assetTypes
        )
    {
        assetAddresses = new address[](length);

        assetIds = new uint256[](length);

        assetAmounts = new uint256[](length);

        assetTypes = new uint256[](length);

        uint256 id = 10;
        for (uint256 i; i < length; ++i) {
            vm.prank(tokenCreatorAddress);
            bayc.mint(accountOwner, id);
            assetAddresses[i] = address(bayc);
            assetIds[i] = id;
            assetAmounts[i] = 1;
            assetTypes[i] = 1;
            ++id;
        }
    }
}

/*///////////////////////////////////////////////////////////////
                ASSET MANAGEMENT LOGIC
///////////////////////////////////////////////////////////////*/
contract AccountActionTest is accountTests {
    using stdStorage for StdStorage;

    ActionMultiCall public action;
    MultiActionMock public multiActionMock;

    AccountTestExtension public proxy_;

    event AssetManagerSet(address indexed owner, address indexed assetManager, bool value);

    function depositERC20InAccount(ERC20Mock token, uint128 amount, address sender)
        public
        override
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(token);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = amount;

        vm.prank(tokenCreatorAddress);
        token.mint(sender, amount);

        token.balanceOf(0x0000000000000000000000000000000000000006);

        vm.startPrank(sender);
        token.approve(address(proxy_), amount);
        proxy_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();
        deployFactory();

        action = new ActionMultiCall();
        deal(address(eth), address(action), 1000 * 10 ** 20, false);

        vm.startPrank(creatorAddress);
        account = new AccountTestExtension(address(mainRegistry));
        factory.setLatestAccountversion(0);
        factory.setNewAccountInfo(address(mainRegistry), address(account), Constants.upgradeProof1To2, "");
        vm.stopPrank();

        vm.startPrank(accountOwner);
        proxyAddr = factory.createAccount(12_345_678, 0, address(0), address(0));
        proxy_ = AccountTestExtension(proxyAddr);
        vm.stopPrank();

        depositERC20InAccount(eth, 1000 * 10 ** 18, accountOwner);
        vm.startPrank(creatorAddress);
        mainRegistry.setAllowedAction(address(action), true);

        vm.stopPrank();
    }
}

/* ///////////////////////////////////////////////////////////////
            ASSET DEPOSIT/WITHDRAWN LOGIC
/////////////////////////////////////////////////////////////// */
contract AssetManagementTest is accountTests {
    using stdStorage for StdStorage;

    AccountTestExtension public account2;

    function setUp() public override {
        super.setUp();
        deployFactory();
        openMarginAccount();
    }

    function testRevert_withdraw_NonOwner(uint8 depositAmount, uint8 withdrawalAmount, address sender) public {
        vm.assume(sender != accountOwner);
        vm.assume(depositAmount > withdrawalAmount);
        Assets memory assetInfo = depositEthInAccount(depositAmount, accountOwner);

        assetInfo.assetAmounts[0] = withdrawalAmount * 10 ** Constants.ethDecimals;
        vm.startPrank(sender);
        vm.expectRevert("A: Only Owner");
        account_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);
    }

    //input as uint8 to prevent too long lists as fuzz input
    function testRevert_withdraw_LengthOfListDoesNotMatch(uint8 addrLen, uint8 idLen, uint8 amountLen) public {
        vm.assume((addrLen != idLen && addrLen != amountLen));

        address[] memory assetAddresses = new address[](addrLen);
        for (uint256 i; i < addrLen; ++i) {
            assetAddresses[i] = address(uint160(i));
        }

        uint256[] memory assetIds = new uint256[](idLen);
        for (uint256 j; j < idLen; j++) {
            assetIds[j] = j;
        }

        uint256[] memory assetAmounts = new uint256[](amountLen);
        for (uint256 k; k < amountLen; k++) {
            assetAmounts[k] = k;
        }

        vm.startPrank(accountOwner);
        vm.expectRevert("MR_BPW: LENGTH_MISMATCH");
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_UnknownAssetType(uint96 assetType) public {
        vm.assume(assetType >= 3);
        depositEthInAccount(5, accountOwner);

        mainRegistry.setAssetType(address(eth), assetType);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(accountOwner);
        vm.expectRevert("A_W: Unknown asset type");
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_MoreThanMaxExposure(uint256 amountWithdraw, uint128 maxExposure) public {
        vm.assume(amountWithdraw > maxExposure);
        vm.prank(creatorAddress);
        standardERC20PricingModule.setExposureOfAsset(address(eth), maxExposure);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(eth);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = amountWithdraw;

        vm.startPrank(accountOwner);
        vm.expectRevert(stdError.arithmeticError);
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC721TransferAndWithdrawTokenOneERC721Deposited() public {
        bayc.mint(accountOwner, 20);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(bayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 20;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(accountOwner);
        bayc.approve(address(account_), 20);
        account_.deposit(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();

        vm.prank(accountOwner);
        account2 = new AccountTestExtension(address(mainRegistry));
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(account2)).checked_write(
            true
        );
        stdstore.target(address(factory)).sig(factory.accountIndex.selector).with_key(address(account2)).checked_write(
            11
        );
        factory.setOwnerOf(accountOwner, 11);

        mayc.mint(accountOwner, 10);
        mayc.mint(accountOwner, 11);

        assetAddresses[0] = address(mayc);
        assetIds[0] = 10;

        vm.startPrank(accountOwner);
        mayc.approve(address(account2), 10);
        account2.deposit(assetAddresses, assetIds, assetAmounts);
        mayc.safeTransferFrom(accountOwner, address(account_), 11);
        vm.stopPrank();

        assetIds[0] = 11;

        vm.startPrank(accountOwner);
        vm.expectRevert("A_W721: Unknown asset");
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC721TransferAndWithdrawTokenNotOneERC721Deposited(uint128[] calldata tokenIdsDeposit)
        public
    {
        vm.assume(tokenIdsDeposit.length < account_.ASSET_LIMIT());
        vm.assume(tokenIdsDeposit.length != 1);

        depositBaycInAccount(tokenIdsDeposit, accountOwner);

        vm.prank(accountOwner);
        account2 = new AccountTestExtension(address(mainRegistry));
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(account2)).checked_write(
            true
        );
        stdstore.target(address(factory)).sig(factory.accountIndex.selector).with_key(address(account2)).checked_write(
            11
        );
        factory.setOwnerOf(accountOwner, 11);

        mayc.mint(accountOwner, 10);
        mayc.mint(accountOwner, 11);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mayc);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 10;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        vm.startPrank(accountOwner);
        mayc.approve(address(account2), 10);
        account2.deposit(assetAddresses, assetIds, assetAmounts);
        mayc.safeTransferFrom(accountOwner, address(account_), 11);
        vm.stopPrank();

        assetIds[0] = 11;

        vm.startPrank(accountOwner);
        vm.expectRevert("A_W721: Unknown asset");
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC20UnsufficientCollateral(
        uint8 baseAmountDeposit,
        uint24 baseAmountCredit,
        uint32 fixedLiquidationCost,
        uint8 baseAmountWithdraw
    ) public {
        vm.assume(baseAmountCredit > 0);
        vm.assume(baseAmountWithdraw > 0);
        vm.assume(baseAmountWithdraw < baseAmountDeposit);

        uint256 valueDeposit = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountDeposit / 10 ** (18 - Constants.daiDecimals);
        uint256 amountCredit = baseAmountCredit * 10 ** Constants.daiDecimals;
        uint256 amountWithdraw = baseAmountWithdraw * 10 ** Constants.ethDecimals;
        uint256 ValueWithdraw = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountWithdraw / 10 ** (18 - Constants.daiDecimals);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        vm.assume(amountCredit + fixedLiquidationCost <= (valueDeposit * collFactor_) / 100);
        vm.assume(amountCredit + fixedLiquidationCost > ((valueDeposit - ValueWithdraw) * collFactor_) / 100);

        Assets memory assetInfo = depositEthInAccount(baseAmountDeposit, accountOwner);

        account_.setFixedLiquidationCost(fixedLiquidationCost);

        trustedCreditor.setOpenPosition(address(account_), amountCredit);

        assetInfo.assetAmounts[0] = amountWithdraw;

        vm.startPrank(accountOwner);
        vm.expectRevert("A_W: Account Unhealthy");
        account_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);
        vm.stopPrank();
    }

    function testRevert_withdraw_ERC721UnsufficientCollateral(
        uint128[] calldata tokenIdsDeposit,
        uint8 amountsWithdrawn
    ) public {
        vm.assume(tokenIdsDeposit.length < account_.ASSET_LIMIT());

        (, uint256[] memory assetIds,) = depositBaycInAccount(tokenIdsDeposit, accountOwner);
        vm.assume(assetIds.length >= amountsWithdrawn && assetIds.length > 1 && amountsWithdrawn > 1);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint256 rateInUsd = (((Constants.WAD * rateBaycToEth) / 10 ** Constants.oracleBaycToEthDecimals) * rateEthToUsd)
            / 10 ** Constants.oracleEthToUsdDecimals / 10 ** (18 - Constants.daiDecimals);

        uint128 maxAmountCredit = uint128(((assetIds.length - amountsWithdrawn) * rateInUsd * collFactor_) / 100);

        trustedCreditor.setOpenPosition(address(account_), maxAmountCredit + 1);

        uint256[] memory withdrawalIds = new uint256[](amountsWithdrawn);
        address[] memory withdrawalAddresses = new address[](amountsWithdrawn);
        uint256[] memory withdrawalAmounts = new uint256[](amountsWithdrawn);
        for (uint256 i; i < amountsWithdrawn; ++i) {
            withdrawalIds[i] = assetIds[i];
            withdrawalAddresses[i] = address(bayc);
            withdrawalAmounts[i] = 1;
        }

        vm.startPrank(accountOwner);
        vm.expectRevert("A_W: Account Unhealthy");
        account_.withdraw(withdrawalAddresses, withdrawalIds, withdrawalAmounts);
        vm.stopPrank();
    }

    function testSuccess_withdraw_ERC20NoDebt(uint8 baseAmountDeposit, uint32 fixedLiquidationCost) public {
        vm.assume(baseAmountDeposit > 0);
        uint256 valueAmount = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountDeposit / 10 ** (18 - Constants.daiDecimals);

        Assets memory assetInfo = depositEthInAccount(baseAmountDeposit, accountOwner);

        uint256 accountValue = account_.getAccountValue(address(dai));

        assertEq(accountValue, valueAmount);

        account_.setFixedLiquidationCost(fixedLiquidationCost);

        vm.startPrank(accountOwner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(account_), accountOwner, assetInfo.assetAmounts[0]);
        account_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);
        vm.stopPrank();

        uint256 accountValueAfter = account_.getAccountValue(address(dai));
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            account_.generateAssetData();
        assertEq(accountValueAfter, 0);
        assertEq(assetAddresses.length, 0);
        assertEq(assetIds.length, 0);
        assertEq(assetAmounts.length, 0);
    }

    function testSuccess_withdraw_ERC20AfterTakingCredit(
        uint8 baseAmountDeposit,
        uint32 baseAmountCredit,
        uint32 fixedLiquidationCost,
        uint8 baseAmountWithdraw
    ) public {
        uint256 valueDeposit = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountDeposit / 10 ** (18 - Constants.daiDecimals);
        uint128 amountCredit = uint128(baseAmountCredit * 10 ** Constants.daiDecimals);
        uint256 amountWithdraw = baseAmountWithdraw * 10 ** Constants.ethDecimals;
        uint256 valueWithdraw = ((Constants.WAD * rateEthToUsd) / 10 ** Constants.oracleEthToUsdDecimals)
            * baseAmountWithdraw / 10 ** (18 - Constants.daiDecimals);
        vm.assume(baseAmountWithdraw < baseAmountDeposit);

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        vm.assume(amountCredit + fixedLiquidationCost <= ((valueDeposit - valueWithdraw) * collFactor_) / 100);

        account_.setFixedLiquidationCost(fixedLiquidationCost);

        trustedCreditor.setOpenPosition(address(account_), amountCredit);

        Assets memory assetInfo = depositEthInAccount(baseAmountDeposit, accountOwner);
        assetInfo.assetAmounts[0] = amountWithdraw;

        vm.prank(accountOwner);
        account_.withdraw(assetInfo.assetAddresses, assetInfo.assetIds, assetInfo.assetAmounts);

        uint256 actualValue = account_.getAccountValue(address(dai));
        uint256 expectedValue = valueDeposit - valueWithdraw;

        assertEq(expectedValue, actualValue);
    }

    function testSuccess_withdraw_ERC721AfterTakingCredit(uint128[] calldata tokenIdsDeposit, uint8 baseAmountCredit)
        public
    {
        vm.assume(tokenIdsDeposit.length < account_.ASSET_LIMIT());
        uint128 amountCredit = uint128(baseAmountCredit * 10 ** Constants.daiDecimals);

        (, uint256[] memory assetIds,) = depositBaycInAccount(tokenIdsDeposit, accountOwner);

        uint256 randomAmounts = assetIds.length > 0
            ? uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "testWithrawERC721AfterTakingCredit(uint256[],uint8)", assetIds, baseAmountCredit
                    )
                )
            ) % assetIds.length
            : 0;

        uint16 collFactor_ = RiskConstants.DEFAULT_COLLATERAL_FACTOR;

        uint256 rateInUsd = (((Constants.WAD * rateBaycToEth) / 10 ** Constants.oracleBaycToEthDecimals) * rateEthToUsd)
            / 10 ** Constants.oracleEthToUsdDecimals / 10 ** (18 - Constants.daiDecimals);
        uint256 valueOfDeposit = rateInUsd * assetIds.length;

        uint256 valueOfWithdrawal = rateInUsd * randomAmounts;

        vm.assume((valueOfDeposit * collFactor_) / 100 >= amountCredit);
        vm.assume(valueOfWithdrawal < valueOfDeposit);
        vm.assume(amountCredit < ((valueOfDeposit - valueOfWithdrawal) * collFactor_) / 100);

        trustedCreditor.setOpenPosition(address(account_), amountCredit);

        uint256[] memory withdrawalIds = new uint256[](randomAmounts);
        address[] memory withdrawalAddresses = new address[](randomAmounts);
        uint256[] memory withdrawalAmounts = new uint256[](randomAmounts);
        for (uint256 i; i < randomAmounts; ++i) {
            withdrawalIds[i] = assetIds[i];
            withdrawalAddresses[i] = address(bayc);
            withdrawalAmounts[i] = 1;
        }

        vm.prank(accountOwner);
        account_.withdraw(withdrawalAddresses, withdrawalIds, withdrawalAmounts);

        uint256 actualValue = account_.getAccountValue(address(dai));
        uint256 expectedValue = valueOfDeposit - valueOfWithdrawal;

        assertEq(expectedValue, actualValue);
    }

    function testRevert_skim_NonOwner(address sender) public {
        vm.assume(sender != accountOwner);

        vm.startPrank(sender);
        vm.expectRevert("A_S: Only owner can skim");
        account_.skim(address(eth), 0, 0);
        vm.stopPrank();
    }

    function testSuccess_skim_type0_skim() public {
        depositERC20InAccount(eth, 2000, accountOwner);

        vm.prank(tokenCreatorAddress);
        eth.mint(address(account_), 1000);

        vm.startPrank(accountOwner);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(account_), accountOwner, 1000);
        account_.skim(address(eth), 0, 0);
        vm.stopPrank();
    }

    function testSuccess_skim_type0_nothingToSkim() public {
        depositERC20InAccount(eth, 2000, accountOwner);

        uint256 balanceBeforeStored = account_.erc20Balances(address(eth));
        uint256 balanceBefore = eth.balanceOf(address(account_));
        assertEq(balanceBeforeStored, balanceBefore);

        vm.startPrank(accountOwner);
        account_.skim(address(eth), 0, 0);
        vm.stopPrank();

        uint256 balancePostStored = account_.erc20Balances(address(eth));
        uint256 balancePost = eth.balanceOf(address(account_));
        assertEq(balancePostStored, balancePost);
        assertEq(balancePostStored, balanceBeforeStored);
    }

    function testSuccess_skim_type1_skim(uint128[] calldata tokenIdsDeposit) public {
        vm.assume(tokenIdsDeposit.length < 15 && tokenIdsDeposit.length > 0);
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            depositBaycInAccount(tokenIdsDeposit, accountOwner);

        address[] memory assetAddrOne = new address[](1);
        uint256[] memory assetIdOne = new uint256[](1);
        uint256[] memory assetAmountOne = new uint256[](1);

        assetAddrOne[0] = assetAddresses[0];
        assetIdOne[0] = assetIds[0];
        assetAmountOne[0] = assetAmounts[0];

        vm.startPrank(accountOwner);
        account_.withdraw(assetAddrOne, assetIdOne, assetAmountOne);
        bayc.transferFrom(accountOwner, address(account_), assetIdOne[0]);

        account_.skim(assetAddrOne[0], assetIdOne[0], 1);
        vm.stopPrank();

        assertEq(bayc.ownerOf(assetIdOne[0]), accountOwner);
    }

    function testSuccess_skim_type1_nothingToSkim() public {
        uint128[] memory tokenIdsDeposit = new uint128[](5);
        tokenIdsDeposit[0] = 100;
        tokenIdsDeposit[1] = 200;
        tokenIdsDeposit[2] = 300;
        tokenIdsDeposit[3] = 400;
        tokenIdsDeposit[4] = 500;
        (address[] memory assetAddresses, uint256[] memory assetIds,) =
            depositBaycInAccount(tokenIdsDeposit, accountOwner);

        uint256 balanceBefore = bayc.balanceOf(address(account_));

        vm.startPrank(accountOwner);
        account_.skim(assetAddresses[0], assetIds[0], 1);
        vm.stopPrank();

        uint256 balancePost = bayc.balanceOf(address(account_));

        assertEq(balanceBefore, balancePost);
        assertEq(bayc.ownerOf(assetIds[0]), address(account_));
    }

    function testSuccess_skim_type2_skim() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10_000;

        vm.prank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);

        assetAmounts[0] = 100;
        vm.startPrank(accountOwner);
        account_.withdraw(assetAddresses, assetIds, assetAmounts);
        interleave.safeTransferFrom(accountOwner, address(account_), 1, 100, "");

        uint256 balanceOwnerBefore = interleave.balanceOf(accountOwner, 1);

        account_.skim(address(interleave), 1, 2);
        vm.stopPrank();

        uint256 balanceOwnerAfter = interleave.balanceOf(accountOwner, 1);

        assertEq(interleave.balanceOf(address(account_), 1), account_.erc1155Balances(address(interleave), 1));
        assertEq(balanceOwnerBefore + 100, balanceOwnerAfter);
    }

    function testSuccess_skim_type2_nothingToSkim() public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(interleave);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 1;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 10_000;

        vm.startPrank(accountOwner);
        account_.deposit(assetAddresses, assetIds, assetAmounts);

        uint256 balanceBefore = interleave.balanceOf(address(account_), 1);

        account_.skim(address(interleave), 1, 2);
        vm.stopPrank();

        uint256 balancePost = interleave.balanceOf(address(account_), 1);

        assertEq(balanceBefore, balancePost);
        assertEq(interleave.balanceOf(address(account_), 1), account_.erc1155Balances(address(interleave), 1));
    }

    function testSuccess_skim_ether() public {
        vm.deal(address(account_), 1e21);
        assertEq(address(account_).balance, 1e21);

        uint256 balanceOwnerBefore = accountOwner.balance;

        vm.prank(accountOwner);
        account_.skim(address(0), 0, 0);

        uint256 balanceOwnerAfter = accountOwner.balance;

        assertEq(balanceOwnerBefore + 1e21, balanceOwnerAfter);
    }
}
