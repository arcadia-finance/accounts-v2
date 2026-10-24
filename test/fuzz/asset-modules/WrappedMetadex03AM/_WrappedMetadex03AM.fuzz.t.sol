/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { IMetadex03V2Pool } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Pool.sol";
import { Metadex03Fixture } from "../../../utils/fixtures/metadex03/Metadex03Fixture.f.sol";
import { Metadex03PoolAM } from "../../../../src/asset-modules/Metadex03/Metadex03PoolAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedMetadex03AMExtension } from "../../../utils/extensions/WrappedMetadex03AMExtension.sol";

/**
 * @notice Common logic needed by "WrappedMetadex03AM" fuzz tests.
 */
// forge-lint: disable-next-item(unsafe-typecast)
abstract contract WrappedMetadex03AM_Fuzz_Test is Fuzz_Test, Metadex03Fixture {
    using stdStorage for StdStorage;

    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-start(mixed-case-variable)
    Metadex03PoolAM internal metadex03PoolAM;
    ERC20Mock internal asset0;
    ERC20Mock internal asset1;
    IMetadex03V2Pool internal metadex03Pool;
    WrappedMetadex03AMExtension internal wrappedMetadex03AM;
    // forge-lint: disable-end(mixed-case-variable)

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy the Metadex03 contracts
        deployMetadex03Periphery();
        deployMetadex03();

        // Deploy Metadex03 AM.
        vm.startPrank(users.owner);
        metadex03PoolAM = new Metadex03PoolAM(
            users.owner, address(registry), address(stablePoolFactory), address(volatilePoolFactory)
        );
        registry.addAssetModule(address(metadex03PoolAM));

        // Deploy WrappedMetadex03AM.
        wrappedMetadex03AM = new WrappedMetadex03AMExtension(users.owner, address(registry));
        registry.addAssetModule(address(wrappedMetadex03AM));
        wrappedMetadex03AM.initialize();
        vm.stopPrank();

        // Create a metadex03Pool where both assets have a usd value equal to their amount.
        asset0 = new ERC20Mock("Asset 0", "ASSET0", 18);
        asset1 = new ERC20Mock("Asset 1", "ASSET1", 18);
        addAssetToArcadia(address(asset0), 1e18);
        addAssetToArcadia(address(asset1), 1e18);
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-next-item(mixed-case-function)
    function givenValidAMState(
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1
    )
        public
        pure
        returns (WrappedAerodromeAM.PoolState memory, WrappedAerodromeAM.PositionState memory, uint256, uint256)
    {
        // Given: A non-zero amount of liquidity is wrapped.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, type(uint128).max));

        // And: The position wraps at most the total wrapped amount.
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 1, poolState.totalWrapped));

        // And: The accrued pool fees keep both fee accumulators within uint128.
        fee0 = bound(fee0, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // And: The pool advanced its fee0 accumulator by the accrued fee0.
        uint256 deltaFee0PerLiquidity = fee0 * 1e18 / poolState.totalWrapped;
        uint128 currentFee0PerLiquidity;
        unchecked {
            currentFee0PerLiquidity = poolState.fee0PerLiquidity + uint128(deltaFee0PerLiquidity);
        }
        // And: The fee0 newly earned by the position stays within uint128.
        unchecked {
            deltaFee0PerLiquidity = currentFee0PerLiquidity - positionState.fee0PerLiquidity;
        }
        deltaFee0PerLiquidity =
            bound(deltaFee0PerLiquidity, 0, type(uint128).max * uint256(1e18) / positionState.amountWrapped);
        unchecked {
            positionState.fee0PerLiquidity = currentFee0PerLiquidity - uint128(deltaFee0PerLiquidity);
        }
        // And: The fee0 balance of the position plus the newly earned fee0 stays within uint128.
        uint256 deltaFee0 = deltaFee0PerLiquidity * uint256(positionState.amountWrapped) / 1e18;
        positionState.fee0 = uint128(bound(positionState.fee0, 0, type(uint128).max - deltaFee0));

        // And: The pool advanced its fee1 accumulator by the accrued fee1.
        uint256 deltaFee1PerLiquidity = fee1 * 1e18 / poolState.totalWrapped;
        uint128 currentFee1PerLiquidity;
        unchecked {
            currentFee1PerLiquidity = poolState.fee1PerLiquidity + uint128(deltaFee1PerLiquidity);
        }
        // And: The fee1 newly earned by the position stays within uint128.
        unchecked {
            deltaFee1PerLiquidity = currentFee1PerLiquidity - positionState.fee1PerLiquidity;
        }
        deltaFee1PerLiquidity =
            bound(deltaFee1PerLiquidity, 0, type(uint128).max * uint256(1e18) / positionState.amountWrapped);
        unchecked {
            positionState.fee1PerLiquidity = currentFee1PerLiquidity - uint128(deltaFee1PerLiquidity);
        }
        // And: The fee1 balance of the position plus the newly earned fee1 stays within uint128.
        uint256 deltaFee1 = deltaFee1PerLiquidity * positionState.amountWrapped / 1e18;
        positionState.fee1 = uint128(bound(positionState.fee1, 0, type(uint128).max - deltaFee1));

        return (poolState, positionState, fee0, fee1);
    }

    // forge-lint: disable-next-item(mixed-case-function)
    function setAMState(
        IMetadex03V2Pool pool_,
        uint256 positionId,
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState
    ) public {
        wrappedMetadex03AM.setPoolState(address(pool_), poolState);
        positionState.pool = address(pool_);
        wrappedMetadex03AM.setPositionState(positionId, positionState);
        deal(address(pool_), address(wrappedMetadex03AM), poolState.totalWrapped, true);

        (address token0, address token1) = pool_.tokens();
        wrappedMetadex03AM.setTokens(address(pool_), token0, token1);
    }

    function setClaimables(IMetadex03V2Pool pool_, address account, uint256 claimable0_, uint256 claimable1_) internal {
        stdstore.target(address(pool_)).sig(pool_.claimable0.selector).with_key(account).checked_write(claimable0_);
        stdstore.target(address(pool_)).sig(pool_.claimable1.selector).with_key(account).checked_write(claimable1_);
    }
}
