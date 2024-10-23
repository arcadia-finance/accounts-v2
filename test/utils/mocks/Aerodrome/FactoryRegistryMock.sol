/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

contract FactoryRegistryMock {
    mapping(address poolFactory => address votingRewardsFactory) internal poolFactoryToVotingRewardsFactory;
    mapping(address poolFactory => address gaugeFactory) internal poolFactoryToGaugeFactory;

    function factoriesToPoolFactory(address poolFactory)
        public
        view
        returns (address votingRewardsFactory, address gaugeFactory)
    {
        votingRewardsFactory = poolFactoryToVotingRewardsFactory[poolFactory];
        gaugeFactory = poolFactoryToGaugeFactory[poolFactory];
    }

    function setFactoriesToPoolFactory(address poolFactory, address votingRewardsFactory, address gaugeFactory)
        public
    {
        poolFactoryToVotingRewardsFactory[poolFactory] = votingRewardsFactory;
        poolFactoryToGaugeFactory[poolFactory] = gaugeFactory;
    }
}
