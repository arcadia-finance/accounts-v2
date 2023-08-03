/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../src/LendingPool.sol";
import "../src/mocks/Asset.sol";
import "../src/mocks/Factory.sol";
import "../src/mocks/Liquidator.sol";
import "../src/Tranche.sol";
import "../src/DebtToken.sol";

contract LendingPoolExtension is LendingPool {
    //Extensions to test internal functions
    constructor(ERC20 _asset, address _treasury, address _vaultFactory, address _liquidator)
        LendingPool(_asset, _treasury, _vaultFactory, _liquidator)
    { }

    function popTranche(uint256 index, address tranche) public {
        _popTranche(index, tranche);
    }

    function syncInterestsToLendingPool(uint128 assets) public {
        _syncInterestsToLiquidityProviders(assets);
    }

    function syncLiquidationFeeToLiquidityProviders(uint128 assets) public {
        _syncLiquidationFeeToLiquidityProviders(assets);
    }

    function processDefault(uint256 assets) public {
        _processDefault(assets);
    }

    function syncInterests() public {
        _syncInterests();
    }

    function setTotalRealisedLiquidity(uint128 totalRealisedLiquidity_) public {
        totalRealisedLiquidity = totalRealisedLiquidity_;
    }

    function setLastSyncedTimestamp(uint32 lastSyncedTimestamp_) public {
        lastSyncedTimestamp = lastSyncedTimestamp_;
    }

    function setRealisedDebt(uint256 realisedDebt_) public {
        realisedDebt = realisedDebt_;
    }

    function setInterestRate(uint256 interestRate_) public {
        interestRate = interestRate_;
    }

    function setIsValidVersion(uint256 version, bool allowed) public {
        isValidVersion[version] = allowed;
    }

    function numberOfTranches() public view returns (uint256) {
        return tranches.length;
    }

    function setAuctionsInProgress(uint16 amount) public {
        auctionsInProgress = amount;
    }
}

abstract contract LendingPoolTest is Test {
    Asset asset;
    Factory factory;
    LendingPoolExtension pool;
    Tranche srTranche;
    Tranche jrTranche;
    DebtToken debt;
    Vault vault;
    Liquidator liquidator;

    address creator = address(1);
    address tokenCreator = address(2);
    address treasury = address(4);
    address vaultOwner = address(5);
    address liquidityProvider = address(6);
    address liquidationInitiatorAddr = address(7);

    bytes3 public emptyBytes3;

    event TrancheAdded(address indexed tranche, uint8 indexed index, uint16 interestWeight, uint16 liquidationWeight);
    event InterestWeightSet(uint256 indexed index, uint16 weight);
    event LiquidationWeightSet(uint256 indexed index, uint16 weight);
    event TranchePopped(address tranche);
    event TreasuryInterestWeightSet(uint16 weight);
    event TreasuryLiquidationWeightSet(uint16 weight);
    event OriginationFeeSet(uint8 originationFee);
    event BorrowCapSet(uint128 borrowCap);
    event SupplyCapSet(uint128 supplyCap);
    event CreditApproval(address indexed vault, address indexed owner, address indexed beneficiary, uint256 amount);
    event Borrow(
        address indexed vault, address indexed by, address to, uint256 amount, uint256 fee, bytes3 indexed referrer
    );
    event Repay(address indexed vault, address indexed from, uint256 amount);
    event MaxInitiatorFeeSet(uint80 maxInitiatorFee);
    event FixedLiquidationCostSet(uint96 fixedLiquidationCost);
    event VaultVersionSet(uint256 indexed vaultVersion, bool valid);

    //Before
    constructor() {
        vm.startPrank(tokenCreator);
        asset = new Asset("Asset", "ASSET", 18);
        asset.mint(liquidityProvider, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(creator);
        factory = new Factory();
        liquidator = new Liquidator();
        vm.stopPrank();
    }

    //Before Each
    function setUp() public virtual {
        vm.startPrank(creator);
        pool = new LendingPoolExtension(asset, treasury, address(factory), address(liquidator));
        pool.setVaultVersion(0, true);
        srTranche = new Tranche(address(pool), "Senior", "SR");
        jrTranche = new Tranche(address(pool), "Junior", "JR");
        vm.stopPrank();

        debt = DebtToken(address(pool));
    }

    //Helper functions
    function calcUnrealisedDebtChecked(uint256 interestRate, uint24 deltaTimestamp, uint256 realisedDebt)
        internal
        view
        returns (uint256 unrealisedDebt)
    {
        uint256 base = 1e18 + interestRate;
        uint256 exponent = uint256(deltaTimestamp) * 1e18 / pool.YEARLY_SECONDS();
        unrealisedDebt = (uint256(realisedDebt) * (LogExpMath.pow(base, exponent) - 1e18)) / 1e18;
    }
}

/* //////////////////////////////////////////////////////////////
                            DEPLOYMENT
////////////////////////////////////////////////////////////// */
contract DeploymentTest is LendingPoolTest {
    function setUp() public override {
        super.setUp();
    }

    function testSuccess_deployment() public {
        assertEq(pool.name(), string("Arcadia Asset Debt"));
        assertEq(pool.symbol(), string("darcASSET"));
        assertEq(pool.decimals(), 18);
        assertEq(pool.vaultFactory(), address(factory));
        assertEq(pool.treasury(), treasury);
    }
}

/* //////////////////////////////////////////////////////////////
                        OWNERSHIP LOGIC
////////////////////////////////////////////////////////////// */
contract OwnershipTest is LendingPoolTest {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_transferOwnership_nonOwner(address unpriv, address newOwner) public {
        vm.assume(unpriv != creator);

        vm.startPrank(unpriv);
        vm.expectRevert("UNAUTHORIZED");
        pool.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function testSuccess_transferOwnership(address newOwner) public {
        vm.startPrank(creator);
        pool.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(newOwner, pool.owner());
    }

    function testSuccess_transferOwnership_newOwnerHasPrivs(address newOwner) public {
        vm.startPrank(creator);
        pool.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(newOwner, pool.owner());

        vm.prank(newOwner);
        pool.setTreasuryLiquidationWeight(1); //a random onlyOwner function
    }
}

/* //////////////////////////////////////////////////////////////
                        TRANCHES LOGIC
////////////////////////////////////////////////////////////// */
contract TranchesTest is LendingPoolTest {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_addTranche_InvalidOwner(address unprivilegedAddress) public {
        // Given: unprivilegedAddress is not the creator
        vm.assume(unprivilegedAddress != creator);

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress calls addTranche
        // Then: addTranche should revert with UNAUTHORIZED
        vm.expectRevert("UNAUTHORIZED");
        pool.addTranche(address(srTranche), 50, 0);
        vm.stopPrank();
    }

    function testSuccess_addTranche_SingleTranche(uint16 interestWeight, uint16 liquidationWeight) public {
        // Given: all neccesary contracts are deployed on the setup
        // When: creator calls addTranche with srTranche as Tranche address and 50 as interestWeight
        vm.startPrank(creator);
        vm.expectEmit(true, true, true, true);
        emit TrancheAdded(address(srTranche), 0, interestWeight, liquidationWeight);
        pool.addTranche(address(srTranche), interestWeight, liquidationWeight);
        vm.stopPrank();

        // Then: pool totalInterestWeight should be equal to 50, interestWeightTranches 0 should be equal to 50,
        // interestWeight of srTranche should be equal to 50, tranches 0 should be equal to srTranche,
        // isTranche for srTranche should return true
        assertEq(pool.totalInterestWeight(), interestWeight);
        assertEq(pool.interestWeightTranches(0), interestWeight);
        assertEq(pool.interestWeight(address(srTranche)), interestWeight);
        assertEq(pool.totalLiquidationWeight(), liquidationWeight);
        assertEq(pool.liquidationWeightTranches(0), liquidationWeight);
        assertEq(pool.tranches(0), address(srTranche));
        assertTrue(pool.isTranche(address(srTranche)));
    }

    function testRevert_addTranche_SingleTrancheTwice() public {
        // Given: creator calls addTranche with srTranche and 50
        vm.startPrank(creator);
        pool.addTranche(address(srTranche), 50, 0);
        // When: creator calls addTranche again with srTranche and 40

        // Then: addTranche should revert with TR_AD: Already exists
        vm.expectRevert("TR_AD: Already exists");
        pool.addTranche(address(srTranche), 40, 0);
        vm.stopPrank();
    }

    function testSuccess_addTranche_MultipleTranches(
        uint16 interestWeightSr,
        uint16 liquidationWeightSr,
        uint16 interestWeightJr,
        uint16 liquidationWeightJr
    ) public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(creator);
        // When: creator calls addTranche for srTranche and jrTranche with 50 and 40 interestWeightTranches
        vm.expectEmit(true, true, true, true);
        emit TrancheAdded(address(srTranche), 0, interestWeightSr, liquidationWeightSr);
        pool.addTranche(address(srTranche), interestWeightSr, liquidationWeightSr);

        vm.expectEmit(true, true, true, true);
        emit TrancheAdded(address(jrTranche), 1, interestWeightJr, liquidationWeightJr);
        pool.addTranche(address(jrTranche), interestWeightJr, liquidationWeightJr);
        vm.stopPrank();

        // Then: pool totalInterestWeight should be equal to 90, interestWeightTranches index 0 should be equal to 50,
        // interestWeightTranches index 1 should be equal to 40, interestWeight of srTranche should be equal to 50,
        // interestWeight of jrTranche should be equal to 40, tranches index 0 should be equal to srTranche,
        // tranches index 1 should be equal to jrTranche, isTranche should return true for both srTranche and jrTranche
        assertEq(pool.totalInterestWeight(), uint256(interestWeightSr) + interestWeightJr);
        assertEq(pool.interestWeightTranches(0), interestWeightSr);
        assertEq(pool.interestWeightTranches(1), interestWeightJr);
        assertEq(pool.interestWeight(address(srTranche)), interestWeightSr);
        assertEq(pool.interestWeight(address(jrTranche)), interestWeightJr);
        assertEq(pool.totalLiquidationWeight(), uint256(liquidationWeightSr) + liquidationWeightJr);
        assertEq(pool.liquidationWeightTranches(0), liquidationWeightSr);
        assertEq(pool.liquidationWeightTranches(1), liquidationWeightJr);
        assertEq(pool.tranches(0), address(srTranche));
        assertEq(pool.tranches(1), address(jrTranche));
        assertTrue(pool.isTranche(address(srTranche)));
        assertTrue(pool.isTranche(address(jrTranche)));
    }

    function testRevert_setInterestWeight_InvalidOwner(address unprivilegedAddress) public {
        // Given: all neccesary contracts are deployed on the setup
        vm.assume(unprivilegedAddress != creator);

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress setInterestWeight
        // Then: setInterestWeight should revert with UNAUTHORIZED
        vm.expectRevert("UNAUTHORIZED");
        pool.setInterestWeight(0, 50);
        vm.stopPrank();
    }

    function testRevert_setInterestWeight_InexistingTranche() public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(creator);
        // When: creator setInterestWeight on index 0
        // Then: setInterestWeight should revert with TR_SIW: Non Existing Tranche
        vm.expectRevert("TR_SIW: Non Existing Tranche");
        pool.setInterestWeight(0, 50);
        vm.stopPrank();
    }

    function testSuccess_setInterestWeight() public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(creator);
        // When: creator calls addTranche with srTranche and 50, calss setInterestWeight with 0 and 40
        pool.addTranche(address(srTranche), 50, 0);

        vm.expectEmit(true, true, true, true);
        emit InterestWeightSet(0, 40);
        pool.setInterestWeight(0, 40);
        vm.stopPrank();

        // Then: totalInterestWeight should be equal to 40, interestWeightTranches index 0 should return 40, interestWeight of srTranche should return 40
        assertEq(pool.totalInterestWeight(), 40);
        assertEq(pool.interestWeightTranches(0), 40);
        assertEq(pool.interestWeight(address(srTranche)), 40);
    }

    function testRevert_setLiquidationWeight_InvalidOwner(address unprivilegedAddress) public {
        // Given: all neccesary contracts are deployed on the setup
        vm.assume(unprivilegedAddress != creator);

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress setInterestWeight
        // Then: setInterestWeight should revert with UNAUTHORIZED
        vm.expectRevert("UNAUTHORIZED");
        pool.setLiquidationWeight(0, 50);
        vm.stopPrank();
    }

    function testRevert_setLiquidationWeight_InexistingTranche() public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(creator);
        // When: creator setInterestWeight on index 0
        // Then: setInterestWeight should revert with TR_SIW: Non Existing Tranche
        vm.expectRevert("TR_SLW: Non Existing Tranche");
        pool.setLiquidationWeight(0, 50);
        vm.stopPrank();
    }

    function testSuccess_setLiquidationWeight() public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(creator);
        // When: creator calls addTranche with srTranche and 50, calss setInterestWeight with 0 and 40
        pool.addTranche(address(srTranche), 50, 0);

        vm.expectEmit(true, true, true, true);
        emit LiquidationWeightSet(0, 40);
        pool.setLiquidationWeight(0, 40);
        vm.stopPrank();

        // Then: totalInterestWeight should be equal to 40, interestWeightTranches index 0 should return 40, interestWeight of srTranche should return 40
        assertEq(pool.totalLiquidationWeight(), 40);
        assertEq(pool.liquidationWeightTranches(0), 40);
    }

    function testSuccess_popTranche() public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(creator);
        // When: creator calls addTranche with srTranche and 50, jrTranche and 40
        pool.addTranche(address(srTranche), 50, 10);
        pool.addTranche(address(jrTranche), 40, 20);
        vm.stopPrank();

        // And: calls popTranche with 1 and jrTranche
        vm.expectEmit(true, true, true, true);
        emit TranchePopped(address(jrTranche));
        pool.popTranche(1, address(jrTranche));

        // Then: pool totalInterestWeight should be equal to 50, interestWeightTranches index 0 should be equal to 50,
        // tranches index 0 should be equal to srTranche, isTranche should return true for srTranche,
        // isTranche should return false for jrTranche
        assertEq(pool.totalInterestWeight(), 50);
        assertEq(pool.interestWeightTranches(0), 50);
        assertEq(pool.totalLiquidationWeight(), 10);
        assertEq(pool.liquidationWeightTranches(0), 10);
        assertEq(pool.tranches(0), address(srTranche));
        assertTrue(pool.isTranche(address(srTranche)));
        assertTrue(!pool.isTranche(address(jrTranche)));
    }
}

