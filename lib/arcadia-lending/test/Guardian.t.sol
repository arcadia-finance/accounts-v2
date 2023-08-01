/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import { Guardian } from "../src/security/Guardian.sol";

contract LendingPoolMockup is Guardian {
    uint256 public totalSupply;
    uint256 public totalBorrow;

    function depositGuarded(uint256 supply) external whenDepositNotPaused {
        totalSupply += supply;
    }

    function borrowUnguarded(uint256 borrow) external {
        totalBorrow += borrow;
    }

    function borrowGuarded(uint256 borrow) external whenBorrowNotPaused {
        totalBorrow += borrow;
    }

    function reset() external onlyOwner {
        totalSupply = 0;
        totalBorrow = 0;
    }

    function resetPauseVars() external onlyOwner {
        borrowPaused = false;
        depositPaused = false;
        repayPaused = false;
        withdrawPaused = false;
        liquidationPaused = false;
    }
}

contract GuardianUnitTest is Test {
    using stdStorage for StdStorage;

    LendingPoolMockup lendingPool;
    address guardian = address(1);
    address owner = address(2);

    event GuardianChanged(address indexed oldGuardian, address indexed newGuardian);
    event PauseUpdate(
        bool repayPauseUpdate,
        bool withdrawPauseUpdate,
        bool borrowPauseUpdate,
        bool supplyPauseUpdate,
        bool liquidationPauseUpdate
    );

    error FunctionIsPaused();

    constructor() {
        vm.startPrank(owner);
        lendingPool = new LendingPoolMockup();
        lendingPool.changeGuardian(guardian);
        vm.stopPrank();
    }

    function setUp() public virtual {
        // Reset the lending pool variables
        vm.startPrank(owner);
        lendingPool.reset();
        lendingPool.resetPauseVars();
        vm.stopPrank();
        // Reset: the lending pool pauseTimestamp
        stdstore.target(address(lendingPool)).sig(lendingPool.pauseTimestamp.selector).checked_write(uint256(0));
        // Warp the block timestamp to 60days for smooth testing
        vm.warp(60 days);
    }

    function testRevert_changeGuardian_onlyOwner(address nonOwner_) public {
        // Given: the lending pool owner is owner
        vm.assume(nonOwner_ != owner);
        vm.startPrank(nonOwner_);
        // When: a non-owner tries to change the guardian, it is reverted
        vm.expectRevert("UNAUTHORIZED");
        lendingPool.changeGuardian(guardian);
        vm.stopPrank();
        // Then: the guardian is not changed
        assertEq(lendingPool.guardian(), guardian);
    }

    function testSuccess_changeGuardian(address newGuardian_) public {
        // Preprocess: set the new guardian
        vm.assume(newGuardian_ != address(0));
        vm.assume(newGuardian_ != guardian);
        vm.assume(newGuardian_ != owner);
        // Given: the lending pool owner is owner
        vm.startPrank(owner);

        // When: the owner changes the guardian
        vm.expectEmit(true, true, true, false);
        emit GuardianChanged(guardian, newGuardian_);
        lendingPool.changeGuardian(newGuardian_);
        vm.stopPrank();
        // Then: the guardian is changed
        assertEq(lendingPool.guardian(), newGuardian_);

        // When: The owner changes the guardian back to the original guardian
        vm.startPrank(owner);
        lendingPool.changeGuardian(guardian);
        vm.stopPrank();

        // Then: the guardian is changed
        assertEq(lendingPool.guardian(), guardian);
    }

    function testRevert_pause_onlyGuard(address pauseCaller) public {
        vm.assume(pauseCaller != guardian);
        // Given When Then: the lending pool is not paused
        vm.expectRevert("Guardian: Only guardian");
        vm.startPrank(pauseCaller);
        lendingPool.pause();
        vm.stopPrank();
    }

    function testRevert_pause_timeNotExpired(uint256 timePassedAfterPause) public {
        vm.assume(timePassedAfterPause < 32 days);

        // Given: the lending pool is paused
        vm.startPrank(guardian);
        lendingPool.pause();
        vm.stopPrank();

        // Given: 1 day passed
        uint256 startTimestamp = block.timestamp;
        vm.warp(startTimestamp + 1 days);

        // When: the owner unPauses
        vm.startPrank(owner);
        lendingPool.unPause(false, false, false, false, false);
        vm.stopPrank();

        // Then: the guardian cannot pause again until 32 days passed from the first pause
        vm.warp(startTimestamp + timePassedAfterPause);
        vm.expectRevert("G_P: Cannot pause");
        vm.startPrank(guardian);
        lendingPool.pause();
        vm.stopPrank();
    }

    function testRevert_pause_guardianCannotPauseAgainBetween30and32Days(uint8 deltaTimePassedAfterPause) public {
        // Preprocess: the delta time passed after pause is between 30 and 32 days
        vm.assume(deltaTimePassedAfterPause <= 2 days);
        uint256 timePassedAfterPause = 30 days + deltaTimePassedAfterPause;

        // Given: the lending pool is paused
        vm.startPrank(guardian);
        lendingPool.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        // When: the guardian tries pause
        vm.startPrank(guardian);
        // Then: the guardian cannot pause again until 32 days passed from the first pause
        vm.expectRevert("G_P: Cannot pause");
        lendingPool.pause();
        vm.stopPrank();
    }

    function testSuccess_pause_guardianCanPauseAgainAfter32days(uint32 timePassedAfterPause, address user) public {
        // Preprocess: the delta time passed after pause is between 30 and 32 days
        vm.assume(timePassedAfterPause > 32 days);
        vm.assume(user != address(0));
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the lending pool is paused
        vm.startPrank(guardian);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, true, true, true, true);
        lendingPool.pause();
        vm.stopPrank();

        uint256 startTimestamp = block.timestamp;
        // Given: 30 days passed after the pause and user unpauses
        vm.warp(startTimestamp + 30 days + 1);
        vm.startPrank(user);
        lendingPool.unPause();
        vm.stopPrank();

        // Given: Sometime passed after the initial pause
        vm.warp(startTimestamp + timePassedAfterPause);

        // When: the guardian unPause
        vm.startPrank(guardian);
        // Then: the guardian can pause again because time passed
        lendingPool.pause();
        vm.stopPrank();
    }

    function testRevert_unPause_userCannotUnPauseBefore30Days(uint256 timePassedAfterPause, address user) public {
        vm.assume(timePassedAfterPause < 30 days);
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the lending pool is paused
        vm.startPrank(guardian);
        lendingPool.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        // When: the user tries to unPause
        vm.expectRevert("G_UP: Cannot unPause");
        vm.startPrank(user);
        lendingPool.unPause();
        vm.stopPrank();
    }

    function testSuccess_unPause_userCanUnPauseAfter30Days(uint256 deltaTimePassedAfterPause, address user) public {
        // Preprocess: the delta time passed after pause is at least 30 days
        vm.assume(deltaTimePassedAfterPause <= 120 days);
        vm.assume(deltaTimePassedAfterPause > 0);
        uint256 timePassedAfterPause = 30 days + deltaTimePassedAfterPause;
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the lending pool is paused
        vm.startPrank(guardian);
        lendingPool.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        // When: the user unPause
        vm.startPrank(user);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(false, false, false, false, false);
        lendingPool.unPause();
        vm.stopPrank();

        // Then: the user can supply
        vm.startPrank(user);
        lendingPool.depositGuarded(100);
        vm.stopPrank();
        assertEq(lendingPool.totalSupply(), 100);
    }

    function testSuccess_unPause_ownerCanUnPauseDuring30Days(uint256 timePassedAfterPause, address user) public {
        vm.assume(timePassedAfterPause <= 30 days);
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the lending pool is paused
        vm.startPrank(guardian);
        lendingPool.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        // When: the owner unPauses the supply
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, true, true, false, true);
        lendingPool.unPause(true, true, true, false, true);
        vm.stopPrank();

        // Then: the user can supply
        vm.startPrank(user);
        lendingPool.depositGuarded(100);
        vm.stopPrank();

        // Then: the total supply is updated
        assertEq(lendingPool.totalSupply(), 100);
    }

    function testSuccess_unPause_onlyUnpausePossible(uint256 timePassedAfterPause, address user) public {
        vm.assume(timePassedAfterPause <= 30 days);
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the lending pool is paused
        vm.startPrank(guardian);
        lendingPool.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        // When: the owner unPauses the supply
        vm.startPrank(owner);
        lendingPool.unPause(true, true, true, false, true);
        vm.stopPrank();

        // When: the owner attempts the pause the supply from the unPause
        vm.startPrank(owner);
        lendingPool.unPause(true, true, true, true, true);
        vm.stopPrank();

        // Then: the user can still supply because the once the supply is unPaused, it cannot be paused
        vm.startPrank(user);
        lendingPool.depositGuarded(100);
        vm.stopPrank();

        // Then: the total supply is updated
        assertEq(lendingPool.totalSupply(), 100);
    }

    function testSuccess_unPause_onlyToggleToUnpause(
        uint32 timePassedAfterPause,
        bool repayPaused,
        bool withdrawPaused,
        bool borrowPaused,
        bool depositPaused,
        bool liquidationPaused
    ) public {
        // Preprocess:
        vm.assume(timePassedAfterPause <= 365 days);

        // Given: the lending pool is paused
        vm.startPrank(guardian);
        lendingPool.pause();
        vm.stopPrank();

        // Given: Sometime passed after the pause
        vm.warp(block.timestamp + timePassedAfterPause);

        bool previousRepayPaused = lendingPool.repayPaused();
        bool previousWithdrawPaused = lendingPool.withdrawPaused();
        bool previousBorrowPaused = lendingPool.borrowPaused();
        bool previousDepositPaused = lendingPool.depositPaused();
        bool previousLiquidationPaused = lendingPool.liquidationPaused();

        // When: the owner unPauses the supply
        vm.startPrank(owner);
        lendingPool.unPause(repayPaused, withdrawPaused, borrowPaused, depositPaused, liquidationPaused);
        vm.stopPrank();

        // Then: the pause variables in the contract should be turned into false if the incoming data is false.
        // True does not change the state
        assertEq(lendingPool.repayPaused(), repayPaused && previousRepayPaused);
        assertEq(lendingPool.withdrawPaused(), withdrawPaused && previousWithdrawPaused);
        assertEq(lendingPool.borrowPaused(), borrowPaused && previousBorrowPaused);
        assertEq(lendingPool.depositPaused(), depositPaused && previousDepositPaused);
        assertEq(lendingPool.liquidationPaused(), liquidationPaused && previousLiquidationPaused);
    }

    function testRevert_depositGuarded_paused(address user) public {
        vm.assume(user != owner);
        vm.assume(user != guardian);
        // Given: the lending pool supply is paused, only supply paused
        vm.startPrank(guardian);
        lendingPool.pause();
        vm.stopPrank();

        // When Then: a user tries to supply, it is reverted as paused
        vm.expectRevert(FunctionIsPaused.selector);
        vm.startPrank(user);
        lendingPool.depositGuarded(100);
        vm.stopPrank();

        // Then: the total supply is not updated
        assertEq(lendingPool.totalSupply(), 0);

        // When: owner can unPauses the borrow
        vm.startPrank(owner);
        lendingPool.unPause(true, true, false, true, true);
        vm.stopPrank();

        // Then: user tries to borrow, which is not paused
        vm.startPrank(user);
        lendingPool.borrowGuarded(100);
        vm.stopPrank();

        // Then: the total borrow is updated
        assertEq(lendingPool.totalBorrow(), 100);
    }

    function testSuccess_depositGuarded_notPause(address user) public {
        // Preprocess: set the user
        vm.assume(user != address(0));
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the lending pool is not paused
        vm.startPrank(user);
        // When: a user supplies
        lendingPool.depositGuarded(100);
        vm.stopPrank();
        // Then: the total supply is updated
        assertEq(lendingPool.totalSupply(), 100);
    }

    function testRevert_borrowGuarded_paused(address user) public {
        // Preprocess: set the user
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the lending pool is paused
        vm.startPrank(guardian);
        lendingPool.pause();
        vm.stopPrank();

        // Given: only borrow left paused
        vm.startPrank(owner);
        lendingPool.unPause(false, false, true, false, false);
        vm.stopPrank();

        // When: a user tries to supply
        vm.startPrank(user);
        lendingPool.depositGuarded(100);
        vm.stopPrank();

        // Then: the total supply is updated
        assertEq(lendingPool.totalSupply(), 100);

        // When: user tries to borrow, which is paused
        vm.expectRevert(FunctionIsPaused.selector);
        vm.startPrank(user);
        lendingPool.borrowGuarded(100);
        vm.stopPrank();

        // Then: the total borrow is not updated
        assertEq(lendingPool.totalBorrow(), 0);
    }

    function testSuccess_borrowUnguarded_notPaused(address user) public {
        // Preprocess: set the user
        vm.assume(user != owner);
        vm.assume(user != guardian);

        // Given: the lending pool is paused
        vm.startPrank(guardian);
        lendingPool.pause();
        vm.stopPrank();

        // When: a user borrows from unguarded function
        vm.startPrank(user);
        lendingPool.borrowUnguarded(100);
        vm.stopPrank();

        // Then: the total borrow is updated
        assertEq(lendingPool.totalBorrow(), 100);
    }
}
