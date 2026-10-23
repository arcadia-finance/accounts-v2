/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { Emissions } from "../../../../src/asset-modules/Metadex03/libraries/Emissions.sol";
import { IEmissionsHandler } from "../../../../src/asset-modules/Metadex03/interfaces/IEmissionsHandler.sol";
import { IGaugeFactory } from "../../../../src/asset-modules/Metadex03/interfaces/IGaugeFactory.sol";
import { StakedMetadex03AM } from "../../../../src/asset-modules/Metadex03/StakedMetadex03AM.sol";
import { StakedMetadex03AM_Fuzz_Test, StakingAM } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the constructor of contract "StakedMetadex03AM".
 */
contract Constructor_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_constructor_GaugeFactoryNotValid_StableNotStable(
        address owner_,
        address registry_,
        address stableGaugeFactory
    ) public {
        // Given: The GaugeFactory passed as the stable one serves volatile pools.
        vm.assume(stableGaugeFactory != address(vm));
        vm.mockCall(stableGaugeFactory, abi.encodeWithSelector(IGaugeFactory.IS_STABLE.selector), abi.encode(false));

        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(StakedMetadex03AM.GaugeFactoryNotValid.selector);
        new StakedMetadex03AM(owner_, registry_, stableGaugeFactory, address(metadex03GaugeFactory), surplusRecipient);
    }

    function testFuzz_Revert_constructor_GaugeFactoryNotValid_VolatileIsStable(
        address owner_,
        address registry_,
        address volatileGaugeFactory
    ) public {
        // Given: The GaugeFactory passed as the volatile one serves stable pools.
        vm.assume(volatileGaugeFactory != address(vm));
        vm.mockCall(volatileGaugeFactory, abi.encodeWithSelector(IGaugeFactory.IS_STABLE.selector), abi.encode(true));

        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(StakedMetadex03AM.GaugeFactoryNotValid.selector);
        new StakedMetadex03AM(
            owner_, registry_, address(metadex03StableGaugeFactory), volatileGaugeFactory, surplusRecipient
        );
    }

    function testFuzz_Revert_constructor_GaugeFactoryNotValid_LeafVoterMismatch(
        address owner_,
        address registry_,
        address otherLeafVoter
    ) public {
        // Given: The two GaugeFactories disagree on their LeafVoter, which is what pins the reward token.
        vm.assume(otherLeafVoter != address(leafVoter));
        vm.mockCall(
            address(metadex03GaugeFactory),
            abi.encodeWithSelector(IGaugeFactory.LEAF_VOTER.selector),
            abi.encode(otherLeafVoter)
        );

        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(StakedMetadex03AM.GaugeFactoryNotValid.selector);
        new StakedMetadex03AM(
            owner_, registry_, address(metadex03StableGaugeFactory), address(metadex03GaugeFactory), surplusRecipient
        );
    }

    function testFuzz_Revert_constructor_HandlerNotValid_MalformedAnswer(
        address owner_,
        address registry_,
        bytes memory answer
    ) public {
        // Given: The emissions handler answers RECEIPT_TOKEN() with something that is not an address.
        vm.assume(answer.length != 32);
        vm.mockCall(emissionsHandler, abi.encodeWithSelector(IEmissionsHandler.RECEIPT_TOKEN.selector), answer);

        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(Emissions.HandlerNotValid.selector);
        new StakedMetadex03AM(
            owner_, registry_, address(metadex03StableGaugeFactory), address(metadex03GaugeFactory), surplusRecipient
        );
    }

    function testFuzz_Revert_constructor_HandlerNotValid_RevertsWithData(
        address owner_,
        address registry_,
        bytes memory reason
    ) public {
        // Given: The emissions handler reverts RECEIPT_TOKEN() with data, which is not a shape we know.
        vm.assume(reason.length > 0);
        vm.mockCallRevert(emissionsHandler, abi.encodeWithSelector(IEmissionsHandler.RECEIPT_TOKEN.selector), reason);

        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(Emissions.HandlerNotValid.selector);
        new StakedMetadex03AM(
            owner_, registry_, address(metadex03StableGaugeFactory), address(metadex03GaugeFactory), surplusRecipient
        );
    }

    function testFuzz_Revert_constructor_RecipientNotValid(address owner_, address registry_) public {
        // Given: The recipient of the surplus is the zero address.
        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(StakingAM.RecipientNotValid.selector);
        new StakedMetadex03AM(
            owner_, registry_, address(metadex03StableGaugeFactory), address(metadex03GaugeFactory), address(0)
        );
    }

    function testFuzz_Success_constructor_Leaf(address owner_, address registry_) public {
        // Given: The protocol is staged on the leaf chain.

        // When: The Asset Module is deployed.
        StakedMetadex03AM assetModule = new StakedMetadex03AM(
            owner_, registry_, address(metadex03StableGaugeFactory), address(metadex03GaugeFactory), surplusRecipient
        );

        // Then: The reward token is the ReceiptToken, which is what the leaf gauges pay out.
        assertEq(address(assetModule.REWARD_TOKEN()), receiptToken);

        // And: The immutables and the metadata are set.
        assertEq(assetModule.ASSET_TYPE(), 2);
        assertEq(assetModule.owner(), owner_);
        assertEq(assetModule.REGISTRY(), registry_);
        assertEq(assetModule.symbol(), "aSMDEXP");
        assertEq(assetModule.name(), "Arcadia Staked Metadex03 Positions");
        assertEq(address(assetModule.FACTORY_REGISTRY()), address(factoryRegistryMetadex03));
        assertGt(assetModule.STAKER().code.length, 0);

        // And: No redeem floor applies, only the root chain redeems on a claim.
        assertEq(assetModule.MIN_REDEEM_AMOUNT(), 0);
        assertFalse(assetModule.IS_ROOT());
    }

    function testFuzz_Success_constructor_Root(address owner_, address registry_) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // When: The Asset Module is deployed against it.
        StakedMetadex03AM assetModule = new StakedMetadex03AM(
            owner_, registry_, address(metadex03StableGaugeFactory), address(metadex03GaugeFactory), surplusRecipient
        );

        // Then: The reward token is the Token of the redeem path, not the ReceiptToken.
        assertEq(address(assetModule.REWARD_TOKEN()), rootToken);
        assertTrue(rootToken != receiptToken);

        // And: The immutables and the metadata are set.
        assertEq(assetModule.ASSET_TYPE(), 2);
        assertEq(assetModule.owner(), owner_);
        assertEq(assetModule.REGISTRY(), registry_);
        assertEq(assetModule.symbol(), "aSMDEXP");
        assertEq(assetModule.name(), "Arcadia Staked Metadex03 Positions");
        assertEq(address(assetModule.FACTORY_REGISTRY()), address(factoryRegistryMetadex03));
        assertGt(assetModule.STAKER().code.length, 0);

        // And: The redeem floor is read from the LeafVoter.
        assertEq(assetModule.MIN_REDEEM_AMOUNT(), leafVoter.MIN_REDEEM_AMOUNT());
        assertTrue(assetModule.IS_ROOT());
    }
}
