/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { Emissions } from "../../../../src/asset-modules/Metadex03/libraries/Emissions.sol";
import { IEmissionsHandler } from "../../../../src/asset-modules/Metadex03/interfaces/IEmissionsHandler.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedMetadex03CLAMExtension } from "../../../utils/extensions/StakedMetadex03CLAMExtension.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { Unused } from "../../../../src/libraries/Unused.sol";

/**
 * @notice Fuzz tests for the constructor of contract "StakedMetadex03CLAM".
 */
contract Constructor_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_constructor_HandlerNotValid_MalformedAnswer(
        bytes memory answer,
        address owner_,
        address registry_
    ) public {
        // Given: The emissions handler answers RECEIPT_TOKEN() with something that is not an address.
        vm.assume(answer.length != 32);
        vm.mockCall(emissionsHandler, abi.encodeWithSelector(IEmissionsHandler.RECEIPT_TOKEN.selector), answer);

        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(Emissions.HandlerNotValid.selector);
        new StakedMetadex03CLAMExtension(
            owner_, registry_, address(metadex03CLGaugeFactory), rewardToken, surplusRecipient
        );
    }

    function testFuzz_Revert_constructor_HandlerNotValid_RevertsWithData(
        bytes memory reason,
        address owner_,
        address registry_
    ) public {
        // Given: The emissions handler reverts RECEIPT_TOKEN() with data, which is not a shape we know.
        vm.assume(reason.length > 0);
        vm.mockCallRevert(emissionsHandler, abi.encodeWithSelector(IEmissionsHandler.RECEIPT_TOKEN.selector), reason);

        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(Emissions.HandlerNotValid.selector);
        new StakedMetadex03CLAMExtension(
            owner_, registry_, address(metadex03CLGaugeFactory), rewardToken, surplusRecipient
        );
    }

    function testFuzz_Revert_constructor_RewardTokenNotValid(address rewardToken_, address owner_, address registry_)
        public
    {
        // Given: The passed Reward Token is not the one the chain's emissions handler delivers.
        vm.assume(rewardToken_ != rewardToken);

        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(StakedSlipstreamAM.RewardTokenNotValid.selector);
        new StakedMetadex03CLAMExtension(
            owner_, registry_, address(metadex03CLGaugeFactory), rewardToken_, surplusRecipient
        );
    }

    function testFuzz_Revert_constructor_RecipientNotValid(address owner_, address registry_) public {
        // Given: The recipient of the deferred emissions is the zero address.

        // When: The Asset Module is deployed.
        // Then: It reverts.
        vm.expectRevert(StakedSlipstreamAM.RecipientNotValid.selector);
        new StakedMetadex03CLAMExtension(owner_, registry_, address(metadex03CLGaugeFactory), rewardToken, address(0));
    }

    function testFuzz_Success_constructor_Leaf(address owner_, address registry_, address surplusRecipient_) public {
        // Given: The recipient of the deferred emissions is not the zero address.
        vm.assume(surplusRecipient_ != address(0));

        // When: The Asset Module is deployed.
        stakedMetadex03CLAM = new StakedMetadex03CLAMExtension(
            owner_, registry_, address(metadex03CLGaugeFactory), rewardToken, surplusRecipient_
        );

        // Then: The constructor arguments are stored.
        assertEq(stakedMetadex03CLAM.owner(), owner_);
        assertEq(stakedMetadex03CLAM.REGISTRY(), registry_);
        assertEq(stakedMetadex03CLAM.getNonfungiblePositionManager(), address(metadex03PositionManager));
        assertEq(stakedMetadex03CLAM.getFactoryRegistry(), address(factoryRegistryMetadex03));
        assertEq(address(stakedMetadex03CLAM.REWARD_TOKEN()), receiptToken);
        assertEq(stakedMetadex03CLAM.MIN_REDEEM_AMOUNT(), 0);
        assertFalse(stakedMetadex03CLAM.IS_ROOT());
        assertEq(stakedMetadex03CLAM.EMISSIONS_HANDLER(), emissionsHandler);
        assertEq(stakedMetadex03CLAM.getCLFactory(), address(metadex03CLFactory));
        assertEq(stakedMetadex03CLAM.surplusRecipient(), surplusRecipient_);

        // And: The ERC721 identity comes from the override, not the inherited literal.
        assertEq(stakedMetadex03CLAM.name(), "Arcadia Staked Metadex03 CL Positions");
        assertEq(stakedMetadex03CLAM.symbol(), "aSMDEXCLP");

        // And: The inherited AERO_VOTER is never read, so it holds the unused sentinel.
        assertEq(stakedMetadex03CLAM.getAeroVoter(), Unused.IMMUTABLE);
    }

    function testFuzz_Success_constructor_Root(address owner_, address registry_, address surplusRecipient_) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03CL(true);

        // And: The recipient of the deferred emissions is not the zero address.
        vm.assume(surplusRecipient_ != address(0));

        // When: The Asset Module is deployed.
        stakedMetadex03CLAM = new StakedMetadex03CLAMExtension(
            owner_, registry_, address(metadex03CLGaugeFactory), rewardToken, surplusRecipient_
        );

        // Then: The constructor arguments are stored.
        assertEq(stakedMetadex03CLAM.owner(), owner_);
        assertEq(stakedMetadex03CLAM.REGISTRY(), registry_);
        assertEq(stakedMetadex03CLAM.surplusRecipient(), surplusRecipient_);

        // And: The reward token is the Token of the redeem path, not the ReceiptToken.
        assertEq(address(stakedMetadex03CLAM.REWARD_TOKEN()), rootToken);
        assertTrue(rootToken != receiptToken);

        // And: The redeem floor is read from the LeafVoter.
        assertEq(stakedMetadex03CLAM.MIN_REDEEM_AMOUNT(), leafVoter.MIN_REDEEM_AMOUNT());
        assertTrue(stakedMetadex03CLAM.IS_ROOT());
        assertEq(stakedMetadex03CLAM.EMISSIONS_HANDLER(), emissionsHandler);
    }
}
