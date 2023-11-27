/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20, SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";

abstract contract StakingModule {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    ERC20 public immutable stakingToken;
    ERC20 public immutable rewardsToken;

    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    uint256 private _totalSupply;

    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) public userRewardPerTokenPaid;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AmountIsZero();

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor(ERC20 stakingToken_, ERC20 rewardsToken_) {
        stakingToken = stakingToken_;
        rewardsToken = rewardsToken_;
    }

    /*///////////////////////////////////////////////////////////////
                        STAKING TOKEN INFORMATION
    ///////////////////////////////////////////////////////////////*/

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    // Note: add nonReentrant and notPaused? modifiers
    // Note: See who can call this function
    function stake(uint256 amount, address account) external updateReward(account) {
        if (amount == 0) revert AmountIsZero();

        _totalSupply += amount;
        _balances[msg.sender] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Internal function to stake in protocol
        _stake(amount);

        emit Staked(msg.sender, amount);
    }

    function _stake(uint256 amount) internal virtual;

    // Note: add nonReentrant modifier
    // Note: see who can call this function
    function withdraw(uint256 amount, address account) external updateReward(account) {
        if (amount == 0) revert AmountIsZero();

        _totalSupply -= amount;
        _balances[msg.sender] -= amount;

        // Internal function to claim from protocol
        _withdraw(amount);

        emit Withdrawn(msg.sender, amount);
    }

    function _withdraw(uint256 amount) internal virtual;

    function rewardPerToken() public view returns (uint256 rewardPerToken_) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        // Calc total earned amount of this contract as of now minus last time = earned over period.
        uint256 earnedSinceLastUpdate;
        rewardPerToken_ = rewardPerTokenStored + earnedSinceLastUpdate.mulDivDown(1e18, _totalSupply);
    }

    // Note: see if we can optimize rewardPerToken here, as we calculate it in modifier previously.
    function earned(address account) public view returns (uint256 earned_) {
        uint256 rewardPerTokenClaimable = rewardPerToken() - userRewardPerTokenPaid[account];
        earned_ = rewards[account] + _balances[account].mulDivDown(rewardPerTokenClaimable, 1e18);
    }
}
