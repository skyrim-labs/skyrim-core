// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../library/Ownable.sol";
import "../interface/IStrategy.sol";

contract LossStrategyMock is IStrategy, Ownable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    // using Address for address;
    using SafeMathUpgradeable for uint256;

    IERC20Upgradeable public underlying;
    address public vault;
    uint256 public balance;

    // These tokens cannot be claimed by the controller
    mapping (address => bool) public unsalvagableTokens;

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

    modifier restricted() {
        require(msg.sender == address(vault) || msg.sender == owner,
        "The sender has to be the controller or vault");
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
    function investAll() override public {
        // get rid of 10% forever
        uint256 contribution = underlying.balanceOf(address(this)).sub(balance);
        underlying.transfer(address(1), contribution.div(10));
        balance = underlying.balanceOf(address(this));
    }

    /*
    * Cashes everything out and withdraws to the vault
    */
    function redeemAll() override external restricted {
        underlying.safeTransfer(address(vault), underlying.balanceOf(address(this)));
        balance = underlying.balanceOf(address(this));
    }

    /*
    * Cashes some amount out and withdraws to the vault
    */
    function withdrawToVault(uint256 amount) external restricted {
        underlying.safeTransfer(address(vault), amount);
        balance = underlying.balanceOf(address(this));
    }

    /*
    * Honest harvesting. It's not much, but it pays off
    */
    function doHardWork() external onlyVault {
        // a no-op
        investAll();
    }
}