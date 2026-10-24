/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

import { IEmissionsHandler } from "../interfaces/IEmissionsHandler.sol";
import { ILeafMessageOrchestrator } from "../interfaces/ILeafMessageOrchestrator.sol";
import { ILeafVoter } from "../interfaces/ILeafVoter.sol";
import { IMinter } from "../interfaces/IMinter.sol";
import { IRootLocalAdapter } from "../interfaces/IRootLocalAdapter.sol";
import { IRootMessageOrchestrator } from "../interfaces/IRootMessageOrchestrator.sol";
import { IVoter } from "../interfaces/IVoter.sol";

/**
 * @title Metadex03 Emissions
 * @author Pragma Labs
 * @notice Resolves how a Metadex03 chain pays out emissions.
 */
library Emissions {
    error HandlerNotValid();

    /**
     * @notice Resolves how the chain's emissions handler pays out.
     * @param leafVoter The contract address of the Metadex03 LeafVoter.
     * @return token The contract address of the Reward Token.
     * @return isRoot Bool indicating if the handler redeems the ReceiptToken for the Token.
     * @return handler The contract address of the emissions handler.
     */
    function resolve(address leafVoter) internal view returns (address token, bool isRoot, address handler) {
        handler = ILeafVoter(leafVoter).EMISSIONS_HANDLER();

        (bool success, bytes memory result) =
            handler.staticcall(abi.encodeWithSelector(IEmissionsHandler.RECEIPT_TOKEN.selector));

        // Only an answerless revert is the root handler.
        // forge-lint: disable-next-item(boolean-cst)
        if (success && result.length == 32) return (abi.decode(result, (address)), false, handler);
        if (success || result.length > 0) revert HandlerNotValid();

        address adapter = ILeafMessageOrchestrator(ILeafVoter(leafVoter).ORCHESTRATOR()).adapter();
        address voter = IRootMessageOrchestrator(IRootLocalAdapter(adapter).ROOT_MESSAGE_ORCHESTRATOR()).VOTER();
        token = IMinter(IVoter(voter).MINTER()).TOKEN();
        isRoot = true;
    }

    /**
     * @notice Returns if a claim delivers the reward token now.
     * @param leafVoter The contract address of the Metadex03 LeafVoter.
     * @return mintable Bool indicating if the chain can mint emissions.
     */
    function isMintable(address leafVoter) internal view returns (bool mintable) {
        ILeafVoter.ChainStatus status = ILeafVoter(leafVoter).chainStatus();
        mintable = status == ILeafVoter.ChainStatus.Active || status == ILeafVoter.ChainStatus.Sunset;
    }
}