/* //////////////////////////////////////////////////////////////
                    PROTOCOL FEE CONFIGURATION
////////////////////////////////////////////////////////////// */
contract ProtocolFeeTest is LendingPoolTest {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_setTreasuryInterestWeight_InvalidOwner(address unprivilegedAddress) public {
        // Given: all neccesary contracts are deployed on the setup
        vm.assume(unprivilegedAddress != creator);

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress setTreasuryInterestWeight

        // Then: setTreasuryInterestWeight should revert with UNAUTHORIZED
        vm.expectRevert("UNAUTHORIZED");
        pool.setTreasuryInterestWeight(5);
        vm.stopPrank();
    }

    function testSuccess_setTreasuryInterestWeight() public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(creator);
        // When: creator addTranche with 50 interestWeight, setTreasuryInterestWeight 5
        pool.addTranche(address(srTranche), 50, 0);

        vm.expectEmit(true, true, true, true);
        emit TreasuryInterestWeightSet(5);
        pool.setTreasuryInterestWeight(5);
        vm.stopPrank();

        // Then: totalInterestWeight should be equal to 55, interestWeightTreasury should be equal to 5
        assertEq(pool.totalInterestWeight(), 55);
        assertEq(pool.interestWeightTreasury(), 5);

        vm.startPrank(creator);
        // When: creator setTreasuryInterestWeight 10
        pool.setTreasuryInterestWeight(10);
        vm.stopPrank();

        // Then: totalInterestWeight should be equal to 60, interestWeightTreasury should be equal to 10
        assertEq(pool.totalInterestWeight(), 60);
        assertEq(pool.interestWeightTreasury(), 10);
    }

    function testRevert_setTreasuryLiquidationWeight_InvalidOwner(address unprivilegedAddress) public {
        // Given: all neccesary contracts are deployed on the setup
        vm.assume(unprivilegedAddress != creator);

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress setTreasuryLiquidationWeight

        // Then: setTreasuryLiquidationWeight should revert with UNAUTHORIZED
        vm.expectRevert("UNAUTHORIZED");
        pool.setTreasuryLiquidationWeight(5);
        vm.stopPrank();
    }

    function testSuccess_setTreasuryLiquidationWeight() public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(creator);
        // When: creator addTranche with 50 liquidationWeight, setTreasuryLiquidationWeight 5
        pool.addTranche(address(srTranche), 0, 50);
        vm.expectEmit(true, true, true, true);
        emit TreasuryLiquidationWeightSet(5);
        pool.setTreasuryLiquidationWeight(5);
        vm.stopPrank();

        // Then: totalLiquidationWeight should be equal to 55, liquidationWeightTreasury should be equal to 5
        assertEq(pool.totalLiquidationWeight(), 55);
        assertEq(pool.liquidationWeightTreasury(), 5);

        vm.startPrank(creator);
        // When: creator setTreasuryLiquidationWeight 10
        pool.setTreasuryLiquidationWeight(10);
        vm.stopPrank();

        // Then: totalLiquidationWeight should be equal to 60, liquidationWeightTreasury should be equal to 10
        assertEq(pool.totalLiquidationWeight(), 60);
        assertEq(pool.liquidationWeightTreasury(), 10);
    }

    function testRevert_setTreasury_InvalidOwner(address unprivilegedAddress) public {
        // Given: all neccesary contracts are deployed on the setup
        vm.assume(unprivilegedAddress != creator);

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress calls setTreasury
        // Then: setTreasury should revert with UNAUTHORIZED
        vm.expectRevert("UNAUTHORIZED");
        pool.setTreasury(creator);
        vm.stopPrank();
    }

    function testSuccess_setTreasury() public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(creator);
        // When: creator setTreasury with creator address input
        pool.setTreasury(creator);
        vm.stopPrank();

        // Then: treasury should creators address
        assertEq(pool.treasury(), creator);
    }

    function testRevert_setOriginationFee_InvalidOwner(address unprivilegedAddress) public {
        // Given: all neccesary contracts are deployed on the setup
        vm.assume(unprivilegedAddress != creator);

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress calls setOriginationFee
        // Then: setOriginationFee should revert with UNAUTHORIZED
        vm.expectRevert("UNAUTHORIZED");
        pool.setOriginationFee(10);
        vm.stopPrank();
    }

    function testSuccess_setOriginationFee(uint8 fee) public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(creator);
        // When: creator calls setOriginationFee
        vm.expectEmit(true, true, true, true);
        emit OriginationFeeSet(fee);
        pool.setOriginationFee(fee);
        vm.stopPrank();

        // Then: treasury should creators address
        assertEq(pool.originationFee(), fee);
    }
}

/* //////////////////////////////////////////////////////////////
                        PROTOCOL CAP LOGIC
////////////////////////////////////////////////////////////// */
contract ProtocolCapTest is LendingPoolTest {
    function setUp() public override {
        super.setUp();
    }

    function testRevert_setBorrowCap_InvalidOwner(address unprivilegedAddress, uint128 borrowCap) public {
        // Given: all neccesary contracts are deployed on the setup
        // And: unprivilegedAddress is not the owner
        vm.assume(unprivilegedAddress != creator);

        // When: unprivilegedAddress calls setBorrowCap
        // Then: setOriginationFee should revert with UNAUTHORIZED
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setBorrowCap(borrowCap);
        vm.stopPrank();
    }

    function testSuccess_setBorrowCap(uint128 borrowCap) public {
        // Given: all neccesary contracts are deployed on the setup

        // When: Owner calls setBorrowCap
        vm.startPrank(creator);
        vm.expectEmit(true, true, true, true);
        emit BorrowCapSet(borrowCap);
        pool.setBorrowCap(borrowCap);
        vm.stopPrank();

        //Then: New borrowCap is set
        assertEq(pool.borrowCap(), borrowCap);
    }

    function testRevert_setSupplyCap_InvalidOwner(address unprivilegedAddress, uint128 supplyCap) public {
        // Given: all neccesary contracts are deployed on the setup
        // And: unprivilegedAddress is not the owner
        vm.assume(unprivilegedAddress != creator);

        // When: unprivilegedAddress calls setSupplyCap
        // Then: setOriginationFee should revert with UNAUTHORIZED
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setSupplyCap(supplyCap);
        vm.stopPrank();
    }

    function testSuccess_setSupplyCap(uint128 supplyCap) public {
        // Given: all neccesary contracts are deployed on the setup

        // When: Owner calls setSupplyCap
        vm.startPrank(creator);
        vm.expectEmit(true, true, true, true);
        emit SupplyCapSet(supplyCap);
        pool.setSupplyCap(supplyCap);
        vm.stopPrank();

        //Then: New supplyCap is set
        assertEq(pool.supplyCap(), supplyCap);
    }
}

