/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FixedPointMathLib } from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";

import { AccountV1 } from "../../src/accounts/AccountV1.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";
import { BaseGuardian } from "../../src/guardians/BaseGuardian.sol";
import { ChainlinkOM } from "../../src/oracle-modules/ChainlinkOM.sol";
import { DerivedAM } from "../../src/asset-modules/abstracts/AbstractDerivedAM.sol";
import { FactoryGuardian } from "../../src/guardians/FactoryGuardian.sol";
import { FloorERC721AM } from "./mocks/asset-modules/FloorERC721AM.sol";
import { FloorERC1155AM } from "./mocks/asset-modules/FloorERC1155AM.sol";
import { RegistryGuardian } from "../../src/guardians/RegistryGuardian.sol";
import { Registry } from "../../src/Registry.sol";
import { IRegistry } from "../../src/interfaces/IRegistry.sol";
import { AssetModule } from "../../src/asset-modules/abstracts/AbstractAM.sol";
import { PrimaryAM } from "../../src/asset-modules/abstracts/AbstractPrimaryAM.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../src/libraries/AssetValuationLib.sol";
import { ERC20PrimaryAM } from "../../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { StandardERC4626AM } from "./mocks/asset-modules/StandardERC4626AM.sol";
import { UniswapV2AM } from "./mocks/asset-modules/UniswapV2AM.sol";
import { UniswapV3AM } from "../../src/asset-modules/UniswapV3/UniswapV3AM.sol";
import { ActionMultiCall } from "../../src/actions/MultiCall.sol";
import { StakingAM } from "../../src/asset-modules/abstracts/AbstractStakingAM.sol";
import { StargateAM } from "../../src/asset-modules/Stargate-Finance/StargateAM.sol";
import { StakedStargateAM } from "../../src/asset-modules/Stargate-Finance/StakedStargateAM.sol";

contract AccountExtension is AccountV1 {
    constructor(address factory) AccountV1(factory) { }

    function getLocked() external view returns (uint256 locked_) {
        locked_ = locked;
    }

    function setLocked(uint8 locked_) external {
        locked = locked_;
    }

    function setInAuction() external {
        inAuction = true;
    }

    function setLastActionTimestamp(uint32 lastActionTimestamp_) external {
        lastActionTimestamp = lastActionTimestamp_;
    }

    function getLengths() external view returns (uint256, uint256, uint256, uint256) {
        return (erc20Stored.length, erc721Stored.length, erc721TokenIds.length, erc1155Stored.length);
    }

    function setCreditor(address creditor_) public {
        creditor = creditor_;
    }

    function setMinimumMargin(uint96 minimumMargin_) public {
        minimumMargin = minimumMargin_;
    }

    function setOwner(address newOwner) public {
        owner = newOwner;
    }

    function setRegistry(address registry_) public {
        registry = registry_;
    }

    function getERC20Stored(uint256 index) public view returns (address) {
        return erc20Stored[index];
    }

    function getERC20Balances(address asset) public view returns (uint256) {
        return erc20Balances[asset];
    }

    function getERC721Stored(uint256 index) public view returns (address) {
        return erc721Stored[index];
    }

    function getERC721TokenIds(uint256 index) public view returns (uint256) {
        return erc721TokenIds[index];
    }

    function getERC1155Stored(uint256 index) public view returns (address) {
        return erc1155Stored[index];
    }

    function getERC1155TokenIds(uint256 index) public view returns (uint256) {
        return erc1155TokenIds[index];
    }

    function getERC1155Balances(address asset, uint256 assetId) public view returns (uint256) {
        return erc1155Balances[asset][assetId];
    }

    function getCoolDownPeriod() public pure returns (uint256 coolDownPeriod) {
        coolDownPeriod = COOL_DOWN_PERIOD;
    }
}

contract BaseGuardianExtension is BaseGuardian {
    constructor() BaseGuardian() { }

    function pause() external override { }

    function unpause() external override { }
}

contract BitPackingLibExtension {
    function pack(bool[] memory boolValues, uint80[] memory uintValues) public pure returns (bytes32 packedData) {
        packedData = BitPackingLib.pack(boolValues, uintValues);
    }

    function unpack(bytes32 packedData) public pure returns (bool[] memory boolValues, uint256[] memory uintValues) {
        (boolValues, uintValues) = BitPackingLib.unpack(packedData);
    }
}

