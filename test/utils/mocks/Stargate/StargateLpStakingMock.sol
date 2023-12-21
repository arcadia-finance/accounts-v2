/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

// interfaces
import { IERC20 } from "../../../../src/interfaces/IERC20.sol";

contract LPStakingTimeMock {
    IERC20 public eToken;

    mapping(uint256 poolId => PoolInfo) public poolIdToPoolInfo;

    struct PoolInfo {
        uint256 pendingEmissionsToken;
        IERC20 lpToken;
    }

    function setInfoForPoolId(uint256 poolId, uint256 pendingEmissionsToken_, address lpToken_) public {
        poolIdToPoolInfo[poolId] =
            PoolInfo({ pendingEmissionsToken: pendingEmissionsToken_, lpToken: IERC20(lpToken_) });
    }

    function pendingEmissionToken(uint256 pid, address) external view returns (uint256 pending) {
        pending = poolIdToPoolInfo[pid].pendingEmissionsToken;
    }

    function setEToken(address eToken_) public {
        eToken = IERC20(eToken_);
    }

    function deposit(uint256 poolId, uint256 amount) external {
        poolIdToPoolInfo[poolId].lpToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 poolId, uint256 amount) external {
        poolIdToPoolInfo[poolId].lpToken.transfer(msg.sender, amount);
    }
}