/* //////////////////////////////////////////////////////////////
                    DEPOSIT / WITHDRAWAL LOGIC
////////////////////////////////////////////////////////////// */
contract DepositAndWithdrawalTest is LendingPoolTest {
    error FunctionIsPaused();
    error supplyCapExceeded();

    function setUp() public override {
        super.setUp();

        vm.startPrank(creator);
        pool.changeGuardian(creator);
        pool.addTranche(address(srTranche), 50, 0);
        pool.addTranche(address(jrTranche), 40, 20);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
    }

    function testRevert_depositInLendingPool_NonTranche(address unprivilegedAddress, uint128 assets, address from)
        public
    {
        // Given: all necessary contracts are deployed on the setup
        vm.assume(unprivilegedAddress != address(jrTranche));
        vm.assume(unprivilegedAddress != address(srTranche));

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress deposit
        // Then: deposit should revert with UNAUTHORIZED
        vm.expectRevert("LP: Only tranche");
        pool.depositInLendingPool(assets, from);
        vm.stopPrank();
    }

    function testRevert_depositInLendingPool_NotApproved(uint128 amount) public {
        vm.assume(amount > 0);
        // Given: liquidityProvider has not approved pool
        vm.prank(liquidityProvider);
        asset.approve(address(pool), 0);

        // When: srTranche deposits
        // Then: deposit should revert with stdError.arithmeticError
        vm.startPrank(address(srTranche));
        vm.expectRevert("TRANSFER_FROM_FAILED");
        pool.depositInLendingPool(amount, liquidityProvider);
        vm.stopPrank();
    }

    function testRevert_depositInLendingPool_Paused(uint128 amount0, uint128 amount1) public {
        // Given: totalAmount is amount0 added by amount1, liquidityProvider approve max value
        vm.assume(amount0 <= type(uint128).max - amount1);

        // When: pool is paused
        vm.warp(35 days);
        vm.prank(creator);
        pool.pause();

        // Then: depositInLendingPool is reverted with PAUSED
        vm.expectRevert(FunctionIsPaused.selector);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amount0, liquidityProvider);
        // And: depositInLendingPool is reverted with PAUSED
        vm.expectRevert(FunctionIsPaused.selector);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(amount1, liquidityProvider);
    }

    function testRevert_depositInLendingPool_SupplyCap(uint256 amount, uint128 supplyCap) public {
        // Given: amount should be greater than 1
        vm.assume(pool.totalRealisedLiquidity() + amount > supplyCap);
        vm.assume(supplyCap > 0);

        // When: supply cap is set to 1
        vm.prank(creator);
        pool.setSupplyCap(supplyCap);

        // Then: depositInLendingPool is reverted with supplyCapExceeded()
        vm.expectRevert(supplyCapExceeded.selector);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amount, liquidityProvider);
    }

    function testSuccess_depositInLendingPool_SupplyCapBackToZero(uint256 amount) public {
        // Given: amount should be greater than 1
        vm.assume(pool.totalRealisedLiquidity() + amount > 1);
        vm.assume(amount <= type(uint128).max);

        // When: supply cap is set to 1
        vm.prank(creator);
        pool.setSupplyCap(1);

        // Then: depositInLendingPool is reverted with supplyCapExceeded()
        vm.expectRevert(supplyCapExceeded.selector);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amount, liquidityProvider);

        // When: supply cap is set to 0
        vm.prank(creator);
        pool.setSupplyCap(0);

        // Then: depositInLendingPool is succeeded
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amount, liquidityProvider);

        // And: supplyBalances srTranche should be amount, totalSupply should be amount, supplyBalances pool should be amount
        assertEq(pool.realisedLiquidityOf(address(srTranche)), amount);
        assertEq(pool.totalRealisedLiquidity(), amount);
        assertEq(asset.balanceOf(address(pool)), amount);
    }

    function testSuccess_depositInLendingPool_FirstDepositByTranche(uint256 amount) public {
        vm.assume(amount <= type(uint128).max);
        vm.prank(address(srTranche));
        // When: srTranche deposit
        pool.depositInLendingPool(amount, liquidityProvider);

        // Then: supplyBalances srTranche should be amount, totalSupply should be amount, supplyBalances pool should be amount
        assertEq(pool.realisedLiquidityOf(address(srTranche)), amount);
        assertEq(pool.totalRealisedLiquidity(), amount);
        assertEq(asset.balanceOf(address(pool)), amount);
    }

    function testSuccess_depositInLendingPool_MultipleDepositsByTranches(uint128 amount0, uint128 amount1) public {
        // Given: totalAmount is amount0 added by amount1, liquidityProvider approve max value
        vm.assume(amount0 <= type(uint128).max - amount1);

        uint256 totalAmount = uint256(amount0) + uint256(amount1);

        vm.prank(address(srTranche));
        // When: srTranche deposit amount0, jrTranche deposit amount1
        pool.depositInLendingPool(amount0, liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(amount1, liquidityProvider);

        // Then: supplyBalances jrTranche should be amount1, totalSupply should be totalAmount, supplyBalances pool should be totalAmount
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), amount1);
        assertEq(pool.totalRealisedLiquidity(), totalAmount);
        assertEq(asset.balanceOf(address(pool)), totalAmount);
    }

    function testRevert_donateToTranche_indexIsNoTranche(uint256 index) public {
        vm.assume(index >= pool.numberOfTranches());

        vm.expectRevert(stdError.indexOOBError);
        pool.donateToTranche(index, 1);
    }

    function testRevert_donateToTranche_zeroAssets() public {
        vm.expectRevert("LP_DTT: Amount is 0");
        pool.donateToTranche(1, 0);
    }

    function testRevert_donateToTranche_SupplyCap(uint256 amount, uint128 supplyCap) public {
        // Given: amount should be greater than 1
        vm.assume(amount > 1);
        vm.assume(pool.totalRealisedLiquidity() + amount > supplyCap);
        vm.assume(supplyCap > 0);

        // When: supply cap is set to 1
        vm.prank(creator);
        pool.setSupplyCap(supplyCap);

        // Then: depositInLendingPool is reverted with supplyCapExceeded()
        vm.expectRevert(supplyCapExceeded.selector);
        pool.donateToTranche(1, amount);
    }

    function testRevert_donateToTranche_InsufficientShares(uint32 initialShares, uint128 assets, address donator)
        public
    {
        vm.assume(assets > 0);
        vm.assume(assets < type(uint128).max - pool.totalRealisedLiquidity() - initialShares);
        vm.assume(initialShares < 10 ** pool.decimals());

        vm.prank(creator);
        pool.setSupplyCap(type(uint128).max);

        vm.startPrank(liquidityProvider);
        srTranche.mint(initialShares, liquidityProvider);
        asset.transfer(donator, assets);
        vm.stopPrank();

        vm.startPrank(donator);
        asset.approve(address(pool), type(uint256).max);
        vm.expectRevert("LP_DTT: Insufficient shares");
        pool.donateToTranche(0, assets);
        vm.stopPrank();
    }

    function testSuccess_donateToTranche(uint8 index, uint128 assets, address donator, uint128 initialShares) public {
        vm.assume(assets > 0);
        vm.assume(assets <= type(uint128).max - pool.totalRealisedLiquidity() - initialShares);
        vm.assume(index < pool.numberOfTranches());
        vm.assume(initialShares >= 10 ** pool.decimals());

        vm.prank(creator);
        pool.setSupplyCap(type(uint128).max);

        address tranche = pool.tranches(index);
        vm.startPrank(liquidityProvider);
        Tranche(tranche).mint(initialShares, liquidityProvider);
        asset.transfer(donator, assets);
        vm.stopPrank();

        uint256 donatorBalancePre = asset.balanceOf(donator);
        uint256 poolBalancePre = asset.balanceOf(address(pool));
        uint256 realisedLiqOfPre = pool.realisedLiquidityOf(tranche);
        uint256 totalRealisedLiqPre = pool.totalRealisedLiquidity();

        vm.startPrank(donator);
        asset.approve(address(pool), type(uint256).max);

        // When: donateToPool
        pool.donateToTranche(index, assets);
        vm.stopPrank();

        uint256 donatorBalancePost = asset.balanceOf(donator);
        uint256 poolBalancePost = asset.balanceOf(address(pool));
        uint256 realisedLiqOfPost = pool.realisedLiquidityOf(tranche);
        uint256 totalRealisedLiqPost = pool.totalRealisedLiquidity();

        assertEq(donatorBalancePost + assets, donatorBalancePre);
        assertEq(poolBalancePost - assets, poolBalancePre);
        assertEq(realisedLiqOfPost - assets, realisedLiqOfPre);
        assertEq(totalRealisedLiqPost - assets, totalRealisedLiqPre);
    }

    function testRevert_withdrawFromLendingPool_Unauthorised(
        uint128 assetsWithdrawn,
        address receiver,
        address unprivilegedAddress
    ) public {
        // Given: unprivilegedAddress is not srTranche, liquidityProvider approve max value
        vm.assume(unprivilegedAddress != address(srTranche));
        vm.assume(assetsWithdrawn > 0);

        vm.prank(address(srTranche));
        // When: srTranche deposit assetsWithdrawn
        pool.depositInLendingPool(assetsWithdrawn, liquidityProvider);

        vm.startPrank(unprivilegedAddress);
        // Then: withdraw by unprivilegedAddress should revert with LP_WFLP: Amount exceeds balance
        vm.expectRevert("LP_WFLP: Amount exceeds balance");
        pool.withdrawFromLendingPool(assetsWithdrawn, receiver);
        vm.stopPrank();
    }

    function testRevert_withdrawFromLendingPool_InsufficientAssets(
        uint128 assetsDeposited,
        uint128 assetsWithdrawn,
        address receiver
    ) public {
        // Given: assetsWithdrawn bigger than assetsDeposited, liquidityProvider approve max value
        vm.assume(assetsDeposited < assetsWithdrawn);

        vm.startPrank(address(srTranche));
        // When: srTranche deposit assetsDeposited
        pool.depositInLendingPool(assetsDeposited, liquidityProvider);

        // Then: withdraw assetsWithdrawn should revert
        vm.expectRevert("LP_WFLP: Amount exceeds balance");
        pool.withdrawFromLendingPool(assetsWithdrawn, receiver);
        vm.stopPrank();
    }

    function testRevert_withdrawFromLendingPool_Paused(
        uint128 assetsDeposited,
        uint128 assetsWithdrawn,
        address receiver
    ) public {
        // Given: assetsWithdrawn less than assetsDeposited, receiver is not pool or liquidityProvider,
        // liquidityProvider approve max value, assetsDeposited and assetsWithdrawn are bigger than 0
        vm.assume(receiver != address(pool));
        vm.assume(receiver != liquidityProvider);
        vm.assume(assetsDeposited >= assetsWithdrawn);

        // And: srTranche deposit and withdraw
        vm.prank(address(srTranche));
        pool.depositInLendingPool(assetsDeposited, liquidityProvider);

        // When: pool is paused
        vm.warp(35 days);
        vm.prank(creator);
        pool.pause();

        // Then: withdrawFromLendingPool is reverted with PAUSED
        vm.expectRevert(FunctionIsPaused.selector);
        vm.prank(address(srTranche));
        pool.withdrawFromLendingPool(assetsWithdrawn, receiver);
    }

    function testSuccess_withdrawFromLendingPool(uint128 assetsDeposited, uint128 assetsWithdrawn, address receiver)
        public
    {
        // Given: assetsWithdrawn less than assetsDeposited, receiver is not pool or liquidityProvider,
        // liquidityProvider approve max value, assetsDeposited and assetsWithdrawn are bigger than 0
        vm.assume(receiver != address(pool));
        vm.assume(receiver != liquidityProvider);
        vm.assume(assetsDeposited >= assetsWithdrawn);

        vm.startPrank(address(srTranche));
        // When: srTranche deposit and withdraw
        pool.depositInLendingPool(assetsDeposited, liquidityProvider);

        pool.withdrawFromLendingPool(assetsWithdrawn, receiver);
        vm.stopPrank();

        // Then: supplyBalances srTranche, pool and totalSupply should be assetsDeposited minus assetsWithdrawn,
        // supplyBalances receiver should be assetsWithdrawn
        assertEq(pool.realisedLiquidityOf(address(srTranche)), assetsDeposited - assetsWithdrawn);
        assertEq(pool.totalRealisedLiquidity(), assetsDeposited - assetsWithdrawn);
        assertEq(asset.balanceOf(address(pool)), assetsDeposited - assetsWithdrawn);
        assertEq(asset.balanceOf(receiver), assetsWithdrawn);
    }
}

