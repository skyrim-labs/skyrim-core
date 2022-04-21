// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./library/Ownable.sol";

contract SkyrimToken is
    Initializable,
    ReentrancyGuardUpgradeable,
    Ownable,
    ERC20Upgradeable
{
    // Whether the caller is a minter or not.
    mapping(address => bool) public isMinter;

    //--------------------------
    //-------- Events ----------
    //--------------------------
    event Mint(address indexed to, uint256 indexed amount);

    event AddMinter(address indexed newMinter);
    event RemoveMinter(address indexed oldMinter);

    /**
     * @notice Expects to call this function only for one time.
     * @dev Initialize contracts and do the initial distribution.
     */
    function initialize(address recipient, uint256 initialSupply) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        __ERC20_init("SkyrimToken", "SKYRIM");

        _mint(recipient, initialSupply);

        emit Mint(recipient, initialSupply);
    }

    //---------------------------------
    //-------- Security Check ---------
    //---------------------------------

    /**
     * @notice Ensure this is a Skyrim token contract.
     */
    function isSkyrimToken() external pure returns (bool) {
        return true;
    }

    //---------------------------------
    //-------- Admin functions --------
    //---------------------------------
    function addMinter(address newMinter) external onlyOwner {
        require(newMinter != address(0), "addMinter: New minter can not be zero address!");
        require(!isMinter[newMinter], "addMinter: Account is already a minter!");

        isMinter[newMinter] = true;

        emit AddMinter(newMinter);
    }

    function removeMinter(address minter) external onlyOwner {
        require(isMinter[minter], "removeMinter: Account is not a minter!");

        isMinter[minter] = false;

        emit RemoveMinter(minter);
    }

    //-----------------------------------
    //------- Authority functions -------
    //-----------------------------------
    /**
     * @dev Mints `amount` SkyrimToken to `recipient`.
     * @param recipient, the account to receive the minted Skyrim token.
     * @param amount, the amount of Skyrim token to mint.
     */
    function mint(address recipient, uint256 amount) external nonReentrant {
        address caller = msg.sender;
        require(isMinter[caller], "mint: Caller is not a minter!");
        _mint(recipient, amount);

        emit Mint(recipient, amount);
    }

    uint256[50] private __gap;
}


