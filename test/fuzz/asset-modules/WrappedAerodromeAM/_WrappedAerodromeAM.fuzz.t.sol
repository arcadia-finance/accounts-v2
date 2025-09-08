/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Fuzz_Test } from "../../Fuzz.t.sol";
import { AerodromeFixture } from "../../../utils/fixtures/aerodrome/AerodromeFixture.f.sol";

import { AerodromePoolAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { Pool } from "../../../utils/mocks/Aerodrome/AeroPoolMock.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedAerodromeAMExtension } from "../../../utils/extensions/WrappedAerodromeAMExtension.sol";

/**
 * @notice Common logic needed by "WrappedAerodromeAM" fuzz tests.
 */
abstract contract WrappedAerodromeAM_Fuzz_Test is Fuzz_Test, AerodromeFixture {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /// forge-lint: disable-start(mixed-case-variable)
    AerodromePoolAM internal aerodromePoolAM;
    ERC20Mock internal asset0;
    ERC20Mock internal asset1;
    Pool internal aeroPool;
    WrappedAerodromeAMExtension internal wrappedAerodromeAM;
    /// forge-lint: disable-end(mixed-case-variable)

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy mocked Aerodrome contracts
        deployAerodrome();

        // Deploy Aerodrome AM.
        vm.startPrank(users.owner);
        aerodromePoolAM = new AerodromePoolAM(address(registry), address(aeroPoolFactory));
        registry.addAssetModule(address(aerodromePoolAM));

        // Deploy WrappedAerodromeAM.
        wrappedAerodromeAM = new WrappedAerodromeAMExtension(address(registry));
        registry.addAssetModule(address(wrappedAerodromeAM));
        wrappedAerodromeAM.initialize();
        vm.stopPrank();

        // Create a aeroPool where both assets have a a usd value equal to their amount.
        asset0 = new ERC20Mock("Asset 0", "ASSET0", 18);
        asset1 = new ERC20Mock("Asset 1", "ASSET1", 18);
        addAssetToArcadia(address(asset0), 1e18);
        addAssetToArcadia(address(asset1), 1e18);
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    /// forge-lint: disable-next-item(mixed-case-function)
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
        // Given: more than 1 gwei is staked.
        poolState.totalWrapped = uint128(bound(poolState.totalWrapped, 1, type(uint128).max));

        // And: totalWrapped should be >= to amountWrappedForPosition (invariant).
        positionState.amountWrapped = uint128(bound(positionState.amountWrapped, 1, poolState.totalWrapped));

        // And: deltaFeesPerLiquidity is smaller or equal as type(uint128).max (no overflow safeCastTo128).
        fee0 = bound(fee0, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);
        fee1 = bound(fee1, 0, uint256(type(uint128).max) * poolState.totalWrapped / 1e18);

        // Calculate the new fee0PerLiquidity.
        uint256 deltaFee0PerLiquidity = fee0 * 1e18 / poolState.totalWrapped;
        uint128 currentFee0PerLiquidity;
        unchecked {
            currentFee0PerLiquidity = poolState.fee0PerLiquidity + uint128(deltaFee0PerLiquidity);
        }
        // And: New fee0 does not overflow.
        // -> fee0PerLiquidity of the position is smaller or equal to type(uint128).max (overflow).
        // -> deltaFee0PerLiquidity * positionState.amountWrapped / 1e18 <= type(uint128).max;
        unchecked {
            deltaFee0PerLiquidity = currentFee0PerLiquidity - positionState.fee0PerLiquidity;
        }
        deltaFee0PerLiquidity =
            bound(deltaFee0PerLiquidity, 0, type(uint128).max * uint256(1e18) / positionState.amountWrapped);
        unchecked {
            positionState.fee0PerLiquidity = currentFee0PerLiquidity - uint128(deltaFee0PerLiquidity);
        }
        // And: Previously earned fee0 for Account + new fee0 does not overflow.
        // -> fee0 + deltaFee0 <= type(uint128).max;
        uint256 deltaFee0 = deltaFee0PerLiquidity * uint256(positionState.amountWrapped) / 1e18;
        positionState.fee0 = uint128(bound(positionState.fee0, 0, type(uint128).max - deltaFee0));

        // Calculate the new fee1PerLiquidity.
        uint256 deltaFee1PerLiquidity = fee1 * 1e18 / poolState.totalWrapped;
        uint128 currentFee1PerLiquidity;
        unchecked {
            currentFee1PerLiquidity = poolState.fee1PerLiquidity + uint128(deltaFee1PerLiquidity);
        }
        // And: New fee1 does not overflow.
        // -> fee1PerLiquidity of the position is smaller or equal to type(uint128).max (overflow).
        // -> deltaFee1PerLiquidity * positionState.amountWrapped / 1e18 <= type(uint128).max;
        unchecked {
            deltaFee1PerLiquidity = currentFee1PerLiquidity - positionState.fee1PerLiquidity;
        }
        deltaFee1PerLiquidity =
            bound(deltaFee1PerLiquidity, 0, type(uint128).max * uint256(1e18) / positionState.amountWrapped);
        unchecked {
            positionState.fee1PerLiquidity = currentFee1PerLiquidity - uint128(deltaFee1PerLiquidity);
        }
        // And: Previously earned fee1 for Account + new fee1 does not overflow.
        // -> fee1 + deltaFee1 <= type(uint128).max;
        uint256 deltaFee1 = deltaFee1PerLiquidity * positionState.amountWrapped / 1e18;
        positionState.fee1 = uint128(bound(positionState.fee1, 0, type(uint128).max - deltaFee1));

        return (poolState, positionState, fee0, fee1);
    }

    /// forge-lint: disable-next-item(mixed-case-function)
    function setAMState(
        Pool pool_,
        uint256 positionId,
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState
    ) public {
        wrappedAerodromeAM.setPoolState(address(pool_), poolState);
        positionState.pool = address(pool_);
        wrappedAerodromeAM.setPositionState(positionId, positionState);
        deal(address(pool_), address(wrappedAerodromeAM), poolState.totalWrapped, true);

        (address token0, address token1) = pool_.tokens();
        wrappedAerodromeAM.setTokens(address(pool_), token0, token1);
    }
}