/* //////////////////////////////////////////////////////////////
                        LENDING LOGIC
////////////////////////////////////////////////////////////// */
contract LendingLogicTest is LendingPoolTest {
    using stdStorage for StdStorage;

    error FunctionIsPaused();

    function setUp() public override {
        super.setUp();

        vm.startPrank(creator);
        pool.addTranche(address(srTranche), 50, 0);
        pool.addTranche(address(jrTranche), 40, 20);
        pool.changeGuardian(creator);
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        vault = Vault(factory.createVault(1));
        vault.setTrustedCreditor(address(pool));
        vm.stopPrank();

        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
    }

    function testRevert_approveBeneficiary_NonVault(address beneficiary, uint256 amount, address nonVault) public {
        // Given: nonVault is not vault
        vm.assume(nonVault != address(vault));
        // When: approveBeneficiary with nonVault input on vault

        // Then: approveBeneficiary should revert with "LP_AB: UNAUTHORIZED"
        vm.expectRevert("LP_AB: UNAUTHORIZED");
        pool.approveBeneficiary(beneficiary, amount, nonVault);
    }

    function testRevert_approveBeneficiary_Unauthorised(
        address beneficiary,
        uint256 amount,
        address unprivilegedAddress
    ) public {
        // Given: unprivilegedAddress is not vaultOwner
        vm.assume(unprivilegedAddress != vaultOwner);

        vm.startPrank(unprivilegedAddress);
        // When: approveBeneficiary as unprivilegedAddress

        // Then: approveBeneficiary should revert with "LP_AB: UNAUTHORIZED"
        vm.expectRevert("LP_AB: UNAUTHORIZED");
        pool.approveBeneficiary(beneficiary, amount, address(vault));
        vm.stopPrank();
    }

    function testSuccess_approveBeneficiary(address beneficiary, uint256 amount) public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(vaultOwner);
        // When: approveBeneficiary as vaultOwner
        vm.expectEmit(true, true, true, true);
        emit CreditApproval(address(vault), vaultOwner, beneficiary, amount);
        pool.approveBeneficiary(beneficiary, amount, address(vault));
        vm.stopPrank();

        // Then: creditAllowance should be equal to amount
        assertEq(pool.creditAllowance(address(vault), vaultOwner, beneficiary), amount);
    }

    function testRevert_borrow_NonVault(uint256 amount, address nonVault, address to) public {
        // Given: nonVault is not vault
        vm.assume(nonVault != address(vault));
        // When: borrow as nonVault

        // Then: borrow should revert with "LP_B: Not a vault"
        vm.expectRevert("LP_B: Not a vault");
        pool.borrow(amount, nonVault, to, emptyBytes3);
    }

    function testRevert_borrow_Unauthorised(uint256 amount, address beneficiary, address to) public {
        // Given: beneficiary is not vaultOwner, amount is bigger than 0
        vm.assume(beneficiary != vaultOwner);

        vm.assume(amount > 0);
        vm.startPrank(beneficiary);
        // When: borrow as beneficiary

        // Then: borrow should revert with stdError.arithmeticError
        vm.expectRevert(stdError.arithmeticError);
        pool.borrow(amount, address(vault), to, emptyBytes3);
        vm.stopPrank();
    }

    function testRevert_borrow_InsufficientApproval(
        uint256 amountAllowed,
        uint256 amountLoaned,
        address beneficiary,
        address to
    ) public {
        // Given: beneficiary is not vaultOwner, amountAllowed is less than amountLoaned, vaultOwner approveBeneficiary
        vm.assume(beneficiary != vaultOwner);
        vm.assume(amountAllowed < amountLoaned);

        vm.prank(vaultOwner);
        pool.approveBeneficiary(beneficiary, amountAllowed, address(vault));

        vm.startPrank(beneficiary);
        // When: borrow as beneficiary

        // Then: borrow should revert with stdError.arithmeticError
        vm.expectRevert(stdError.arithmeticError);
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
        vm.stopPrank();
    }

    function testRevert_borrow_InsufficientApprovalAfterTransfer(
        uint256 amountLoaned,
        address beneficiary,
        address to,
        address newOwner
    ) public {
        // Given: beneficiary is not vaultOwner, vaultOwner approveBeneficiary
        vm.assume(beneficiary != newOwner);
        vm.assume(newOwner != vaultOwner);
        vm.assume(newOwner != address(0));
        vm.assume(amountLoaned > 0);

        vm.prank(vaultOwner);
        pool.approveBeneficiary(beneficiary, type(uint256).max, address(vault));
        uint256 vaultIndex = factory.vaultIndex(address(vault));
        stdstore.target(address(factory)).sig(factory.ownerOf.selector).with_key(vaultIndex).checked_write(newOwner);

        vm.startPrank(beneficiary);
        // When: borrow as beneficiary

        // Then: borrow should revert with stdError.arithmeticError
        vm.expectRevert(stdError.arithmeticError);
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
        vm.stopPrank();
    }

    function testRevert_borrow_InsufficientCollateral(uint128 amountLoaned, uint256 collateralValue, address to)
        public
    {
        // Given: collateralValue is less than amountLoaned, vault setTotalValue to colletrallValue
        vm.assume(collateralValue < amountLoaned);

        vault.setTotalValue(collateralValue);

        vm.startPrank(vaultOwner);
        // When: borrow amountLoaned as vaultOwner

        // Then: borrow should revert with "LP_B: Reverted"
        vm.expectRevert("LP_B: Reverted");
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
        vm.stopPrank();
    }

    function testRevert_borrow_DifferentTrustedCreditor(
        uint128 amountLoaned,
        uint256 collateralValue,
        address to,
        address trustedCreditor
    ) public {
        // Given: collateralValue is less than amountLoaned, vault setTotalValue to colletrallValue
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(trustedCreditor != address(pool));

        vault.setTotalValue(collateralValue);
        vault.setTrustedCreditor(trustedCreditor);

        vm.startPrank(vaultOwner);
        // When: borrow amountLoaned as vaultOwner

        // Then: borrow should revert with "LP_B: Reverted"
        vm.expectRevert("LP_B: Reverted");
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
        vm.stopPrank();
    }

    function testRevert_borrow_BadVaultVersion(uint128 amountLoaned, uint256 collateralValue, address to) public {
        // Given: collateralValue is less than amountLoaned, vault setTotalValue to colletrallValue
        vm.assume(collateralValue >= amountLoaned);

        vault.setTotalValue(collateralValue);

        vm.prank(creator);
        pool.setVaultVersion(0, false);

        vm.startPrank(vaultOwner);
        // When: borrow amountLoaned as vaultOwner

        // Then: borrow should revert with "LP_B: Reverted"
        vm.expectRevert("LP_B: Reverted");
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
        vm.stopPrank();
    }

    function testRevert_borrow_InsufficientLiquidity(
        uint128 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to
    ) public {
        // Given: collateralValue less than equal to amountLoaned, liquidity is bigger than 0 but less than amountLoaned,
        // to is not address 0, creator setDebtToken to debt, liquidityProvider approve pool to max value,
        // srTranche deposit liquidity, setTotalValue to colletralValue
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity < amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);
        vault.setTotalValue(collateralValue);

        vm.startPrank(vaultOwner);
        // When: borrow amountLoaned as vaultOwner

        // Then: borrow should revert with "TRANSFER_FAILED"
        vm.expectRevert("TRANSFER_FAILED");
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
        vm.stopPrank();
    }

    function testRevert_borrow_Paused(uint128 amountLoaned, uint256 collateralValue, uint128 liquidity, address to)
        public
    {
        // Given: collateralValue bigger than equal to amountLoaned, liquidity is bigger than 0 and amountLoaned,
        // to is not address 0, creator setDebtToken to debt, liquidityProvider approve pool to max value,
        // srTranche deposit liquidity, setTotalValue to colletralValue
        vm.assume(collateralValue <= amountLoaned);
        vm.assume(liquidity > amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));

        vm.warp(35 days);

        // And enough liquidity in the pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);
        vault.setTotalValue(collateralValue);
        // When: pool is paused
        vm.prank(creator);
        pool.pause();

        // Then: borrow should revert with "Guardian borrow paused"
        vm.expectRevert(FunctionIsPaused.selector);
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
    }

    function testRevert_borrow_BorrowCap(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to,
        uint128 borrowCap
    ) public {
        // Given: collateralValue bigger than equal to amountLoaned, liquidity is bigger than 0 and amountLoaned,
        // to is not address 0, creator setDebtToken to debt, liquidityProvider approve pool to max value,
        // srTranche deposit liquidity, setTotalValue to collateral Value
        vm.assume(amountLoaned > 1);
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity > amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));
        vm.assume(borrowCap > 0);
        vm.assume(borrowCap < amountLoaned);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);
        vault.setTotalValue(collateralValue);

        // When: borrow cap is set to 1
        vm.prank(creator);
        pool.setBorrowCap(borrowCap);

        // Then: borrow should revert with "LP_B: Borrow cap reached"
        vm.expectRevert("DT_D: BORROW_CAP_EXCEEDED");
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
    }

    function testSuccess_borrow_BorrowCapSetToZeroAgain(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to
    ) public {
        // Given: collateralValue bigger than equal to amountLoaned, liquidity is bigger than 0 and amountLoaned,
        // to is not address 0, creator setDebtToken to debt, liquidityProvider approve pool to max value,
        // srTranche deposit liquidity, setTotalValue to collateral Value
        vm.assume(amountLoaned > 1);
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity > amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));
        vm.assume(to != liquidityProvider);
        vm.assume(to != address(pool));

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);
        vault.setTotalValue(collateralValue);

        // When: borrow cap is set to 1
        vm.prank(creator);
        pool.setBorrowCap(1);

        // Then: borrow should revert with "LP_B: Borrow cap reached"
        vm.expectRevert("DT_D: BORROW_CAP_EXCEEDED");
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);

        // When: borrow cap is set to 0
        vm.prank(creator);
        pool.setBorrowCap(0);

        // Then: borrow should succeed
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
        assertEq(asset.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(asset.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(vault)), amountLoaned);
    }

    function testSuccess_borrow_BorrowCapNotReached(
        uint256 amountLoaned,
        uint256 amountLoanedToFail,
        uint256 collateralValue,
        uint128 liquidity,
        address to
    ) public {
        // Given: amountLoaned is greater than 1, and less than 100
        // collateralValue bigger than equal to amountLoaned, liquidity is bigger than 0 and amountLoaned,
        // to is not address 0, creator setDebtToken to debt, liquidityProvider approve pool to max value,
        // srTranche deposit liquidity, setTotalValue to collateral Value
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned < 100);
        vm.assume(amountLoanedToFail > 100);
        vm.assume(collateralValue >= amountLoanedToFail);
        vm.assume(liquidity > amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));
        vm.assume(to != liquidityProvider);
        vm.assume(to != address(pool));

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);
        vault.setTotalValue(collateralValue);

        // When: borrow cap is set to 1
        vm.prank(creator);
        pool.setBorrowCap(1);

        // Then: borrow should revert with "LP_B: Borrow cap reached"
        vm.expectRevert("DT_D: BORROW_CAP_EXCEEDED");
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);

        // When: borrow cap is set to 100 which is lower than the amountLoaned
        vm.prank(creator);
        pool.setBorrowCap(100);

        // Then: borrow should still fail with exceeding amount
        vm.expectRevert("DT_D: BORROW_CAP_EXCEEDED");
        vm.prank(vaultOwner);
        pool.borrow(amountLoanedToFail, address(vault), to, emptyBytes3);

        // When: right amount is used
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);

        // Then: borrow should succeed
        assertEq(asset.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(asset.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(vault)), amountLoaned);
    }

    function testSuccess_borrow_ByVaultOwner(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to
    ) public {
        // Given: collateralValue and liquidity bigger than equal to amountLoaned, amountLoaned is bigger than 0,
        // to is not address 0 and not liquidityProvider, creator setDebtToken to debt, setTotalValue to colletralValue,
        // liquidityProvider approve pool to max value, srTranche deposit liquidity
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(to != address(0));
        vm.assume(to != liquidityProvider);
        vm.assume(to != address(pool));

        vault.setTotalValue(collateralValue);
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);

        vm.startPrank(vaultOwner);
        // When: vaultOwner borrow amountLoaned
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
        vm.stopPrank();

        // Then: balanceOf pool should be equal to liquidity minus amountLoaned, balanceOf "to" should be equal to amountLoaned,
        // balanceOf vault should be equal to amountLoaned
        assertEq(asset.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(asset.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(vault)), amountLoaned);
    }

    function testSuccess_borrow_ByLimitedAuthorisedAddress(
        uint256 amountAllowed,
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address beneficiary,
        address to
    ) public {
        // Given: amountAllowed, collateralValue and liquidity bigger than equal to amountLoaned, amountLoaned is bigger than 0,
        // amountAllowed is less than max value, beneficiary is not vaultOwner, to is not address 0 and not liquidityProvider,
        // creator setDebtToken to debt, liquidityProvider approve pool to max value, srTranche deposit liquidity,
        // vaultOwner approveBeneficiary
        vm.assume(amountAllowed >= amountLoaned);
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountAllowed < type(uint256).max);
        vm.assume(beneficiary != vaultOwner);
        vm.assume(to != address(0));
        vm.assume(to != liquidityProvider);
        vm.assume(to != address(pool));

        vault.setTotalValue(collateralValue);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);
        vm.prank(vaultOwner);
        pool.approveBeneficiary(beneficiary, amountAllowed, address(vault));

        vm.startPrank(beneficiary);
        // When: beneficiary borrow amountLoaned
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
        vm.stopPrank();

        // Then: balanceOf pool should be equal to liquidity minus amountLoaned, balanceOf "to" should be equal to amountLoaned,
        // balanceOf vault should be equal to amountLoaned, creditAllowance should be equal to amountAllowed minus amountLoaned
        assertEq(asset.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(asset.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(vault)), amountLoaned);
        assertEq(pool.creditAllowance(address(vault), vaultOwner, beneficiary), amountAllowed - amountLoaned);
    }

    function testSuccess_borrow_ByMaxAuthorisedAddress(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address beneficiary,
        address to
    ) public {
        // Given: collateralValue and liquidity bigger than equal to amountLoaned, amountLoaned is bigger than 0,
        // beneficiary is not vaultOwner, to is not address 0 and not liquidityProvider,
        // creator setDebtToken to debt, setTotalValue to collateralValue, liquidityProvider approve pool to max value,
        // srTranche deposit liquidity, vaultOwner approveBeneficiary
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(beneficiary != vaultOwner);
        vm.assume(to != address(0));
        vm.assume(to != liquidityProvider);
        vm.assume(to != address(pool));

        vault.setTotalValue(collateralValue);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);
        vm.prank(vaultOwner);
        pool.approveBeneficiary(beneficiary, type(uint256).max, address(vault));

        vm.startPrank(beneficiary);
        // When: beneficiary borrow
        pool.borrow(amountLoaned, address(vault), to, emptyBytes3);
        vm.stopPrank();

        // Then: balanceOf pool should be equal to liquidity minus amountLoaned, balanceOf "to" should be equal to amountLoaned,
        // balanceOf vault should be equal to amountLoaned, creditAllowance should be equal to max value
        assertEq(asset.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(asset.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(vault)), amountLoaned);
        assertEq(pool.creditAllowance(address(vault), vaultOwner, beneficiary), type(uint256).max);
    }

    function testSuccess_borrow_originationFeeAvailable(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to,
        uint8 originationFee,
        bytes3 ref
    ) public {
        vm.assume(amountLoaned <= type(uint256).max / (uint256(originationFee) + 1));
        vm.assume(amountLoaned <= type(uint256).max - (amountLoaned * originationFee / 10_000));
        vm.assume(collateralValue >= amountLoaned + (amountLoaned * originationFee / 10_000));
        vm.assume(liquidity >= amountLoaned);
        vm.assume(liquidity <= type(uint128).max - (amountLoaned * originationFee / 10_000));
        vm.assume(to != address(0));
        vm.assume(to != liquidityProvider);
        vm.assume(to != address(pool));

        vm.prank(creator);
        pool.setOriginationFee(originationFee);

        vault.setTotalValue(collateralValue);
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);

        uint256 treasuryBalancePre = pool.realisedLiquidityOf(treasury);
        uint256 totalRealisedLiquidityPre = pool.totalRealisedLiquidity();

        vm.startPrank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), to, ref);
        vm.stopPrank();

        uint256 treasuryBalancePost = pool.realisedLiquidityOf(treasury);
        uint256 totalRealisedLiquidityPost = pool.totalRealisedLiquidity();

        // Then: balanceOf pool should be equal to liquidity minus amountLoaned, balanceOf "actionHandler" should be equal to amountLoaned,
        // balanceOf vault should be equal to amountLoaned + fee
        assertEq(asset.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(asset.balanceOf(to), amountLoaned);

        assertEq(debt.balanceOf(address(vault)), amountLoaned + (amountLoaned * originationFee / 10_000));
        assertEq(treasuryBalancePre + (amountLoaned * originationFee / 10_000), treasuryBalancePost);
        assertEq(totalRealisedLiquidityPre + (amountLoaned * originationFee / 10_000), totalRealisedLiquidityPost);
    }

    function testSuccess_borrow_EmitReferralEvent(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to,
        uint8 originationFee,
        bytes3 ref
    ) public {
        // Given: collateralValue and liquidity bigger than equal to amountLoaned, amountLoaned is bigger than 0,
        // to is not address 0 and not liquidityProvider, creator setDebtToken to debt, setTotalValue to colletralValue,
        // liquidityProvider approve pool to max value, srTranche deposit liquidity
        vm.assume(amountLoaned <= type(uint256).max / (uint256(originationFee) + 1));
        vm.assume(amountLoaned <= type(uint256).max - (amountLoaned * originationFee / 10_000));
        vm.assume(collateralValue >= amountLoaned + (amountLoaned * originationFee / 10_000));
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(to != address(0));
        vm.assume(to != liquidityProvider);
        vm.assume(to != address(pool));

        uint256 fee = amountLoaned * originationFee / 10_000;

        vm.prank(creator);
        pool.setOriginationFee(originationFee);

        vault.setTotalValue(collateralValue);
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);

        vm.startPrank(vaultOwner);
        vm.expectEmit(true, true, true, true);
        emit Borrow(address(vault), vaultOwner, to, amountLoaned, fee, ref);
        pool.borrow(amountLoaned, address(vault), to, ref);
        vm.stopPrank();
    }

    function testRevert_repay_InsufficientFunds(uint128 amountLoaned, uint256 availablefunds, address sender) public {
        // Given: amountLoaned is bigger than availablefunds, availablefunds bigger than 0,
        // sender is not zero address, liquidityProvider or vaultOwner, creator setDebtToken to debt,
        // setTotalValue to amountLoaned, liquidityProvider approve max value, transfer availablefunds,
        // srTranche deposit amountLoaned, vaultOwner borrow amountLoaned
        vm.assume(amountLoaned > availablefunds);
        vm.assume(availablefunds > 0);
        vm.assume(sender != address(0));
        vm.assume(sender != liquidityProvider);
        vm.assume(sender != vaultOwner);

        vault.setTotalValue(amountLoaned);
        vm.prank(liquidityProvider);
        asset.transfer(sender, availablefunds);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, liquidityProvider);
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), vaultOwner, emptyBytes3);

        vm.startPrank(sender);
        asset.approve(address(pool), type(uint256).max);
        // When: sender repays amountLoaned which is more than his available funds
        // Then: repay should revert with an ovcerflow
        vm.expectRevert("TRANSFER_FROM_FAILED");
        pool.repay(amountLoaned, address(vault));
        vm.stopPrank();
    }

    function testRevert_repay_Paused(uint128 amountLoaned, uint256 availableFunds, address sender) public {
        // Given: amountLoaned is greater than availableFunds, availableFunds greater than 0,
        // sender is not zero address, liquidityProvider or vaultOwner, creator setDebtToken to debt,
        // setTotalValue to amountLoaned, liquidityProvider approve max value, transfer availableFunds,
        // srTranche deposit amountLoaned, vaultOwner borrow amountLoaned
        vm.assume(amountLoaned > availableFunds);
        vm.assume(availableFunds > 0);
        vm.assume(sender != address(0));
        vm.assume(sender != liquidityProvider);
        vm.assume(sender != vaultOwner);
        vm.warp(35 days);

        vault.setTotalValue(amountLoaned);
        vm.prank(liquidityProvider);
        asset.transfer(sender, availableFunds);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, liquidityProvider);
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), vaultOwner, emptyBytes3);

        // When: pool is paused
        vm.prank(creator);
        pool.pause();

        vm.startPrank(sender);
        asset.approve(address(pool), type(uint256).max);
        // Then: repay should revert with an Paused
        vm.expectRevert(FunctionIsPaused.selector);
        pool.repay(amountLoaned, address(vault));
        vm.stopPrank();
    }

    function testRevert_repay_NonVault(uint128 availablefunds, uint256 amountRepaid, address sender, address nonVault)
        public
    {
        // Given: nonVault is not vault
        vm.assume(nonVault != address(vault));
        vm.assume(availablefunds > amountRepaid);
        vm.assume(sender != liquidityProvider);
        vm.prank(liquidityProvider);
        asset.transfer(sender, availablefunds);

        // When: repay amount to nonVault
        // Then: repay should revert
        vm.startPrank(sender);
        vm.expectRevert("DT_W: ZERO_SHARES");
        pool.repay(amountRepaid, nonVault);
        vm.stopPrank();
    }

    function testSuccess_repay_AmountInferiorLoan(uint128 amountLoaned, uint256 amountRepaid, address sender) public {
        // Given: amountLoaned is bigger than amountRepaid, amountRepaid bigger than 0,
        // sender is not zero address, liquidityProvider, vaultOwner or pool, creator setDebtToken to debt,
        // setTotalValue to amountLoaned, liquidityProvider approve max value, transfer amountRepaid,
        // srTranche deposit amountLoaned, vaultOwner borrow amountLoaned
        vm.assume(amountLoaned > amountRepaid);
        vm.assume(amountRepaid > 0);
        vm.assume(sender != address(0));
        vm.assume(sender != liquidityProvider);
        vm.assume(sender != vaultOwner);
        vm.assume(sender != address(pool));

        vault.setTotalValue(amountLoaned);
        vm.prank(liquidityProvider);
        asset.transfer(sender, amountRepaid);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, liquidityProvider);
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), vaultOwner, emptyBytes3);

        vm.startPrank(sender);
        // When: sender approve pool with max value, repay amountRepaid
        asset.approve(address(pool), type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit Repay(address(vault), sender, amountRepaid);
        pool.repay(amountRepaid, address(vault));
        vm.stopPrank();

        // Then: balanceOf pool should be equal to amountRepaid, balanceOf sender should be equal to 0,
        // balanceOf vault should be equal to amountLoaned minus amountRepaid
        assertEq(asset.balanceOf(address(pool)), amountRepaid);
        assertEq(asset.balanceOf(sender), 0);
        assertEq(debt.balanceOf(address(vault)), amountLoaned - amountRepaid);
    }

    function testSuccess_Repay_ExactAmount(uint128 amountLoaned, address sender) public {
        // Given: amountLoaned is bigger than 0, sender is not zero address, liquidityProvider, vaultOwner or pool,
        // creator setDebtToken to debt, setTotalValue to amountLoaned, liquidityProvider approve max value, transfer amountRepaid,
        // srTranche deposit amountLoaned, vaultOwner borrow amountLoaned
        vm.assume(amountLoaned > 0);
        vm.assume(sender != address(0));
        vm.assume(sender != liquidityProvider);
        vm.assume(sender != vaultOwner);
        vm.assume(sender != address(pool));

        vault.setTotalValue(amountLoaned);
        vm.prank(liquidityProvider);
        asset.transfer(sender, amountLoaned);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, liquidityProvider);
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), vaultOwner, emptyBytes3);

        vm.startPrank(sender);
        // When: sender approve pool with max value, repay amountLoaned
        asset.approve(address(pool), type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit Repay(address(vault), sender, amountLoaned);
        pool.repay(amountLoaned, address(vault));
        vm.stopPrank();

        // Then: balanceOf pool should be equal to amountLoaned, balanceOf sender and vault should be equal to 0
        assertEq(asset.balanceOf(address(pool)), amountLoaned);
        assertEq(asset.balanceOf(sender), 0);
        assertEq(debt.balanceOf(address(vault)), 0);
    }

    function testSuccess_repay_AmountExceedingLoan(uint128 amountLoaned, uint128 availablefunds, address sender)
        public
    {
        // Given: availablefunds is bigger than amountLoaned, amountLoaned bigger than 0,
        // sender is not zero address, liquidityProvider, vaultOwner or pool, creator setDebtToken to debt,
        // setTotalValue to amountLoaned, liquidityProvider approve max value, transfer availablefunds,
        // srTranche deposit amountLoaned, vaultOwner borrow amountLoaned
        vm.assume(availablefunds > amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(sender != address(0));
        vm.assume(sender != liquidityProvider);
        vm.assume(sender != vaultOwner);
        vm.assume(sender != address(pool));

        vault.setTotalValue(amountLoaned);
        vm.prank(liquidityProvider);
        asset.transfer(sender, availablefunds);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, liquidityProvider);
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), vaultOwner, emptyBytes3);

        vm.startPrank(sender);
        // When: sender approve pool with max value, repay availablefunds
        asset.approve(address(pool), type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit Repay(address(vault), sender, amountLoaned);
        pool.repay(availablefunds, address(vault));
        vm.stopPrank();

        // Then: balanceOf pool should be equal to amountLoaned, balanceOf sender should be equal to availablefunds minus amountLoaned,
        // balanceOf vault should be equal to 0
        assertEq(asset.balanceOf(address(pool)), amountLoaned);
        assertEq(asset.balanceOf(sender), availablefunds - amountLoaned);
        assertEq(debt.balanceOf(address(vault)), 0);
    }
}

