/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.34;

/**
 * @title Library for creating Arcadia Proxy Contracts
 * @author Pragma Labs
 */
library CreateProxyLib {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The bytecode of the Proxy contract.
    bytes internal constant PROXY_BYTECODE =
        hex"608060405260405161017c38038061017c8339810160408190526100229161008d565b7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc80546001600160a01b0319166001600160a01b0383169081179091556040517fbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b905f90a2506100ba565b5f6020828403121561009d575f80fd5b81516001600160a01b03811681146100b3575f80fd5b9392505050565b60b6806100c65f395ff3fe608060405236603c57603a7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc5b546001600160a01b03166063565b005b603a7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc602c565b365f80375f80365f845af43d5f803e808015607c573d5ff35b3d5ffdfea2646970667358221220eeb8a2fa918a2057b66e1d3fa3930647dc7a4e56c99898cd9e280beec9d9ba9f64736f6c63430008160033000000000000000000000000";

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error ProxyCreationFailed();

    /* //////////////////////////////////////////////////////////////
                            CREATION LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Creates a new Proxy.
     * @param salt The create2 salt.
     * @param implementation The implementation contract of the Proxy.
     * @return proxy The contract address of the Proxy.
     */
    function createProxy(uint256 salt, address implementation) internal returns (address proxy) {
        bytes memory runtimeBytecode = abi.encodePacked(PROXY_BYTECODE, implementation);
        assembly {
            proxy := create2(0, add(runtimeBytecode, 0x20), mload(runtimeBytecode), salt)
        }
        if (proxy.code.length == 0) revert ProxyCreationFailed();
    }

    /**
     * @notice Computes the address of a Proxy contract.
     * @param salt The create2 salt.
     * @param implementation The implementation contract of the Proxy.
     * @return proxy The contract address of the Proxy.
     */
    function getProxyAddress(uint256 salt, address implementation) internal view returns (address proxy) {
        bytes memory runtimeBytecode = abi.encodePacked(PROXY_BYTECODE, implementation);
        proxy = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(this), salt, keccak256(runtimeBytecode)))))
        );
    }
}
