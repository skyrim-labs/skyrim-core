// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface ISkyrimToken {
    function mint(address recipient, uint256 amount) external;
    /**
     * @notice Security checks when setting Skyrim token, always expect to return true.
     */
    function isSkyrimToken() external returns (bool);
}
