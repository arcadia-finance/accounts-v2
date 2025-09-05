/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

/**
 * @title Module to build the data object of a Safe transaction.
 * @author Pragma Labs
 * @notice Based on https://github.com/ind-igo/forge-safe (MIT).
 */
abstract contract SafeTransactionBuilder {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    string internal constant PATH = "./script/out/output.txt";
    mapping(address safe => bytes[] txs) internal encodedTxs;

    enum Operation {
        CALL,
        DELEGATECALL
    }

    /* //////////////////////////////////////////////////////////////
                                LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Adds an encoded transaction to the batch.
     * @param safe The contract address of the Safe that will send the transactions.
     * @param operation The type of transaction, "0" for a call, "1" for a delegatecall.
     * @param to The address of the contract to call.
     * @param value The msg.value.
     * @param calldata_ The calldata.
     */
    function addToBatch(address safe, Operation operation, address to, uint256 value, bytes memory calldata_) public {
        encodedTxs[safe].push(abi.encodePacked(operation, to, value, calldata_.length, calldata_));
    }

    /**
     * @notice Adds an encoded transaction to the batch.
     * @param safe The contract address of the Safe that will send the transactions.
     * @param to The address of the contract to call.
     * @param calldata_ The calldata.
     * @dev We only use calls no delegatecall and msg.value is always 0.
     */
    function addToBatch(address safe, address to, bytes memory calldata_) public {
        addToBatch(safe, Operation.CALL, to, uint256(0), calldata_);
    }

    /**
     * @notice Encodes the data for a Safe Multidata.
     * @param safe The contract address of the Safe that will send the transactions.
     * @return data The encoded data.
     */
    function createBatchedData(address safe) public view returns (bytes memory data) {
        bytes[] memory encodedTxs_ = encodedTxs[safe];
        uint256 length = encodedTxs_.length;
        for (uint256 i; i < length; ++i) {
            data = bytes.concat(data, encodedTxs_[i]);
        }
        data = abi.encodeWithSignature("multiSend(bytes)", data);
    }
}
