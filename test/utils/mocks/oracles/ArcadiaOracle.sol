/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Owned } from "../../../../lib/solmate/src/auth/Owned.sol";

contract ArcadiaOracle is Owned {
    // Configs
    uint8 public decimals;
    string public description;

    uint8 private latestRoundId;

    // Transmission records the median answer from the transmit transaction at
    // time timestamp
    struct Transmission {
        int256 answer;
        uint64 timestamp;
    }

    mapping(uint32 => Transmission) /* aggregator round ID */ internal transmissions;

    enum Role {
        Unset, // unset
        Transmitter, // Offchain data transmissions to the oracle
        Validator // Offchain data validator for the setted values

    }

    struct OffchainConnector {
        Role role; // role of the connector
        bool isActive; // is the connector still active
    }

    mapping(address => OffchainConnector) internal offchainConnectors;

    constructor(uint8 _decimals, string memory _description) Owned(msg.sender) {
        decimals = _decimals;
        description = _description;
        latestRoundId = 0;
    }

    /**
     * @notice setOffchainTransmitter set the offchain transmitter to transmit new data, multiple transmitter is possible,
     * @param _transmitter address of the transmitter
     */
    function setOffchainTransmitter(address _transmitter) public onlyOwner {
        require(
            offchainConnectors[_transmitter].role != Role.Transmitter,
            "Oracle: Address is already saved as Transmitter!"
        );
        offchainConnectors[_transmitter] = OffchainConnector({ isActive: true, role: Role.Transmitter });
    }

    /**
     * @notice deactivateTransmitter set the offchain transmitter state to deactive
     * @param _transmitter address of the transmitter
     */
    function deactivateTransmitter(address _transmitter) public onlyOwner {
        require(offchainConnectors[_transmitter].role == Role.Transmitter, "Oracle: Address is not Transmitter!");
        offchainConnectors[_transmitter].isActive = false;
    }

    /**
     * @dev Throws if called by any account other than the transmitter.
     */
    modifier onlyTransmitter() {
        require(offchainConnectors[msg.sender].role == Role.Transmitter, "Oracle: caller is not the valid transmitter");
        require(offchainConnectors[msg.sender].isActive, "Oracle: transmitter is not active");
        _;
    }

    /**
     * @notice transmit is called to post a new report to the contract
     * @param _answer the new price data for the round
     */
    function transmit(int256 _answer) public onlyTransmitter {
        unchecked {
            latestRoundId++;
        }
        transmissions[latestRoundId] = Transmission(_answer, uint64(block.timestamp));
    }

    /**
     * @notice oracle answer for latest rounddata
     * @return roundId aggregator round of latest report
     * @return answer latest report
     * @return startedAt timestamp of block containing latest report
     * @return updatedAt timestamp of block containing latest report
     * @return answeredInRound aggregator round of latest report
     */
    function latestRoundData()
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = latestRoundId;
        require(roundId != 0, "Oracle: No data present!");

        return (
            roundId,
            transmissions[uint32(roundId)].answer,
            transmissions[uint32(roundId)].timestamp,
            transmissions[uint32(roundId)].timestamp,
            roundId
        );
    }

    function aggregator() public view returns (address) {
        return address(this);
    }

    int192 public minAnswer = 100;
    int192 public maxAnswer = type(int192).max - 100;

    function setMinAnswer(int192 minAnswer_) public {
        minAnswer = minAnswer_;
    }

    function setMaxAnswer(int192 maxAnswer_) public {
        maxAnswer = maxAnswer_;
    }

    function setLatestRoundId(uint8 roundId_) public {
        latestRoundId = roundId_;
    }
}