contract ChainlinkOMExtension is ChainlinkOM {
    constructor(address registry_) ChainlinkOM(registry_) { }

    function getInOracleModule(address oracle) public view returns (bool) {
        return inOracleModule[oracle];
    }

    function getOracleInformation(uint256 oracleId)
        public
        view
        returns (uint32 cutOffTime, uint64 unitCorrection, address oracle)
    {
        cutOffTime = oracleInformation[oracleId].cutOffTime;
        unitCorrection = oracleInformation[oracleId].unitCorrection;
        oracle = oracleInformation[oracleId].oracle;
    }
}

contract FactoryGuardianExtension is FactoryGuardian {
    constructor() FactoryGuardian() { }

    function setPauseTimestamp(uint96 pauseTimestamp_) public {
        pauseTimestamp = pauseTimestamp_;
    }

    function setFlags(bool createPaused_) public {
        createPaused = createPaused_;
    }
}

contract RegistryGuardianExtension is RegistryGuardian {
    constructor() RegistryGuardian() { }

    function setPauseTimestamp(uint96 pauseTimestamp_) public {
        pauseTimestamp = pauseTimestamp_;
    }

    function setFlags(bool withdrawPaused_, bool depositPaused_) public {
        withdrawPaused = withdrawPaused_;
        depositPaused = depositPaused_;
    }
}

contract RegistryExtension is Registry {
    using FixedPointMathLib for uint256;

    constructor(address factory, address sequencerUptimeOracle_) Registry(factory, sequencerUptimeOracle_) { }

    function isSequencerDown(address creditor) public view returns (bool success, bool sequencerDown) {
        return _isSequencerDown(creditor);
    }

    function getSequencerUptimeOracle() public view returns (address sequencerUptimeOracle_) {
        sequencerUptimeOracle_ = sequencerUptimeOracle;
    }

    function getOracleCounter() public view returns (uint256 oracleCounter_) {
        oracleCounter_ = oracleCounter;
    }

    function setOracleCounter(uint256 oracleCounter_) public {
        oracleCounter = oracleCounter_;
    }

    function getOracleToOracleModule(uint256 oracleId) public view returns (address oracleModule) {
        oracleModule = oracleToOracleModule[oracleId];
    }

    function setOracleToOracleModule(uint256 oracleId, address oracleModule) public {
        oracleToOracleModule[oracleId] = oracleModule;
    }

    function setAssetToAssetModule(address asset, address assetModule) public {
        assetToAssetModule[asset] = assetModule;
    }
}

contract AssetValuationLibExtension {
    function calculateCollateralValue(AssetValueAndRiskFactors[] memory valuesAndRiskFactors)
        external
        pure
        returns (uint256 collateralValue)
    {
        collateralValue = AssetValuationLib._calculateCollateralValue(valuesAndRiskFactors);
    }

    function calculateLiquidationValue(AssetValueAndRiskFactors[] memory valuesAndRiskFactors)
        external
        pure
        returns (uint256 liquidationValue)
    {
        liquidationValue = AssetValuationLib._calculateLiquidationValue(valuesAndRiskFactors);
    }
}

abstract contract AbstractAssetModuleExtension is AssetModule {
    constructor(address registry_, uint256 assetType_) AssetModule(registry_, assetType_) { }

    function getAssetFromKey(bytes32 key) public view returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public view returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }
}

abstract contract AbstractPrimaryAMExtension is PrimaryAM {
    constructor(address registry_, uint256 assetType_) PrimaryAM(registry_, assetType_) { }

    function setExposure(
        address creditor,
        address asset,
        uint256 assetId,
        uint112 lastExposureAsset,
        uint112 maxExposure
    ) public {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        riskParams[creditor][assetKey].lastExposureAsset = lastExposureAsset;
        riskParams[creditor][assetKey].maxExposure = maxExposure;
    }
}

