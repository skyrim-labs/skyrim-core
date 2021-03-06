// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.8.0;

interface IStrategy {
    
    // function unsalvagableTokens(address tokens) external view returns (bool);
    
    // function governance() external view returns (address);
    // function controller() external view returns (address);
    // function underlying() external view returns (address);
    // function vault() external view returns (address);

    // function withdrawAllToVault() external;
    // function withdrawToVault(uint256 amount) external;

    function investAll() external;
    function redeemAll() external;
    // should only be called by controller
    // function salvage(address recipient, address token, uint256 amount) external;

    // function doHardWork() external;
    // function depositArbCheck() external view returns(bool);
}