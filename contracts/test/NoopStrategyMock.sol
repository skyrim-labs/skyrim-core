// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../library/Ownable.sol";
import "../interface/IStrategy.sol";

contract NoopStrategyMock {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    // using Address for address;
    using SafeMathUpgradeable for uint256;

    IERC20Upgradeable public underlying;
    address public vault;

    bool public withdrawAllCalled = false;

    constructor(address _underlying, address _vault) payable {
        require(_underlying != address(0), "_underlying cannot be empty");
        require(_vault != address(0), "_vault cannot be empty");
        underlying = IERC20Upgradeable(_underlying);
        vault = _vault;
    }

    modifier onlyVault() {
        require(msg.sender == address(vault), "The caller must be the vault");
        _;
    }

    /*
    * Returns the total invested amount.
    */
    function investedUnderlyingBalance() view public returns (uint256) {
        // for real strategies, need to calculate the invested balance
        return underlying.balanceOf(address(this));
    }

    /*
    * Invests all tokens that were accumulated so far
    */
    function investAll() public {
    }

    /*
    * Cashes everything out and withdraws to the vault
    */
    function redeemAll() external onlyVault {
        withdrawAllCalled = true;
        if (underlying.balanceOf(address(this)) > 0) {
            underlying.safeTransfer(address(vault), underlying.balanceOf(address(this)));
        }
    }

    /*
    * Cashes some amount out and withdraws to the vault
    */
    function withdrawToVault(uint256 amount) external onlyVault {
        if (amount > 0) {
        underlying.safeTransfer(address(vault), amount);
        }
    }

    /*
    * Honest harvesting. It's not much, but it pays off
    */
    function doHardWork() external onlyVault {
        // a no-op
    }
}