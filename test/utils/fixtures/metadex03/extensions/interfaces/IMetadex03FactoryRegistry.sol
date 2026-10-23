// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

interface IMetadex03FactoryRegistry {
    function targetFactoryToGaugeFactory(address targetFactory) external view returns (address gaugeFactory);

    function targetToGauge(address target) external view returns (address gauge);
}
