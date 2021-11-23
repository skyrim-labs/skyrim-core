//SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

library SafeMathRatio {
    using SafeMathUpgradeable for uint256;

    uint256 private constant BASE = 10**18;
    uint256 private constant DOUBLE = 10**36;

    function divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.add(y.sub(1)).div(y);
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(y).div(BASE);
    }

    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(BASE).div(y);
    }

    function rdivup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(BASE).add(y.sub(1)).div(y);
    }
}

