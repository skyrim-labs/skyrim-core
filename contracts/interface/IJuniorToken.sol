// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface IJuniorToken {
    /**
     * @notice Security checks when setting junior token, always expect to return true.
     */
    function isJuniorToken() external returns (bool);
    function withdrawUnderlyingToVault(uint256 amount) external;
    function vaultBurnLoss(uint256 amount) external;
}
