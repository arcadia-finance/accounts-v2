// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03CLGaugeFactory {
    function leafVoter() external view returns (address leafVoter_);

    function nft() external view returns (address nft_);
}