abstract contract AbstractDerivedAMExtension is DerivedAM {
    constructor(address registry_, uint256 assetType_) DerivedAM(registry_, assetType_) { }

    function getAssetExposureLast(address creditor, bytes32 assetKey)
        external
        view
        returns (uint128 lastExposureAsset, uint128 lastUsdExposureAsset)
    {
        lastExposureAsset = lastExposuresAsset[creditor][assetKey].lastExposureAsset;
        lastUsdExposureAsset = lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset;
    }

    function getExposureAssetToUnderlyingAssetsLast(address creditor, bytes32 assetKey, bytes32 underlyingAssetKey)
        external
        view
        returns (uint256 exposureAssetToUnderlyingAssetsLast_)
    {
        exposureAssetToUnderlyingAssetsLast_ =
            lastExposureAssetToUnderlyingAsset[creditor][assetKey][underlyingAssetKey];
    }

    function setUsdExposureProtocol(address creditor, uint112 maxUsdExposureProtocol_, uint112 usdExposureProtocol_)
        public
    {
        riskParams[creditor].maxUsdExposureProtocol = maxUsdExposureProtocol_;
        riskParams[creditor].lastUsdExposureProtocol = usdExposureProtocol_;
    }

    function setAssetInformation(
        address creditor,
        address asset,
        uint256 assetId,
        address underLyingAsset,
        uint256 underlyingAssetId,
        uint112 exposureAssetLast,
        uint112 lastUsdExposureAsset,
        uint128 exposureAssetToUnderlyingAssetLast
    ) public {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        bytes32 underLyingAssetKey = _getKeyFromAsset(underLyingAsset, underlyingAssetId);
        lastExposuresAsset[creditor][assetKey].lastExposureAsset = exposureAssetLast;
        lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset = lastUsdExposureAsset;
        lastExposureAssetToUnderlyingAsset[creditor][assetKey][underLyingAssetKey] = exposureAssetToUnderlyingAssetLast;
    }

    function getRateUnderlyingAssetsToUsd(address creditor, bytes32[] memory underlyingAssetKeys)
        public
        view
        returns (AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);
    }

    function processDeposit(address creditor, bytes32 assetKey, uint256 exposureAsset)
        public
        returns (uint256 usdExposureAsset)
    {
        (, usdExposureAsset) = _processDeposit(exposureAsset, creditor, assetKey);
    }

    function getAndUpdateExposureAsset(address creditor, bytes32 assetKey, int256 deltaAsset)
        public
        returns (uint256 exposureAsset)
    {
        exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, deltaAsset);
    }

    function processWithdrawal(address creditor, bytes32 assetKey, uint256 exposureAsset)
        public
        returns (uint256 usdExposureAsset)
    {
        usdExposureAsset = _processWithdrawal(creditor, assetKey, exposureAsset);
    }

    function getAssetFromKey(bytes32 key) public view returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public view returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }
}

contract ERC20PrimaryAMExtension is ERC20PrimaryAM {
    constructor(address registry_) ERC20PrimaryAM(registry_) { }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function setExposure(address creditor, address asset, uint112 lastExposureAsset, uint112 maxExposure) public {
        bytes32 assetKey = _getKeyFromAsset(asset, 0);
        riskParams[creditor][assetKey].lastExposureAsset = lastExposureAsset;
        riskParams[creditor][assetKey].maxExposure = maxExposure;
    }
}

contract FloorERC721AMExtension is FloorERC721AM {
    constructor(address registry_) FloorERC721AM(registry_) { }

    function getIdRange(address asset) public view returns (uint256 start, uint256 end) {
        start = idRange[asset].start;
        end = idRange[asset].end;
    }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }
}

contract FloorERC1155AMExtension is FloorERC1155AM {
    constructor(address registry_) FloorERC1155AM(registry_) { }
}

