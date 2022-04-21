// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract BUSD is ERC20Upgradeable {
    constructor() {
        __ERC20_init("Binance USD", "BUSD");
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