/* //////////////////////////////////////////////////////////////
                    LEVERAGED ACTIONS LOGIC
////////////////////////////////////////////////////////////// */
contract LeveragedActions is LendingPoolTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(creator);
        pool.addTranche(address(srTranche), 50, 0);
        pool.addTranche(address(jrTranche), 40, 20);
        vm.stopPrank();

        vm.prank(vaultOwner);
        vault = Vault(factory.createVault(1));
        vault.setTrustedCreditor(address(pool));

        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
    }

    function testRevert_doActionWithLeverage_NonVault(
        uint256 amount,
        address nonVault,
        address actionHandler,
        bytes calldata actionData
    ) public {
        // Given: nonVault is not vault
        vm.assume(nonVault != address(vault));
        // When: doActionWithLeverage as nonVault

        // Then: doActionWithLeverage should revert with "LP_DAWL: Not a vault"
        vm.expectRevert("LP_DAWL: Not a vault");
        pool.doActionWithLeverage(amount, nonVault, actionHandler, actionData, emptyBytes3);
    }

    function testRevert_doActionWithLeverage_Unauthorised(
        uint256 amount,
        address beneficiary,
        address actionHandler,
        bytes calldata actionData
    ) public {
        // Given: beneficiary is not vaultOwner, amount is bigger than 0
        vm.assume(beneficiary != vaultOwner);

        vm.startPrank(beneficiary);
        // When: doActionWithLeverage as beneficiary

        // Then: doActionWithLeverage should revert with stdError.arithmeticError
        vm.expectRevert("LP_DAWL: UNAUTHORIZED");
        pool.doActionWithLeverage(amount, address(vault), actionHandler, actionData, emptyBytes3);
        vm.stopPrank();
    }

    function testRevert_doActionWithLeverage_ByLimitedAuthorisedAddress(
        uint256 amountAllowed,
        uint256 amountLoaned,
        address beneficiary,
        address actionHandler,
        bytes calldata actionData
    ) public {
        // Given: beneficiary is not vaultOwner, amountAllowed is less than amountLoaned, vaultOwner approveBeneficiary
        vm.assume(beneficiary != vaultOwner);
        vm.assume(amountAllowed < type(uint256).max);

        vm.prank(vaultOwner);
        pool.approveBeneficiary(beneficiary, amountAllowed, address(vault));

        vm.startPrank(beneficiary);
        // When: doActionWithLeverage as beneficiary

        // Then: doActionWithLeverage should revert with stdError.arithmeticError
        vm.expectRevert("LP_DAWL: UNAUTHORIZED");
        pool.doActionWithLeverage(amountLoaned, address(vault), actionHandler, actionData, emptyBytes3);
        vm.stopPrank();
    }

    function testRevert_doActionWithLeverage_InsufficientLiquidity(
        uint128 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address actionHandler,
        bytes calldata actionData
    ) public {
        // Given: collateralValue less than equal to amountLoaned, liquidity is bigger than 0 but less than amountLoaned,
        // actionHandler is not address 0, creator setDebtToken to debt, liquidityProvider approve pool to max value,
        // srTranche deposit liquidity, setTotalValue to colletralValue
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity < amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(actionHandler != address(0));

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);
        vault.setTotalValue(collateralValue);

        vm.startPrank(vaultOwner);
        // When: doActionWithLeverage amountLoaned as vaultOwner

        // Then: doActionWithLeverage should revert with "TRANSFER_FAILED"
        vm.expectRevert("TRANSFER_FAILED");
        pool.doActionWithLeverage(amountLoaned, address(vault), actionHandler, actionData, emptyBytes3);
        vm.stopPrank();
    }

    function testSuccess_doActionWithLeverage_ByVaultOwner(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address actionHandler,
        bytes calldata actionData
    ) public {
        // Given: collateralValue and liquidity bigger than equal to amountLoaned, amountLoaned is bigger than 0,
        // actionHandler is not address 0 and not liquidityProvider, creator setDebtToken to debt, setTotalValue to colletralValue,
        // liquidityProvider approve pool to max value, srTranche deposit liquidity
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(actionHandler != address(0));
        vm.assume(actionHandler != liquidityProvider);

        vault.setTotalValue(collateralValue);
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);

        vm.startPrank(vaultOwner);
        // When: vaultOwner does action with leverage of amountLoaned
        pool.doActionWithLeverage(amountLoaned, address(vault), actionHandler, actionData, emptyBytes3);
        vm.stopPrank();

        // Then: balanceOf pool should be equal to liquidity minus amountLoaned, balanceOf "actionHandler" should be equal to amountLoaned,
        // balanceOf vault should be equal to amountLoaned
        assertEq(asset.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(asset.balanceOf(actionHandler), amountLoaned);
        assertEq(debt.balanceOf(address(vault)), amountLoaned);
    }

    function testSuccess_doActionWithLeverage_ByMaxAuthorisedAddress(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address beneficiary,
        address actionHandler,
        bytes calldata actionData
    ) public {
        // Given: collateralValue and liquidity bigger than equal to amountLoaned, amountLoaned is bigger than 0,
        // beneficiary is not vaultOwner, actionHandler is not address 0 and not liquidityProvider,
        // creator setDebtToken to debt, setTotalValue to collateralValue, liquidityProvider approve pool to max value,
        // srTranche deposit liquidity, vaultOwner approveBeneficiary
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(beneficiary != vaultOwner);
        vm.assume(actionHandler != address(0));
        vm.assume(actionHandler != liquidityProvider);
        vm.assume(actionHandler != address(pool));

        vault.setTotalValue(collateralValue);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);
        vm.prank(vaultOwner);
        pool.approveBeneficiary(beneficiary, type(uint256).max, address(vault));

        vm.startPrank(beneficiary);
        // When: beneficiary does action with leverage of amountLoaned
        pool.doActionWithLeverage(amountLoaned, address(vault), actionHandler, actionData, emptyBytes3);
        vm.stopPrank();

        // Then: balanceOf pool should be equal to liquidity minus amountLoaned, balanceOf "actionHandler" should be equal to amountLoaned,
        // balanceOf vault should be equal to amountLoaned, creditAllowance should be equal to max value
        assertEq(asset.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(asset.balanceOf(actionHandler), amountLoaned);
        assertEq(debt.balanceOf(address(vault)), amountLoaned);
        assertEq(pool.creditAllowance(address(vault), vaultOwner, beneficiary), type(uint256).max);
    }

    function testSuccss_doActionWithLeverage_originationFeeAvailable(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address actionHandler,
        bytes calldata actionData,
        uint8 originationFee
    ) public {
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(liquidity <= type(uint128).max - (amountLoaned * originationFee / 10_000));
        vm.assume(amountLoaned > 0);
        vm.assume(actionHandler != address(0));
        vm.assume(actionHandler != liquidityProvider);

        vm.prank(creator);
        pool.setOriginationFee(originationFee);

        vault.setTotalValue(collateralValue);
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);

        uint256 treasuryBalancePre = pool.realisedLiquidityOf(treasury);
        uint256 totalRealisedLiquidityPre = pool.totalRealisedLiquidity();

        vm.startPrank(vaultOwner);
        // When: vaultOwner does action with leverage of amountLoaned
        pool.doActionWithLeverage(amountLoaned, address(vault), actionHandler, actionData, emptyBytes3);
        vm.stopPrank();

        uint256 treasuryBalancePost = pool.realisedLiquidityOf(treasury);
        uint256 totalRealisedLiquidityPost = pool.totalRealisedLiquidity();

        // Then: balanceOf pool should be equal to liquidity minus amountLoaned, balanceOf "actionHandler" should be equal to amountLoaned,
        // balanceOf vault should be equal to amountLoaned + fee
        assertEq(asset.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(asset.balanceOf(actionHandler), amountLoaned);
        assertEq(debt.balanceOf(address(vault)), amountLoaned + (amountLoaned * originationFee / 10_000));
        assertEq(treasuryBalancePre + (amountLoaned * originationFee / 10_000), treasuryBalancePost);
        assertEq(totalRealisedLiquidityPre + (amountLoaned * originationFee / 10_000), totalRealisedLiquidityPost);
    }

    function testSuccess_doActionWithLeverage_EmitReferralEvent(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address actionHandler,
        bytes calldata actionData,
        uint8 originationFee,
        bytes3 ref
    ) public {
        vm.assume(amountLoaned <= type(uint256).max / (uint256(originationFee) + 1));
        vm.assume(amountLoaned <= type(uint256).max - (amountLoaned * originationFee / 10_000));
        vm.assume(collateralValue >= amountLoaned + (amountLoaned * originationFee / 10_000));
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(actionHandler != address(0));
        vm.assume(actionHandler != liquidityProvider);

        uint256 fee = amountLoaned * originationFee / 10_000;

        vm.prank(creator);
        pool.setOriginationFee(originationFee);

        vault.setTotalValue(collateralValue);
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);

        vm.startPrank(vaultOwner);
        vm.expectEmit(true, true, true, true);
        emit Borrow(address(vault), vaultOwner, actionHandler, amountLoaned, fee, ref);
        // When: vaultOwner does action with leverage of amountLoaned
        pool.doActionWithLeverage(amountLoaned, address(vault), actionHandler, actionData, ref);
        vm.stopPrank();
    }
}