contract UniswapV2AMExtension is UniswapV2AM {
    constructor(address registry_, address uniswapV2Factory_) UniswapV2AM(registry_, uniswapV2Factory_) { }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function getUniswapV2Factory() external view returns (address uniswapV2Factory) {
        uniswapV2Factory = UNISWAP_V2_FACTORY;
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssets) {
        return _getUnderlyingAssets(assetKey);
    }

    function getUnderlyingAssets(address asset) public view returns (address[] memory underlyingAssets) {
        underlyingAssets = new address[](2);

        bytes32 assetKey = _getKeyFromAsset(asset, 0);
        bytes32[] memory underlyingAssetKeys = assetToUnderlyingAssets[assetKey];
        (underlyingAssets[0],) = _getAssetFromKey(underlyingAssetKeys[0]);
        (underlyingAssets[1],) = _getAssetFromKey(underlyingAssetKeys[1]);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 exposureAsset,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (
            uint256[] memory exposureAssetToUnderlyingAssets,
            AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        )
    {
        (exposureAssetToUnderlyingAssets, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);
    }

    function getTrustedTokenAmounts(
        address pair,
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1,
        uint256 liquidityAmount
    ) public view returns (uint256 token0Amount, uint256 token1Amount) {
        (token0Amount, token1Amount) =
            _getTrustedTokenAmounts(pair, trustedPriceToken0, trustedPriceToken1, liquidityAmount);
    }

    function getTrustedReserves(address pair, uint256 trustedPriceToken0, uint256 trustedPriceToken1)
        public
        view
        returns (uint256 reserve0, uint256 reserve1)
    {
        (reserve0, reserve1) = _getTrustedReserves(pair, trustedPriceToken0, trustedPriceToken1);
    }

    function computeProfitMaximizingTrade(
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1,
        uint256 reserve0,
        uint256 reserve1
    ) public pure returns (bool token0ToToken1, uint256 amountIn) {
        (token0ToToken1, amountIn) =
            _computeProfitMaximizingTrade(trustedPriceToken0, trustedPriceToken1, reserve0, reserve1);
    }

    function computeTokenAmounts(
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply,
        uint256 liquidityAmount,
        uint256 kLast
    ) public view returns (uint256 token0Amount, uint256 token1Amount) {
        (token0Amount, token1Amount) = _computeTokenAmounts(reserve0, reserve1, totalSupply, liquidityAmount, kLast);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
    }
}

contract UniswapV3AMExtension is UniswapV3AM {
    constructor(address registry_, address nonfungiblePositionManager)
        UniswapV3AM(registry_, nonfungiblePositionManager)
    { }

    function getAssetExposureLast(address creditor, bytes32 assetKey)
        external
        view
        returns (uint128 lastExposureAsset, uint128 lastUsdExposureAsset)
    {
        lastExposureAsset = lastExposuresAsset[creditor][assetKey].lastExposureAsset;
        lastUsdExposureAsset = lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset;
    }

    function getExposureAssetToUnderlyingAssetsLast(address creditor, bytes32 assetKey, bytes32 underlyingAssetKey)
        external
        view
        returns (uint256 exposureAssetToUnderlyingAssetsLast_)
    {
        exposureAssetToUnderlyingAssetsLast_ =
            lastExposureAssetToUnderlyingAsset[creditor][assetKey][underlyingAssetKey];
    }

    function getNonFungiblePositionManager() public view returns (address nonFungiblePositionManager) {
        nonFungiblePositionManager = address(NON_FUNGIBLE_POSITION_MANAGER);
    }

    function getUniswapV3Factory() public view returns (address uniswapV3Factory) {
        uniswapV3Factory = UNISWAP_V3_FACTORY;
    }

    function getAssetToLiquidity(uint256 assetId) external view returns (uint256 liquidity) {
        liquidity = assetToLiquidity[assetId];
    }

    function addAsset(uint256 assetId) public {
        _addAsset(assetId);
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssets) {
        return _getUnderlyingAssets(assetKey);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 exposureAsset,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (
            uint256[] memory exposureAssetToUnderlyingAssets,
            AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        )
    {
        (exposureAssetToUnderlyingAssets, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);
    }

    function getPosition(uint256 assetId)
        public
        view
        returns (address token0, address token1, int24 tickLower, int24 tickUpper, uint128 liquidity)
    {
        return _getPosition(assetId);
    }

    function getPrincipalAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 usdPriceToken0,
        uint256 usdPriceToken1
    ) public pure returns (uint256 amount0, uint256 amount1) {
        return _getPrincipalAmounts(tickLower, tickUpper, liquidity, usdPriceToken0, usdPriceToken1);
    }

    function getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public pure returns (uint160 sqrtPriceX96) {
        return _getSqrtPriceX96(priceToken0, priceToken1);
    }

    function getFeeAmounts(uint256 id) public view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _getFeeAmounts(id);
    }

    function calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) public view returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}

