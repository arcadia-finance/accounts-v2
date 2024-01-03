/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

contract SequencerUptimeOracle {
    bool internal reverts;

    int256 internal answer;
    uint256 internal startedAt;

    function latestRoundData() public view returns (uint80, int256, uint256, uint256, uint80) {
        if (reverts) revert();
        return (0, answer, startedAt, 0, 0);
    }

    function setLatestRoundData(int256 answer_, uint256 startedAt_) public {
        answer = answer_;
        startedAt = startedAt_;
    }

    function setRevertsFlag(bool reverts_) public {
        reverts = reverts_;
    }
}