/* //////////////////////////////////////////////////////////////
                        ACCOUNTING LOGIC
////////////////////////////////////////////////////////////// */
contract AccountingTest is LendingPoolTest {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();

        vm.startPrank(creator);
        pool.addTranche(address(srTranche), 50, 0);
        pool.addTranche(address(jrTranche), 40, 20);
        vm.stopPrank();

        vm.prank(vaultOwner);
        vault = Vault(factory.createVault(1));
        vault.setTrustedCreditor(address(pool));

        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
    }

    function testSuccess_totalAssets(uint120 realisedDebt, uint256 interestRate, uint24 deltaTimestamp) public {
        // Given: all neccesary contracts are deployed on the setup
        vm.assume(interestRate <= 1e3 * 1e18);
        //1000%
        vm.assume(interestRate > 0);
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60);
        //5 year

        vm.prank(address(srTranche));
        pool.depositInLendingPool(type(uint128).max, liquidityProvider);
        vm.prank(creator);
        vault.setTotalValue(realisedDebt);

        vm.prank(vaultOwner);
        pool.borrow(realisedDebt, address(vault), vaultOwner, emptyBytes3);

        vm.prank(creator);
        pool.setInterestRate(interestRate);

        vm.warp(block.timestamp + deltaTimestamp);

        uint256 unrealisedDebt = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);
        uint256 expectedValue = realisedDebt + unrealisedDebt;

        uint256 actualValue = debt.totalAssets();

        assertEq(actualValue, expectedValue);
    }

    function testSuccess_liquidityOf(
        uint256 interestRate,
        uint24 deltaTimestamp,
        uint128 realisedDebt,
        uint120 initialLiquidity
    ) public {
        // Given: all necessary contracts are deployed on the setup
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60);
        //5 year
        vm.assume(interestRate <= 1e3 * 10 ** 18);
        //1000%
        vm.assume(interestRate > 0);
        vm.assume(initialLiquidity >= realisedDebt);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(initialLiquidity, liquidityProvider);
        vault.setTotalValue(realisedDebt);

        vm.prank(vaultOwner);
        pool.borrow(realisedDebt, address(vault), vaultOwner, emptyBytes3);

        // When: deltaTimestamp amount of time has passed
        vm.warp(block.timestamp + deltaTimestamp);

        vm.prank(creator);
        pool.setInterestRate(interestRate);

        uint256 unrealisedDebt = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);
        uint256 interest = unrealisedDebt * 50 / 90;
        if (interest * 90 < unrealisedDebt * 50) interest += 1;
        // interest for a tranche is rounded up
        uint256 expectedValue = initialLiquidity + interest;

        uint256 actualValue = pool.liquidityOf(address(srTranche));

        // Then: actualValue should be equal to expectedValue
        assertEq(actualValue, expectedValue);
    }

    function testRevert_skim_OngoingAuctions(uint16 auctionsInProgress_, address sender) public {
        vm.assume(auctionsInProgress_ > 0);
        pool.setAuctionsInProgress(auctionsInProgress_);

        vm.startPrank(sender);
        vm.expectRevert("LP_S: Auctions Ongoing");
        pool.skim();
        vm.stopPrank();
    }

    function testSuccess_skim(uint128 balanceOf, uint128 totalDebt, uint128 totalLiquidity, address sender) public {
        vm.assume(uint256(balanceOf) + totalDebt <= type(uint128).max);
        vm.assume(totalLiquidity <= balanceOf + totalDebt);

        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedDebt(totalDebt);
        vm.prank(liquidityProvider);
        asset.transfer(address(pool), balanceOf);

        vm.prank(sender);
        pool.skim();

        assertEq(pool.totalRealisedLiquidity(), balanceOf + totalDebt);
        assertEq(pool.realisedLiquidityOf(treasury), balanceOf + totalDebt - totalLiquidity);
    }
}

/* //////////////////////////////////////////////////////////////
                        INTERESTS LOGIC
////////////////////////////////////////////////////////////// */
contract InterestsTest is LendingPoolTest {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();

        vm.startPrank(creator);
        pool.setTreasuryInterestWeight(10);
        pool.setTreasuryLiquidationWeight(80);
        pool.addTranche(address(srTranche), 50, 0);
        pool.addTranche(address(jrTranche), 40, 20);
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        vault = Vault(factory.createVault(1));
        vault.setTrustedCreditor(address(pool));
        vm.stopPrank();
    }

    function testSuccess_calcUnrealisedDebt_Unchecked(uint24 deltaTimestamp, uint128 realisedDebt, uint256 interestRate)
        public
    {
        // Given: deltaTimestamp smaller than equal to 5 years,
        // realisedDebt smaller than equal to than 3402823669209384912995114146594816
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60);
        //5 year
        vm.assume(interestRate <= 10 * 10 ** 18);
        //1000%
        vm.assume(realisedDebt <= type(uint128).max / (10 ** 5));
        //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816

        vm.startPrank(creator);
        pool.setInterestRate(interestRate);
        pool.setLastSyncedTimestamp(uint32(block.number));
        // And: the vaultOwner takes realisedDebt debt
        pool.setRealisedDebt(realisedDebt);
        vm.stopPrank();

        // When: deltaTimestamp have passed
        vm.warp(block.timestamp + deltaTimestamp);

        // Then: Unrealised debt should never overflow (-> calcUnrealisedDebtChecked does never error and same calculation unched are always equal)
        uint256 expectedValue = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);
        uint256 actualValue = pool.calcUnrealisedDebt();
        assertEq(expectedValue, actualValue);
    }

    function testSucces_syncInterests(
        uint24 deltaTimestamp,
        uint128 realisedDebt,
        uint120 realisedLiquidity,
        uint256 interestRate
    ) public {
        // Given: deltaTimestamp than 5 years, realisedDebt than 3402823669209384912995114146594816 and bigger than 0
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60);
        //5 year
        vm.assume(interestRate <= 10 * 10 ** 18);
        //1000%
        vm.assume(realisedDebt <= type(uint128).max / (10 ** 5));
        //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816
        vm.assume(realisedDebt > 0);
        vm.assume(realisedDebt <= realisedLiquidity);

        // And: the vaultOwner takes realisedDebt debt
        vault.setTotalValue(realisedDebt);
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(realisedLiquidity, liquidityProvider);
        vm.prank(vaultOwner);
        pool.borrow(realisedDebt, address(vault), address(vault), emptyBytes3);

        // And: deltaTimestamp have passed
        uint256 start_timestamp = block.timestamp;
        vm.warp(start_timestamp + deltaTimestamp);

        // When: Intersts are synced
        vm.prank(creator);
        pool.setInterestRate(interestRate);
        pool.syncInterests();

        uint256 interests = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);

        // Then: Total redeemable interest of LP providers and total open debt of borrowers should increase with interests
        assertEq(pool.totalRealisedLiquidity(), realisedLiquidity + interests);
        assertEq(debt.maxWithdraw(address(vault)), realisedDebt + interests);
        assertEq(debt.maxRedeem(address(vault)), realisedDebt);
        assertEq(debt.totalAssets(), realisedDebt + interests);
        assertEq(pool.lastSyncedTimestamp(), start_timestamp + deltaTimestamp);
    }

    function testSuccess_syncInterestsToLiquidityProviders(
        uint128 interests,
        uint8 weightSr,
        uint8 weightJr,
        uint8 weightTreasury
    ) public {
        uint256 totalInterestWeight = uint256(weightSr) + uint256(weightJr) + uint256(weightTreasury);
        vm.assume(totalInterestWeight > 0);
        // Given: all necessary contracts are deployed on the setup
        vm.startPrank(creator);
        pool.setInterestWeight(0, weightSr);
        pool.setInterestWeight(1, weightJr);
        pool.setTreasuryInterestWeight(weightTreasury);
        vm.stopPrank();

        // When: creator syncInterestsToLendingPool with amount
        pool.syncInterestsToLendingPool(interests);

        // Then: supplyBalances srTranche, jrTranche and treasury should be correct
        // TotalSupply should be equal to interest
        uint256 interestSr = uint256(interests) * weightSr / totalInterestWeight;
        uint256 interestJr = uint256(interests) * weightJr / totalInterestWeight;
        uint256 interestTreasury = interests - interestSr - interestJr;

        assertEq(pool.realisedLiquidityOf(address(srTranche)), interestSr);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), interestJr);
        assertEq(pool.realisedLiquidityOf(address(treasury)), interestTreasury);
        assertEq(pool.totalRealisedLiquidity(), interests);
    }
}

/* //////////////////////////////////////////////////////////////
                    INTEREST RATE LOGIC
////////////////////////////////////////////////////////////// */
contract InterestRateTest is LendingPoolTest {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();

        vm.startPrank(creator);
        pool.setTreasuryInterestWeight(10);
        pool.setTreasuryLiquidationWeight(80);
        pool.addTranche(address(srTranche), 50, 0);
        pool.addTranche(address(jrTranche), 40, 20);
        vm.stopPrank();
    }

    function testRevert_setInterestConfig_NonOwner(
        address unprivilegedAddress,
        uint8 baseRate_,
        uint8 highSlope_,
        uint8 lowSlope_,
        uint8 utilisationThreshold_
    ) public {
        // Given: unprivilegedAddress is not creator, InterestRateConfiguration setted as config
        vm.assume(unprivilegedAddress != creator);

        // And: InterestRateConfiguration setted as config
        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });

        // When: unprivilegedAddress calls setInterestConfig
        vm.startPrank(unprivilegedAddress);
        // Then: setInterestConfig should revert with UNAUTHORIZED
        vm.expectRevert("UNAUTHORIZED");
        pool.setInterestConfig(config);
        vm.stopPrank();
    }

    function testSuccess_setInterestConfig(
        uint8 baseRate_,
        uint8 highSlope_,
        uint8 lowSlope_,
        uint8 utilisationThreshold_
    ) public {
        // Given: InterestRateConfiguration data type setted as config
        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });

        // When: creator calls setInterestConfig
        vm.prank(creator);
        pool.setInterestConfig(config);

        // Then: config is successfully set
        (uint256 baseRatePerYear, uint256 lowSlopePerYear, uint256 highSlopePerYear, uint256 utilisationThreshold) =
            pool.interestRateConfig();
        assertEq(baseRatePerYear, baseRate_);
        assertEq(highSlopePerYear, highSlope_);
        assertEq(lowSlopePerYear, lowSlope_);
        assertEq(utilisationThreshold, utilisationThreshold_);
    }

    function testSuccess_updateInterestRate(
        address sender,
        uint24 deltaTimestamp,
        uint128 realisedDebt,
        uint120 realisedLiquidity,
        uint256 interestRate
    ) public {
        // Given: deltaBlocks smaller than equal to 5 years,
        // realisedDebt smaller than equal to than 3402823669209384912995114146594816
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60);
        //5 year
        vm.assume(interestRate <= 10 * 10 ** 18);
        //1000%
        vm.assume(realisedDebt <= type(uint128).max / (10 ** 5));
        //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816
        vm.assume(realisedDebt <= realisedLiquidity);

        // And: There is realisedLiquidity liquidity
        vm.startPrank(creator);
        pool.setTotalRealisedLiquidity(realisedLiquidity);
        // And: There is realisedDebt debt
        pool.setRealisedDebt(realisedDebt);
        pool.setInterestRate(interestRate);
        pool.setLastSyncedTimestamp(uint32(block.number));
        vm.stopPrank();

        // And: deltaTimestamp have passed
        uint256 start_timestamp = block.timestamp;
        vm.warp(start_timestamp + deltaTimestamp);

        // When: Interests are updated
        vm.prank(sender);
        pool.updateInterestRate();

        // Then interests should be up to date
        uint256 interest = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);
        uint256 interestSr = interest * 50 / 100;
        uint256 interestJr = interest * 40 / 100;
        uint256 interestTreasury = interest - interestSr - interestJr;

        assertEq(debt.totalAssets(), realisedDebt + interest);
        assertEq(pool.lastSyncedTimestamp(), start_timestamp + deltaTimestamp);
        assertEq(pool.realisedLiquidityOf(address(srTranche)), interestSr);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), interestJr);
        assertEq(pool.realisedLiquidityOf(address(treasury)), interestTreasury);
        assertEq(pool.totalRealisedLiquidity(), realisedLiquidity + interest);
    }
}

