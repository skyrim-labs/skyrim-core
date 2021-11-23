// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface ISeniorToken {
    /**
     * @notice Security checks when setting the senior token, always expect to return true.
     */
    function isSeniorToken() external returns (bool);
    function withdrawUnderlyingToVault(uint256 amount) external;
    function vaultBurnLoss(uint256 amount) external;
}
