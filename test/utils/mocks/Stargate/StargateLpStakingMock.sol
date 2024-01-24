/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

// interfaces
import { IERC20 } from "../../../../src/interfaces/IERC20.sol";

contract LPStakingTimeMock {
    IERC20 public eToken = IERC20(0xE3B53AF74a4BF62Ae5511055290838050bf764Df);

    mapping(uint256 poolId => PoolInfo) public poolInfo;

    struct PoolInfo {
        IERC20 lpToken;
        uint256 pendingEmissionsToken;
        uint256 allocPoint;
        uint256 lastRewardTime;
    }

    function setInfoForPoolId(uint256 poolId, uint256 pendingEmissionsToken_, address lpToken_) public {
        poolInfo[poolId] = PoolInfo({
            pendingEmissionsToken: pendingEmissionsToken_,
            lpToken: IERC20(lpToken_),
            allocPoint: 0,
            lastRewardTime: 0
        });
    }

    function pendingEmissionToken(uint256 pid, address) external view returns (uint256 pending) {
        pending = poolInfo[pid].pendingEmissionsToken;
    }

    function setEToken(address eToken_) public {
        eToken = IERC20(eToken_);
    }

    function deposit(uint256 poolId, uint256 amount) external {
        poolInfo[poolId].lpToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 poolId, uint256 amount) external {
        poolInfo[poolId].lpToken.transfer(msg.sender, amount);
    }
}