/* //////////////////////////////////////////////////////////////
                        LIQUIDATION LOGIC
////////////////////////////////////////////////////////////// */
contract LiquidationTest is LendingPoolTest {
    using stdStorage for StdStorage;

    error FunctionIsPaused();

    function setUp() public override {
        super.setUp();

        vm.startPrank(creator);
        pool.setTreasuryInterestWeight(10);
        pool.setTreasuryLiquidationWeight(80);
        //Set Tranche interestWeight on 0 so that all yield goes to treasury
        pool.addTranche(address(srTranche), 0, 0);
        pool.addTranche(address(jrTranche), 0, 20);
        pool.changeGuardian(creator);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);

        vm.startPrank(vaultOwner);
        vault = Vault(factory.createVault(1));
        vault.setTrustedCreditor(address(pool));
        vm.stopPrank();
    }

    function testRevert_setMaxInitiatorFee_Unauthorised(address unprivilegedAddress) public {
        // Given: unprivilegedAddress is not the Owner
        vm.assume(unprivilegedAddress != creator);

        // When: unprivilegedAddress sets the Liquidator
        // Then: setMaxInitiatorFee should revert with "UNAUTHORIZED"
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setMaxInitiatorFee(100);
        vm.stopPrank();
    }

    function testSuccess_setMaxInitiatorFee(uint80 maxFee) public {
        vm.prank(creator);
        vm.expectEmit(true, true, true, true);
        emit MaxInitiatorFeeSet(maxFee);
        pool.setMaxInitiatorFee(maxFee);

        assertEq(pool.maxInitiatorFee(), maxFee);
    }

    function testRevert_setFixedLiquidationCost_Unauthorised(address unprivilegedAddress, uint96 fixedLiquidationCost)
        public
    {
        // Given: unprivilegedAddress is not the Owner
        vm.assume(unprivilegedAddress != creator);

        // When: unprivilegedAddress sets the Liquidator
        // Then: setMaxInitiatorFee should revert with "UNAUTHORIZED"
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setFixedLiquidationCost(fixedLiquidationCost);
        vm.stopPrank();
    }

    function testSuccess_setFixedLiquidationCost(uint96 fixedLiquidationCost) public {
        vm.prank(creator);
        vm.expectEmit(true, true, true, true);
        emit FixedLiquidationCostSet(fixedLiquidationCost);
        pool.setFixedLiquidationCost(fixedLiquidationCost);

        assertEq(pool.fixedLiquidationCost(), fixedLiquidationCost);
    }

    function testRevert_liquidateVault_Paused(address liquidationInitiator, address vault_) public {
        // Given: The liquidator is set
        vm.warp(35 days);

        // And: pool is paused
        vm.prank(creator);
        pool.pause();

        // When: liquidationInitiator tries to liquidate the vault
        // Then: liquidateVault should revert with "LP_LV: Pool is paused"
        vm.expectRevert(FunctionIsPaused.selector);
        vm.prank(liquidationInitiator);
        pool.liquidateVault(vault_);
    }

    function testRevert_liquidateVault_NoDebt(address liquidationInitiator, address vault_) public {
        // Given: The liquidator is set
        // And: Vault has no debt

        // When: liquidationInitiator tries to liquidate the vault
        // Then: liquidateVault should revert with "LP_LV: Not a Vault with debt"
        vm.startPrank(liquidationInitiator);
        vm.expectRevert("LP_LV: Not a Vault with debt");
        pool.liquidateVault(vault_);
        vm.stopPrank();
    }

    function testSuccess_liquidateVault_NoOngoingAuctions(address liquidationInitiator, uint128 amountLoaned) public {
        // Given: all necessary contracts are deployed on the setup
        // And: The vault has debt
        vm.assume(amountLoaned > 0);
        vault.setTotalValue(amountLoaned);
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, liquidityProvider);
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), vaultOwner, emptyBytes3);

        // When: Liquidator calls liquidateVault
        vm.prank(liquidationInitiator);
        pool.liquidateVault(address(vault));

        // Then: liquidationInitiator should be set
        assertEq(pool.liquidationInitiator(address(vault)), liquidationInitiator);

        // Then: The debt of the vault should be decreased with amountLiquidated
        assertEq(debt.balanceOf(address(vault)), 0);
        assertEq(debt.totalSupply(), 0);

        // Then: auctionsInProgress should increase
        assertEq(pool.auctionsInProgress(), 1);
        // and the most junior tranche should be locked
        // ToDo: Check for emit
        assertTrue(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testSuccess_liquidateVault_WithOngoingAuctions(
        address liquidationInitiator,
        uint128 amountLoaned,
        uint16 auctionsInProgress
    ) public {
        // Given: all necessary contracts are deployed on the setup
        // And: The vault has debt
        vm.assume(amountLoaned > 0);
        vault.setTotalValue(amountLoaned);
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, liquidityProvider);
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), vaultOwner, emptyBytes3);

        //And: an auction is ongoing
        vm.assume(auctionsInProgress > 0);
        vm.assume(auctionsInProgress < type(uint16).max);
        pool.setAuctionsInProgress(auctionsInProgress);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator calls liquidateVault
        vm.prank(liquidationInitiator);
        pool.liquidateVault(address(vault));

        // Then: liquidationInitiator should be set
        assertEq(pool.liquidationInitiator(address(vault)), liquidationInitiator);

        // Then: The debt of the vault should be decreased with amountLiquidated
        assertEq(debt.balanceOf(address(vault)), 0);
        assertEq(debt.totalSupply(), 0);

        // Then: auctionsInProgress should increase
        assertEq(pool.auctionsInProgress(), auctionsInProgress + 1);
        // and the most junior tranche should be locked
        assertTrue(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testRevert_settleLiquidation_Unauthorised(
        uint128 badDebt,
        uint128 liquidationInitiatorReward,
        uint128 liquidationPenalty,
        uint128 remainder,
        address unprivilegedAddress_
    ) public {
        // Given: unprivilegedAddress is not the liquidator
        vm.assume(unprivilegedAddress_ != address(liquidator));

        // When: unprivilegedAddress settles a liquidation
        // Then: settleLiquidation should revert with "UNAUTHORIZED"
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("LP: Only liquidator");
        pool.settleLiquidation(
            address(vault), vaultOwner, badDebt, liquidationInitiatorReward, liquidationPenalty, remainder
        );
        vm.stopPrank();
    }

    function testSuccess_settleLiquidation_Surplus(
        uint128 liquidity,
        uint128 liquidationInitiatorReward,
        uint128 liquidationPenalty,
        uint128 remainder
    ) public {
        vm.assume(
            uint256(liquidity) + uint256(liquidationInitiatorReward) <= type(uint128).max - uint256(liquidationPenalty)
        );
        vm.assume(
            uint256(liquidity) + uint256(liquidationInitiatorReward) + uint256(liquidationPenalty)
                <= type(uint128).max - uint256(remainder)
        );

        vm.assume(liquidationInitiatorReward > 0);
        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);

        stdstore.target(address(pool)).sig(pool.liquidationInitiator.selector).with_key(address(vault)).checked_write(
            liquidationInitiatorAddr
        );

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(address(vault), vaultOwner, 0, liquidationInitiatorReward, liquidationPenalty, remainder);

        address initiator = pool.liquidationInitiator(address(vault));
        // round up
        uint256 liqPenaltyTreasury =
            uint256(liquidationPenalty) * pool.liquidationWeightTreasury() / pool.totalLiquidationWeight();
        if (
            uint256(liqPenaltyTreasury) * pool.totalLiquidationWeight()
                < uint256(liquidationPenalty) * pool.liquidationWeightTreasury()
        ) {
            liqPenaltyTreasury++;
        }

        uint256 liqPenaltyJunior =
            uint256(liquidationPenalty) * pool.liquidationWeightTranches(1) / pool.totalLiquidationWeight();
        if (
            uint256(liqPenaltyTreasury) * pool.totalLiquidationWeight()
                < uint256(liquidationPenalty) * pool.liquidationWeightTranches(1)
        ) {
            liqPenaltyTreasury--;
        }

        // Then: Initiator should be able to claim his rewards for liquidation initiation
        assertEq(pool.realisedLiquidityOf(initiator), liquidationInitiatorReward);
        // And: The liquidity amount from the most senior tranche should remain the same
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquidity);
        // And: The jr tranche will get its part of the liquidationpenalty
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), liqPenaltyJunior);
        // And: treasury will get its part of the liquidationpenalty
        assertEq(pool.realisedLiquidityOf(address(treasury)), liqPenaltyTreasury);
        // And: The remaindershould be claimable by the original owner
        assertEq(pool.realisedLiquidityOf(vaultOwner), remainder);
        // And: The total realised liquidity should be updated
        assertEq(pool.totalRealisedLiquidity(), liquidity + liquidationInitiatorReward + liquidationPenalty + remainder);

        //ToDo: check emit Tranche
        assertEq(pool.auctionsInProgress(), 0);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testSuccess_settleLiquidation_ProcessDefault(
        uint128 liquidity,
        uint128 badDebt,
        uint128 liquidationInitiatorReward,
        uint128 liquidationPenalty,
        uint128 remainder
    ) public {
        vm.assume(uint256(liquidity) + uint256(liquidationInitiatorReward) <= type(uint128).max + uint256(badDebt));
        // Given: provided liquidity is bigger than the default amount (Should always be true)
        vm.assume(liquidity >= badDebt);
        // And: badDebt is bigger than 0
        vm.assume(badDebt > 0);
        // And: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);

        stdstore.target(address(pool)).sig(pool.liquidationInitiator.selector).with_key(address(vault)).checked_write(
            liquidationInitiatorAddr
        );

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(
            address(vault), vaultOwner, badDebt, liquidationInitiatorReward, liquidationPenalty, remainder
        );

        // Then: Initiator should be able to claim his rewards for liquidation initiation
        address initiator = pool.liquidationInitiator(address(vault));
        assertEq(pool.realisedLiquidityOf(initiator), liquidationInitiatorReward);

        // And: The badDebt amount should be discounted from the most junior tranche
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquidity - badDebt);

        // And: The total realised liquidity should be updated
        assertEq(pool.totalRealisedLiquidity(), uint256(liquidity) + liquidationInitiatorReward - badDebt);
    }

    function testSuccess_settleLiquidation_MultipleAuctionsOngoing(uint128 liquidity, uint16 auctionsInProgress)
        public
    {
        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, liquidityProvider);

        // And multiple auctions are ongoing
        vm.assume(auctionsInProgress > 1);
        pool.setAuctionsInProgress(auctionsInProgress);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(address(vault), vaultOwner, 0, 0, 0, 0);

        //ToDo: check emit Tranche
        assertEq(pool.auctionsInProgress(), auctionsInProgress - 1);
        assertTrue(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testSuccess_settleLiquidation_ProcessDefaultNoTrancheWiped(
        uint128 liquiditySenior,
        uint128 liquidityJunior,
        uint128 badDebt
    ) public {
        // srTranche calls depositInLendingPool for liquiditySenior, jrTranche calls depositInLendingPool for liquidityJunior
        vm.assume(liquiditySenior <= type(uint128).max - liquidityJunior);
        uint256 totalAmount = uint256(liquiditySenior) + uint256(liquidityJunior);
        vm.assume(badDebt < liquidityJunior);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquiditySenior, liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidityJunior, liquidityProvider);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(address(vault), vaultOwner, badDebt, 0, 0, 0);

        // Then: realisedLiquidityOf for srTranche should be liquiditySenior, realisedLiquidityOf jrTranche should be liquidityJunior minus badDebt,
        // totalRealisedLiquidity should be equal to totalAmount minus badDebt
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquiditySenior);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), liquidityJunior - badDebt);
        assertEq(pool.totalRealisedLiquidity(), totalAmount - badDebt);
    }

    function testSuccess_settleLiquidation_ProcessDefaultOneTrancheWiped(
        uint128 liquiditySenior,
        uint128 liquidityJunior,
        uint128 badDebt,
        uint16 auctionsInProgress
    ) public {
        vm.assume(badDebt > 0);
        // Given: srTranche deposit liquiditySenior, jrTranche deposit liquidityJunior
        vm.assume(liquiditySenior <= type(uint128).max - liquidityJunior);
        uint256 totalAmount = uint256(liquiditySenior) + uint256(liquidityJunior);
        vm.assume(badDebt < totalAmount);
        vm.assume(badDebt >= liquidityJunior);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquiditySenior, liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidityJunior, liquidityProvider);

        // And multiple auctions are ongoing
        vm.assume(auctionsInProgress > 1);
        pool.setAuctionsInProgress(auctionsInProgress);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(address(vault), vaultOwner, badDebt, 0, 0, 0);

        // Then: supplyBalances srTranche should be totalAmount minus badDebt, supplyBalances jrTranche should be 0,
        // totalSupply should be equal to totalAmount minus badDebt, isTranche for jrTranche should return false
        assertEq(pool.realisedLiquidityOf(address(srTranche)), totalAmount - badDebt);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), 0);
        assertEq(pool.totalRealisedLiquidity(), totalAmount - badDebt);
        assertFalse(pool.isTranche(address(jrTranche)));

        //ToDo: check emits Tranche
        assertEq(pool.auctionsInProgress(), auctionsInProgress - 1);
        assertFalse(jrTranche.auctionInProgress());
        assertTrue(srTranche.auctionInProgress());
    }

    function testSuccess_settleLiquidation_ProcessDefaultAllTranchesWiped(
        uint128 liquiditySenior,
        uint128 liquidityJunior,
        uint16 auctionsInProgress
    ) public {
        // Given: srTranche deposit liquiditySenior, jrTranche deposit liquidityJunior
        vm.assume(liquiditySenior <= type(uint128).max - liquidityJunior);
        uint128 badDebt = liquiditySenior + liquidityJunior;
        vm.assume(badDebt > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquiditySenior, liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidityJunior, liquidityProvider);

        // And multiple auctions are ongoing
        vm.assume(auctionsInProgress > 1);
        pool.setAuctionsInProgress(auctionsInProgress);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(address(vault), vaultOwner, badDebt, 0, 0, 0);

        // Then: supplyBalances srTranche should be totalAmount minus badDebt, supplyBalances jrTranche should be 0,
        // totalSupply should be equal to totalAmount minus badDebt, isTranche for jrTranche should return false
        assertEq(pool.realisedLiquidityOf(address(srTranche)), 0);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), 0);
        assertEq(pool.totalRealisedLiquidity(), 0);
        assertFalse(pool.isTranche(address(jrTranche)));
        assertFalse(pool.isTranche(address(srTranche)));

        //ToDo: check emits Tranche
        assertEq(pool.auctionsInProgress(), auctionsInProgress - 1);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testRevert_settleLiquidation_ExcessBadDebt(
        uint128 liquiditySenior,
        uint128 liquidityJunior,
        uint128 badDebt
    ) public {
        // Given: badDebt, liquidityJunior and liquiditySenior bigger than 0,
        // srTranche calls depositInLendingPool for liquiditySenior, jrTranche calls depositInLendingPool for liquidityJunior
        // vm.assume(liquiditySenior <= type(uint256).max - liquidityJunior);
        uint256 totalAmount = uint256(liquiditySenior) + uint256(liquidityJunior);
        vm.assume(badDebt > totalAmount);
        vm.assume(badDebt > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquiditySenior, liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidityJunior, liquidityProvider);

        // When: Liquidator settles a liquidation
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(address(liquidator));
        pool.settleLiquidation(address(vault), vaultOwner, badDebt, 0, 0, 0);
    }

    function testSuccess_syncLiquidationFeeToLiquidityProviders(
        uint128 penalty,
        uint8 weightSr,
        uint8 weightJr,
        uint8 weightTreasury
    ) public {
        uint256 totalPenaltyWeight = uint256(weightSr) + uint256(weightJr) + uint256(weightTreasury);
        vm.assume(totalPenaltyWeight > 0);
        // Given: all necessary contracts are deployed on the setup
        vm.startPrank(creator);
        pool.setLiquidationWeight(0, weightSr);
        pool.setLiquidationWeight(1, weightJr);
        pool.setTreasuryLiquidationWeight(weightTreasury);
        vm.stopPrank();

        // When: creator syncLiquidationFeeToLiquidityProviders with penalty
        pool.syncLiquidationFeeToLiquidityProviders(penalty);

        // Then: supplyBalances srTranche, jrTranche and treasury should be correct
        // TotalSupply should be equal to penalty
        uint256 penaltySr = uint256(penalty) * weightSr / totalPenaltyWeight;
        uint256 penaltyJr = uint256(penalty) * weightJr / totalPenaltyWeight;
        uint256 penaltyTreasury = penalty - penaltySr - penaltyJr;

        assertEq(pool.realisedLiquidityOf(address(srTranche)), penaltySr);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), penaltyJr);
        assertEq(pool.realisedLiquidityOf(address(treasury)), penaltyTreasury);
    }
}