contract ERC4626AMExtension is StandardERC4626AM {
    constructor(address registry_) StandardERC4626AM(registry_) { }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 exposureAsset,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (
            uint256[] memory exposureAssetToUnderlyingAssets,
            AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        )
    {
        (exposureAssetToUnderlyingAssets, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssets) {
        return _getUnderlyingAssets(assetKey);
    }
}

contract MultiCallExtension is ActionMultiCall {
    function assets() public view returns (address[] memory) {
        return mintedAssets;
    }

    function ids() public view returns (uint256[] memory) {
        return mintedIds;
    }

    function setMintedAssets(address[] memory mintedAssets_) public {
        mintedAssets = mintedAssets_;
    }

    function setMintedIds(uint256[] memory mintedIds_) public {
        mintedIds = mintedIds_;
    }
}

abstract contract StakingAMExtension is StakingAM {
    constructor(address registry, string memory name_, string memory symbol_) StakingAM(registry, name_, symbol_) { }

    function setLastRewardGlobal(address asset, uint128 balance) public {
        assetState[asset].lastRewardGlobal = balance;
    }

    function addAsset(address asset) public {
        _addAsset(asset);
    }

    function setAssetInPosition(address asset, uint96 tokenId) public {
        positionState[tokenId].asset = asset;
    }

    function setTotalStaked(address asset, uint128 totalStaked_) public {
        assetState[asset].totalStaked = totalStaked_;
    }

    function setLastRewardPerTokenGlobal(address asset, uint128 amount) public {
        assetState[asset].lastRewardPerTokenGlobal = amount;
    }

    function setLastRewardPosition(uint256 id, uint128 rewards_) public {
        positionState[id].lastRewardPosition = rewards_;
    }

    function setLastRewardPerTokenPosition(uint256 id, uint128 rewardPaid) public {
        positionState[id].lastRewardPerTokenPosition = rewardPaid;
    }

    function setAmountStakedForPosition(uint256 id, uint256 amount) public {
        positionState[id].amountStaked = uint128(amount);
    }

    function getIdCounter() public view returns (uint256 lastId_) {
        lastId_ = lastPositionId;
    }

    function setIdCounter(uint256 lastId_) public {
        lastPositionId = lastId_;
    }

    function setOwnerOfPositionId(address owner_, uint256 positionId) public {
        _ownerOf[positionId] = owner_;
    }

    function getRewardBalances(AssetState memory assetState_, PositionState memory positionState_)
        public
        view
        returns (AssetState memory, PositionState memory)
    {
        return _getRewardBalances(assetState_, positionState_);
    }

    function mintIdTo(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }

    function getAssetFromKey(bytes32 key) public view returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public view returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssetKeys) {
        underlyingAssetKeys = _getUnderlyingAssets(assetKey);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 assetAmount,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, assetAmount, underlyingAssetKeys);
    }

    function setTotalStakedForAsset(address asset, uint128 totalStaked_) public {
        assetState[asset].totalStaked = totalStaked_;
    }

    function calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) public view returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}

contract StargateAMExtension is StargateAM {
    constructor(address registry, address stargateFactory) StargateAM(registry, stargateFactory) { }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 exposureAsset,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (
            uint256[] memory exposureAssetToUnderlyingAssets,
            AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        )
    {
        (exposureAssetToUnderlyingAssets, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssets) {
        return _getUnderlyingAssets(assetKey);
    }

    function calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) public view returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}

contract StakedStargateAMExtension is StakedStargateAM {
    constructor(address registry, address stargateLpStaking_) StakedStargateAM(registry, stargateLpStaking_) { }

    function setAssetToPoolId(address asset, uint256 pid) public {
        assetToPid[asset] = pid;
    }

    function getCurrentReward(address asset) public view returns (uint256 currentReward) {
        currentReward = _getCurrentReward(asset);
    }

    function stake(address asset, uint256 amount) public {
        _stake(asset, amount);
    }

    function withdraw(address asset, uint256 amount) public {
        _withdraw(asset, amount);
    }

    function calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) public view returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}
