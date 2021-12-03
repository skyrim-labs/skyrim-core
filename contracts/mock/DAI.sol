// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract DAI is ERC20Upgradeable {
    constructor() {
        __ERC20_init("DAI Stable Coin", "DAI");
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
