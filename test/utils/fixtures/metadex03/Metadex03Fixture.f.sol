/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { IFactoryRegistry } from "./interfaces/IFactoryRegistry.sol";
import { ILeafMessageOrchestrator } from "./interfaces/ILeafMessageOrchestrator.sol";
import { ILeafVoter } from "./interfaces/ILeafVoter.sol";
import { IMetadex03EmissionsHandler } from "./interfaces/IMetadex03EmissionsHandler.sol";
import { IMetadex03V2Gauge } from "./interfaces/IMetadex03V2Gauge.sol";
import { IMetadex03V2GaugeFactory } from "./interfaces/IMetadex03V2GaugeFactory.sol";
import { IMetadex03V2Pool } from "./interfaces/IMetadex03V2Pool.sol";
import { IMetadex03V2PoolFactory } from "./interfaces/IMetadex03V2PoolFactory.sol";
import { IRootMessageOrchestrator } from "./interfaces/IRootMessageOrchestrator.sol";
import { IVoter } from "./interfaces/IVoter.sol";
import { Test } from "../../../../lib/forge-std/src/Test.sol";

// forge-lint: disable-next-item(reentrancy-no-eth)
contract Metadex03Fixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    uint256 internal constant MAX_PIPS = 1_000_000;

    uint24 internal constant MAX_WEEKLY_RATE_CHANGE_PIPS = 50_000;

    // The slot offset of the ceiling in a ChainState.
    uint256 internal constant CEILING_OFFSET = 2;

    // Base is the Metadex03 root chain.
    uint256 internal constant ROOT_CHAIN_ID = 8453;

    uint24 internal constant MAX_BAND_CEILING_PIPS = 1_000_000;
    uint24 internal constant MAX_BAND_FLOOR_PIPS = 500_000;

    uint256 internal constant MAX_MIN_STAKE_BLOCKS = type(uint128).max;

    uint128 internal constant PRECISION = 1e18;

    uint32 internal constant POOL_TAPE_CADENCE_INTERVAL = 300;
    uint32 internal constant POOL_TAPE_GAS_LIMIT = 200_000;
    uint32 internal constant FEE_MODULE_GAS_LIMIT = 20_000;

    /*//////////////////////////////////////////////////////////////////////////
                                   ADDRESSES
    //////////////////////////////////////////////////////////////////////////*/

    address internal metadex03Governor = address(uint160(uint256(keccak256("Metadex03Governor"))));
    address internal metadex03ConfigAdmin = address(uint160(uint256(keccak256("Metadex03ConfigAdmin"))));
    address internal metadex03Orchestrator = address(uint160(uint256(keccak256("Metadex03Orchestrator"))));
    address internal metadex03GaugeManager = address(uint160(uint256(keccak256("Metadex03GaugeManager"))));
    address internal metadex03Fed = address(uint160(uint256(keccak256("Metadex03Fed"))));
    address internal metadex03TokenRegistry = address(uint160(uint256(keccak256("Metadex03TokenRegistry"))));

    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IFactoryRegistry internal factoryRegistryMetadex03;
    ILeafVoter internal leafVoter;
    IMetadex03V2GaugeFactory internal metadex03GaugeFactory;
    IMetadex03V2GaugeFactory internal metadex03StableGaugeFactory;
    IMetadex03V2PoolFactory internal stablePoolFactory;
    IMetadex03V2PoolFactory internal volatilePoolFactory;
    address internal votingRewardsFactory;
    uint256 internal constant MIN_REDEEM_AMOUNT = 1_000_000;

    // The rate the emissions cap accrues at.
    uint232 internal constant MAX_BASE_RATE = 730_750_818_665_456_651_398_700_951_213;

    // The addresses of the linked metadex03 libraries.
    address internal constant ALLOCATION_LOGIC_LIBRARY = 0x3000000000000000000000000000000000000001;
    address internal constant LEAF_ALLOCATION_LIBRARY = 0x3000000000000000000000000000000000000002;
    address internal constant REWARDS_LOGIC_LIBRARY = 0x3000000000000000000000000000000000000003;
    address internal constant VOTING_REWARDS_FACTORY_LIBRARY = 0x3000000000000000000000000000000000000004;

    address internal emissionsHandler;
    address internal receiptToken;

    // Only set on the root chain, the Voter that mints the Token a redeem pays out.
    IVoter internal rootVoter;

    // The address the LeafVoter accepts allocation messages from.
    address internal messageOrchestrator;

    // Only set on the root chain, where the ReceiptToken is redeemed for the Token.
    address internal rootToken;

    // Tracks the gauges that already carry voting weight.
    mapping(address gauge => bool weighted) internal metadex03GaugeWeighted;

    // Deploys the Arbitrum gauge factories, whose gauges read the block height from ArbSys.
    bool internal metadex03ArbGauges;

    // Maps a gauge to the gauge factory that created it.
    mapping(address gauge => IMetadex03V2GaugeFactory gaugeFactory) internal metadex03GaugeFactoryOf;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function deployMetadex03Periphery() internal {
        deployMetadex03Periphery(false);
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function deployMetadex03Periphery(bool root) internal {
        _deployMetadex03Libraries();
        root ? _deployMetadex03Root() : _deployMetadex03Leaf();

        votingRewardsFactory =
            deployCode("VotingRewardsFactory.sol:VotingRewardsFactory", abi.encode(address(leafVoter), address(0)));

        // Assert the FactoryRegistry constructor argument order.
        assertEq(factoryRegistryMetadex03.leafVoter(), address(leafVoter));
    }

    /**
     * @notice Stages the linked libraries at their linked addresses.
     */
    function _deployMetadex03Libraries() private {
        deployCodeTo("AllocationLogicLibrary.sol:AllocationLogicLibrary", ALLOCATION_LOGIC_LIBRARY);
        deployCodeTo("LeafAllocationLibrary.sol:LeafAllocationLibrary", LEAF_ALLOCATION_LIBRARY);
        deployCodeTo("RewardsLogicLibrary.sol:RewardsLogicLibrary", REWARDS_LOGIC_LIBRARY);
        deployCodeTo("VotingRewardsFactoryLibrary.sol:VotingRewardsFactoryLibrary", VOTING_REWARDS_FACTORY_LIBRARY);
    }

    /**
     * @notice Deploys the leaf chain shape, where emissions are paid in the ReceiptToken.
     */
    function _deployMetadex03Leaf() private {
        // Predict the LeafVoter address.
        address predictedVoter = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 4);

        receiptToken =
            deployCode("ReceiptToken.sol:ReceiptToken", abi.encode(predictedVoter, "Receipt Token", "rTOKEN"));
        emissionsHandler =
            deployCode("LeafEmissionsHandler.sol:LeafEmissionsHandler", abi.encode(predictedVoter, receiptToken));
        factoryRegistryMetadex03 = IFactoryRegistry(
            deployCode(
                "FactoryRegistry.sol:FactoryRegistry", abi.encode(address(0), predictedVoter, metadex03TokenRegistry)
            )
        );

        // The orchestrator points at the root chain.
        messageOrchestrator = deployCode(
            "LeafMessageOrchestrator.sol:LeafMessageOrchestrator",
            abi.encode(predictedVoter, ROOT_CHAIN_ID, address(0), uint256(0))
        );
        leafVoter = ILeafVoter(deployCode("LeafVoter.sol:LeafVoter", _leafVoterArgs()));
        assertEq(address(leafVoter), predictedVoter);
    }

    /**
     * @notice The predicted addresses of the redeem path.
     */
    struct RootAddresses {
        address token;
        address minter;
        address voter;
        address rootOrchestrator;
        address leafVoter;
        uint48 migrationOpen;
    }

    /**
     * @notice Deploys the root chain shape, where the ReceiptToken is redeemed for the Token on every claim.
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _deployMetadex03Root() private {
        uint256 stagedAt = _stagingClock(vm.getBlockTimestamp());
        vm.warp(stagedAt - 3 weeks);

        RootAddresses memory predicted = _predictRootAddresses();
        messageOrchestrator = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 7);

        _deployRootVoter(predicted);

        receiptToken =
            deployCode("ReceiptToken.sol:ReceiptToken", abi.encode(predicted.leafVoter, "Receipt Token", "rTOKEN"));
        emissionsHandler = deployCode("RootEmissionsHandler.sol:RootEmissionsHandler", abi.encode(predicted.leafVoter));
        factoryRegistryMetadex03 = IFactoryRegistry(
            deployCode(
                "FactoryRegistry.sol:FactoryRegistry",
                abi.encode(address(0), predicted.leafVoter, metadex03TokenRegistry)
            )
        );
        assertEq(
            deployCode(
                "LeafMessageOrchestrator.sol:LeafMessageOrchestrator",
                abi.encode(predicted.leafVoter, block.chainid, address(0), uint256(0))
            ),
            messageOrchestrator
        );
        leafVoter = ILeafVoter(deployCode("LeafVoter.sol:LeafVoter", _leafVoterArgs()));
        assertEq(address(leafVoter), predicted.leafVoter);

        // Deploy and wire the adapter of the redeem path.
        address adapter = deployCode(
            "RootLocalAdapter.sol:RootLocalAdapter", abi.encode(predicted.rootOrchestrator, messageOrchestrator)
        );
        vm.startPrank(metadex03ConfigAdmin);
        ILeafMessageOrchestrator(messageOrchestrator).setAdapter(adapter);
        IRootMessageOrchestrator(predicted.rootOrchestrator).setAdapter(block.chainid, adapter);
        vm.stopPrank();

        // Register the chain and seed its ceiling.
        rootVoter = IVoter(predicted.voter);
        vm.prank(metadex03ConfigAdmin);
        rootVoter.registerChain(block.chainid);
        _seedChainCeiling(type(uint128).max);

        vm.warp(stagedAt);
    }

    /**
     * @notice Sets the ceiling the root Voter caps redemptions of this chain against.
     * @param ceiling The amount of Token this chain may redeem in total.
     */
    function setChainCeiling(uint256 ceiling) internal {
        _seedChainCeiling(ceiling);
    }

    /**
     * @notice Seeds the ceiling the root Voter caps redemptions of this chain against.
     * @param ceiling The amount of Token this chain may redeem in total.
     * @dev Locates the slot by probing and verifies it through the getter.
     */
    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _seedChainCeiling(uint256 ceiling) internal {
        for (uint256 slot; slot < 64; ++slot) {
            bytes32 target = bytes32(uint256(keccak256(abi.encode(block.chainid, slot))) + CEILING_OFFSET);
            bytes32 previous = vm.load(address(rootVoter), target);
            vm.store(address(rootVoter), target, bytes32(ceiling));
            (, uint256 stored,,,,) = rootVoter.chainStates(block.chainid);
            if (stored == ceiling) return;
            vm.store(address(rootVoter), target, previous);
        }
        revert("Metadex03Fixture: ceiling slot not found");
    }

    function _stagingClock(uint256 timestamp) private pure returns (uint256 clock) {
        clock = timestamp > 3 weeks ? timestamp : 4 weeks;
    }

    function _predictRootAddresses() private view returns (RootAddresses memory predicted) {
        uint64 nonce = vm.getNonce(address(this));
        // forge-lint: disable-next-item(unsafe-typecast)
        predicted = RootAddresses({
            token: vm.computeCreateAddress(address(this), nonce),
            minter: vm.computeCreateAddress(address(this), nonce + 1),
            voter: vm.computeCreateAddress(address(this), nonce + 2),
            rootOrchestrator: vm.computeCreateAddress(address(this), nonce + 3),
            leafVoter: vm.computeCreateAddress(address(this), nonce + 8),
            // The migration must open on a future epoch start.
            migrationOpen: uint48((block.timestamp / 1 weeks + 1) * 1 weeks)
        });
    }

    /**
     * @notice Deploys the root Token, Minter, Voter and RootMessageOrchestrator.
     */
    function _deployRootVoter(RootAddresses memory predicted) private {
        rootToken = deployCode("Token.sol:Token", _tokenArgs(predicted));
        assertEq(rootToken, predicted.token);
        deployCode("Minter.sol:Minter", _minterArgs(predicted));
        deployCode("Voter.sol:Voter", _voterArgs(predicted));
        deployCode("RootMessageOrchestrator.sol:RootMessageOrchestrator", abi.encode(predicted.voter));
    }

    function _tokenArgs(RootAddresses memory predicted) private view returns (bytes memory args) {
        args = abi.encode(
            predicted.minter,
            metadex03Governor,
            metadex03Governor,
            metadex03Governor,
            uint256(0),
            uint256(0),
            "Token",
            "TOKEN"
        );
    }

    /**
     * @notice Returns the encoded Voter constructor arguments.
     */
    function _voterArgs(RootAddresses memory predicted) private view returns (bytes memory args) {
        // A non-zero placeholder stands in for the VotingEscrow.
        // forge-lint: disable-next-item(encode-packed-collision)
        args = abi.encodePacked(
            abi.encode(
                predicted.rootOrchestrator, metadex03Governor, predicted.minter, predicted.token, metadex03Governor
            ),
            abi.encode(
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                uint48(1 weeks),
                uint48(1 weeks)
            )
        );
    }

    /**
     * @notice Returns the encoded LeafVoter constructor arguments.
     */
    function _leafVoterArgs() private view returns (bytes memory args) {
        // forge-lint: disable-next-item(encode-packed-collision)
        args = abi.encodePacked(
            abi.encode(
                metadex03Governor,
                metadex03ConfigAdmin,
                messageOrchestrator,
                receiptToken,
                address(factoryRegistryMetadex03),
                metadex03GaugeManager
            ),
            abi.encode(
                uint48(0), uint48(7 days), uint256(100), metadex03ConfigAdmin, emissionsHandler, metadex03Governor
            ),
            abi.encode(
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                metadex03ConfigAdmin,
                uint256(1_000_000)
            )
        );
    }

    /**
     * @notice Returns the encoded Minter constructor arguments.
     */
    function _minterArgs(RootAddresses memory predicted) private view returns (bytes memory args) {
        // forge-lint: disable-next-item(encode-packed-collision)
        args = abi.encodePacked(
            abi.encode(
                predicted.token,
                predicted.voter,
                metadex03Governor,
                metadex03Governor,
                metadex03Fed,
                predicted.migrationOpen,
                MAX_BASE_RATE,
                uint24(MAX_WEEKLY_RATE_CHANGE_PIPS)
            ),
            abi.encode(
                uint48(1 weeks),
                uint24(0),
                uint24(MAX_WEEKLY_RATE_CHANGE_PIPS),
                uint48(1 hours),
                uint48(4 weeks),
                MAX_BAND_FLOOR_PIPS,
                MAX_BAND_CEILING_PIPS
            )
        );
    }

    function deployMetadex03() internal {
        address poolTape = deployCode("PoolTape.sol:PoolTape", abi.encode(address(this), POOL_TAPE_CADENCE_INTERVAL));
        stablePoolFactory =
            _deployPoolFactory("StablePoolFactory.sol:StablePoolFactory", "StablePool.sol:StablePool", poolTape);
        volatilePoolFactory = _deployPoolFactory(
            "VolatilePoolFactory.sol:VolatilePoolFactory", "VolatilePool.sol:VolatilePool", poolTape
        );

        metadex03GaugeFactory = _deployGaugeFactory(false);
        metadex03StableGaugeFactory = _deployGaugeFactory(true);

        vm.startPrank(metadex03ConfigAdmin);
        factoryRegistryMetadex03.registerFactories(address(metadex03GaugeFactory), address(volatilePoolFactory));
        factoryRegistryMetadex03.registerFactories(address(metadex03StableGaugeFactory), address(stablePoolFactory));
        vm.stopPrank();

        metadex03GaugeFactory.setPenaltyConfig(0, 0);
        metadex03GaugeFactory.setMaxShareCap(MAX_PIPS);
        metadex03StableGaugeFactory.setPenaltyConfig(0, 0);
        metadex03StableGaugeFactory.setMaxShareCap(MAX_PIPS);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function createPoolMetadex03(address token0, address token1, bool stable) internal returns (IMetadex03V2Pool pool) {
        IMetadex03V2PoolFactory poolFactory = stable ? stablePoolFactory : volatilePoolFactory;
        // createPool registers the pool as a target on the FactoryRegistry itself.
        pool = IMetadex03V2Pool(poolFactory.createPool(token0, token1));
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function createGaugeMetadex03(address pool) internal returns (IMetadex03V2Gauge gauge) {
        IMetadex03V2GaugeFactory gaugeFactory =
            stablePoolFactory.isPool(pool) ? metadex03StableGaugeFactory : metadex03GaugeFactory;

        vm.startPrank(metadex03GaugeManager);
        (address gauge_, address rewards) = gaugeFactory.createGauge(pool, "");
        factoryRegistryMetadex03.registerGauge(gauge_, address(gaugeFactory), rewards, pool);
        leafVoter.registerGauge(gauge_, true);
        vm.stopPrank();

        metadex03GaugeFactoryOf[gauge_] = gaugeFactory;
        gauge = IMetadex03V2Gauge(gauge_);
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function depositInGauge(address gauge, address lp, uint256 amount) internal {
        address pool = IMetadex03V2Gauge(gauge).stakingToken();
        deal(pool, lp, amount);
        vm.startPrank(lp);
        IMetadex03V2Pool(pool).approve(gauge, amount);
        IMetadex03V2Gauge(gauge).deposit(amount);
        vm.stopPrank();
    }

    function claimEmissionsTo(address gauge, address lp, address recipient) internal {
        vm.prank(lp);
        IMetadex03V2Gauge(gauge).claimEmissions(lp, recipient);
    }

    function pendingRedeemsOf(address recipient) internal view returns (uint256 pendingAmount) {
        pendingAmount = IMetadex03EmissionsHandler(emissionsHandler).pendingRedeems(recipient);
    }

    function addEmissionsToGauge(address gauge, uint256 emissions) internal {
        _allocateWeightToGauge(gauge);
        _setEmissionsPerVP(gauge, emissions);
        vm.warp(vm.getBlockTimestamp() + 1);
        _setEmissionsPerVP(gauge, 0);
    }

    function setPenaltyConfig(address gauge, uint256 minStakeBlocks, uint256 penaltyRate) internal {
        IMetadex03V2GaugeFactory gaugeFactory = metadex03GaugeFactoryOf[gauge];
        gaugeFactory.setPenaltyConfig(minStakeBlocks, penaltyRate);
        gaugeFactory.setMinStakeBlocks(gauge, minStakeBlocks);
    }

    function setGaugeTape(address gauge, address gaugeTape, uint32 gasLimit) internal {
        metadex03GaugeFactoryOf[gauge].setGaugeTape(gaugeTape, gasLimit);
    }

    function setReferralConfig(address gauge, address referral, uint256 share) internal {
        metadex03GaugeFactoryOf[gauge].setReferralConfig(gauge, referral, share);
    }

    function setEmissionCap(address gauge, uint128 cap) internal {
        metadex03GaugeFactoryOf[gauge].setEmissionCap(gauge, cap);
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function setChainSuspended(bool suspended) internal {
        vm.prank(metadex03ConfigAdmin);
        leafVoter.setChainStatus(suspended ? ILeafVoter.ChainStatus.Suspended : ILeafVoter.ChainStatus.Active);
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _allocateWeightToGauge(address gauge) private {
        uint256 tokenId = uint256(uint160(gauge));
        if (metadex03GaugeWeighted[gauge]) return;
        metadex03GaugeWeighted[gauge] = true;

        ILeafVoter.TokenSnapshot memory snapshot =
            ILeafVoter.TokenSnapshot({ staked: PRECISION, stakeEnd: 0, isPermanent: true });
        ILeafVoter.GaugeAllocation[] memory gauges = new ILeafVoter.GaugeAllocation[](1);
        gauges[0] = ILeafVoter.GaugeAllocation({ gauge: gauge, allocated: PRECISION, data: "" });

        vm.startPrank(messageOrchestrator);
        leafVoter.applyChainAllocation(tokenId, PRECISION, 0, true, true, snapshot);
        leafVoter.applyGaugeAllocations(tokenId, type(uint48).max, 0, true, false, snapshot, gauges);
        vm.stopPrank();
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    // forge-lint: disable-next-item(mixed-case-function,mixed-case-variable)
    function _setEmissionsPerVP(address gauge, uint256 emissionsPerVP) private {
        ILeafVoter.TokenSnapshot memory snapshot =
            ILeafVoter.TokenSnapshot({ staked: PRECISION, stakeEnd: 0, isPermanent: true });

        vm.prank(messageOrchestrator);
        leafVoter.applyChainAllocation(uint256(uint160(gauge)), 0, emissionsPerVP, true, false, snapshot);
    }

    function _deployGaugeFactory(bool isStable) private returns (IMetadex03V2GaugeFactory gaugeFactory) {
        // forge-lint: disable-next-item(encode-packed-collision)
        bytes memory args = abi.encodePacked(
            abi.encode(
                address(leafVoter),
                address(votingRewardsFactory),
                isStable,
                address(this),
                address(this),
                address(this),
                address(this)
            ),
            abi.encode(
                uint128(type(uint128).max - 1),
                uint128(1),
                uint128(type(uint128).max - 1),
                MAX_MIN_STAKE_BLOCKS,
                address(this),
                address(this),
                address(this),
                address(this)
            )
        );
        gaugeFactory = IMetadex03V2GaugeFactory(
            deployCode(
                metadex03ArbGauges ? "ArbGaugeFactory.sol:ArbGaugeFactory" : "GaugeFactory.sol:GaugeFactory", args
            )
        );
    }

    /**
     * @notice Deploys a pool factory with its fee module and exact-out quoter.
     */
    function _deployPoolFactory(string memory factoryName, string memory implementationName, address poolTape)
        private
        returns (IMetadex03V2PoolFactory poolFactory)
    {
        address implementation = deployCode(implementationName);
        address predicted = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        address feeModule = deployCode("CustomFeeModule.sol:CustomFeeModule", abi.encode(predicted));
        address exactOutFeeQuoter = deployCode("FlatFeeQuoter.sol:FlatFeeQuoter", abi.encode(predicted));

        // forge-lint: disable-next-item(encode-packed-collision)
        bytes memory args = abi.encodePacked(
            abi.encode(
                implementation,
                address(this),
                address(this),
                address(this),
                address(this),
                address(this),
                address(factoryRegistryMetadex03)
            ),
            abi.encode(
                address(0),
                poolTape,
                POOL_TAPE_GAS_LIMIT,
                feeModule,
                FEE_MODULE_GAS_LIMIT,
                address(0),
                uint32(0),
                exactOutFeeQuoter
            )
        );
        poolFactory = IMetadex03V2PoolFactory(deployCode(factoryName, args));
        assertEq(address(poolFactory), predicted);
    }
}