/* //////////////////////////////////////////////////////////////
                        VAULT LOGIC
////////////////////////////////////////////////////////////// */
contract VaultTest is LendingPoolTest {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
        vm.startPrank(creator);
        pool.setTreasuryInterestWeight(10);
        pool.setTreasuryLiquidationWeight(80);
        //Set Tranche interestWeight on 0 so that all yield goes to treasury
        pool.addTranche(address(srTranche), 50, 0);
        pool.addTranche(address(jrTranche), 40, 20);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(type(uint128).max, liquidityProvider);

        vm.startPrank(vaultOwner);
        vault = Vault(factory.createVault(1));
        vault.setTrustedCreditor(address(pool));
        vm.stopPrank();
    }

    function testRevert_setVaultVersion_NonOwner(address unprivilegedAddress, uint256 vaultVersion, bool valid)
        public
    {
        vm.assume(unprivilegedAddress != creator);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setVaultVersion(vaultVersion, valid);
        vm.stopPrank();
    }

    function testSuccess_setVaultVersion_setValid(uint256 vaultVersion) public {
        vm.startPrank(creator);
        vm.expectEmit(true, true, true, true);
        emit VaultVersionSet(vaultVersion, true);
        pool.setVaultVersion(vaultVersion, true);
        vm.stopPrank();

        assertTrue(pool.isValidVersion(vaultVersion));
    }

    function testSuccess_setVaultVersion_setInvalid(uint256 vaultVersion) public {
        vm.prank(creator);
        pool.setIsValidVersion(vaultVersion, true);

        vm.prank(creator);
        pool.setVaultVersion(vaultVersion, false);

        assertTrue(!pool.isValidVersion(vaultVersion));
    }

    function testSuccess_openMarginAccount_InvalidVaultVersion(uint256 vaultVersion, uint96 fixedLiquidationCost)
        public
    {
        // Given: vaultVersion is invalid
        vm.startPrank(creator);
        pool.setVaultVersion(vaultVersion, false);
        pool.setFixedLiquidationCost(fixedLiquidationCost);
        vm.stopPrank();

        // When: vault opens a margin account
        (bool success, address baseCurrency, address liquidator_, uint256 fixedLiquidationCost_) =
            pool.openMarginAccount(vaultVersion);

        // Then: openMarginAccount should return success and correct contract addresses
        assertTrue(!success);
        assertEq(address(0), baseCurrency);
        assertEq(address(0), liquidator_);
        assertEq(0, fixedLiquidationCost_);
    }

    function testSuccess_openMarginAccount_ValidVaultVersion(uint256 vaultVersion, uint96 fixedLiquidationCost)
        public
    {
        // Given: vaultVersion is valid
        vm.startPrank(creator);
        pool.setVaultVersion(vaultVersion, true);
        pool.setFixedLiquidationCost(fixedLiquidationCost);
        vm.stopPrank();

        // When: vault opens a margin account
        (bool success, address baseCurrency, address liquidator_, uint256 fixedLiquidationCost_) =
            pool.openMarginAccount(vaultVersion);

        // Then: openMarginAccount should return success and correct contract addresses
        assertTrue(success);
        assertEq(address(asset), baseCurrency);
        assertEq(address(liquidator), liquidator_);
        assertEq(fixedLiquidationCost, fixedLiquidationCost_);
    }

    function testSuccess_getOpenPosition(uint128 amountLoaned) public {
        // Given: a vault has taken out debt
        vm.assume(amountLoaned > 0);
        vault.setTotalValue(amountLoaned);
        vm.prank(vaultOwner);
        pool.borrow(amountLoaned, address(vault), vaultOwner, emptyBytes3);

        // When: The vault fetches its open position
        uint256 openPosition = pool.getOpenPosition(address(vault));

        // Then: The open position should equal the amount loaned
        assertEq(amountLoaned, openPosition);
    }
}

/* //////////////////////////////////////////////////////////////
                        GUARDIAN LOGIC
////////////////////////////////////////////////////////////// */
contract GuardianTest is LendingPoolTest {
    using stdStorage for StdStorage;

    address pauseGuardian = address(17);

    error FunctionIsPaused();

    function setUp() public override {
        super.setUp();

        // Set Guardian
        vm.startPrank(creator);
        pool.changeGuardian(pauseGuardian);
        vm.stopPrank();

        // Warp the block timestamp to 60days for smooth testing
        vm.warp(60 days);
    }

    function testRevert_depositInLendingPool_Paused() public {
        // Given: all necessary contracts are deployed on the setup
        assertEq(pool.guardian(), pauseGuardian);

        // When: the guardian pauses the pool
        vm.prank(pauseGuardian);
        pool.pause();

        // Then: the pool should be paused
        assertTrue(pool.depositPaused());
        // And: the pool should not be able to deposit
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        vm.expectRevert(FunctionIsPaused.selector);
        pool.depositInLendingPool(type(uint128).max, liquidityProvider);
    }

    function testRevert_borrow_Paused() public {
        // Given: all necessary contracts are deployed on the setup
        assertEq(pool.guardian(), pauseGuardian);

        // When: the guardian pauses the pool
        vm.prank(pauseGuardian);
        pool.pause();

        // Then: the pool should be paused
        assertTrue(pool.borrowPaused());
        vm.startPrank(vaultOwner);
        // And: the pool should not be able to borrow
        vm.expectRevert(FunctionIsPaused.selector);
        pool.borrow(uint256(20 * 10 ** 18), address(vault), address(412), emptyBytes3);
        vm.stopPrank();
    }

    function testRevert_withdrawFromLendingPool_Paused() public {
        // Given: all necessary contracts are deployed on the setup
        assertEq(pool.guardian(), pauseGuardian);

        // When: the guardian pauses the pool
        vm.prank(pauseGuardian);
        pool.pause();

        // Then: the pool should be paused
        assertTrue(pool.withdrawPaused());
        vm.startPrank(address(srTranche));
        // And: the pool should not be able to borrow
        vm.expectRevert(FunctionIsPaused.selector);
        pool.withdrawFromLendingPool(uint128(20 * 10 ** 18), address(42));
        vm.stopPrank();
    }

    function testRevert_liquidateVault_Paused() public {
        // Given: all necessary contracts are deployed on the setup
        assertEq(pool.guardian(), pauseGuardian);

        // When: the guardian pauses the pool
        vm.prank(pauseGuardian);
        pool.pause();

        // Then: the pool should be paused
        assertTrue(pool.liquidationPaused());
        // And: the pool should not be able to borrow
        vm.expectRevert(FunctionIsPaused.selector);
        pool.liquidateVault(address(vault));
    }

    function testRevert_repay_Paused() public {
        // Given: all necessary contracts are deployed on the setup
        assertEq(pool.guardian(), pauseGuardian);

        // When: the guardian pauses the pool
        vm.prank(pauseGuardian);
        pool.pause();

        // Then: the pool should be paused
        assertTrue(pool.repayPaused());
        vm.startPrank(vaultOwner);
        asset.approve(address(pool), type(uint256).max);
        // And: the pool should not be able to borrow
        vm.expectRevert(FunctionIsPaused.selector);
        pool.repay(uint128(20 * 10 ** 18), address(42));
        vm.stopPrank();
    }

    function testSuccess_withdraw_OwnerUnpausesDepositAndWithdrawOnly(uint256 timePassed) public {
        // Preprocess: set fuzzing limits
        vm.assume(timePassed < 30 days);
        vm.assume(timePassed > 0);

        // Given: all necessary contracts are deployed on the setup
        assertEq(pool.guardian(), pauseGuardian);

        // And: Tranches are added
        vm.startPrank(creator);
        pool.addTranche(address(srTranche), 50, 0);
        pool.addTranche(address(jrTranche), 40, 20);
        vm.stopPrank();

        // And: the guardian pauses the pool
        vm.prank(pauseGuardian);
        pool.pause();

        // And: and time passes
        vm.warp(block.timestamp + timePassed);

        // When: the owner unpauses the pool, only withdraw and deposit
        vm.prank(creator);
        pool.unPause(true, false, true, false, true);

        // Then: the variables should be set correctly
        assertTrue(!pool.depositPaused());
        assertTrue(pool.borrowPaused());
        assertTrue(!pool.withdrawPaused());
        assertTrue(pool.repayPaused());

        // And: the pool should not be able to repay
        vm.expectRevert(FunctionIsPaused.selector);
        pool.repay(uint128(20 * 10 ** 18), address(42));

        // And: the pool should be able to deposit and withdraw
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.startPrank(address(srTranche));
        pool.depositInLendingPool(uint128(20 * 10 ** 18), liquidityProvider);

        pool.withdrawFromLendingPool(uint128(19 * 10 ** 18), address(412));
        vm.stopPrank();
    }

    function testSuccess_withdraw_UserUnpauses(uint64 deltaTimePassed, address randomUser) public {
        // Preprocess: set fuzzing limits
        uint256 timePassed = 30 days + 1;
        vm.assume(deltaTimePassed < 30 days);
        timePassed = timePassed + uint256(deltaTimePassed);
        vm.assume(randomUser != address(0));
        vm.assume(randomUser != creator);
        vm.assume(randomUser != pauseGuardian);

        // Given: all necessary contracts are deployed on the setup
        assertEq(pool.guardian(), pauseGuardian);

        // And: Tranches are added
        vm.startPrank(creator);
        pool.addTranche(address(srTranche), 50, 0);
        pool.addTranche(address(jrTranche), 40, 20);
        vm.stopPrank();

        // And: the guardian pauses the pool
        vm.prank(pauseGuardian);
        pool.pause();

        // And: and time passes
        vm.warp(block.timestamp + timePassed);

        // When: the randomUser unpauses the pool
        vm.prank(randomUser);
        pool.unPause();

        // Then: the variables should be set correctly
        assertTrue(!pool.depositPaused());
        assertTrue(!pool.borrowPaused());
        assertTrue(!pool.withdrawPaused());
        assertTrue(!pool.repayPaused());

        // And: the pool should be able to deposit and withdraw
        vm.prank(liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
        vm.startPrank(address(srTranche));
        pool.depositInLendingPool(uint128(20 * 10 ** 18), liquidityProvider);

        pool.withdrawFromLendingPool(uint128(19 * 10 ** 18), address(412));
        vm.stopPrank();
    }
}
