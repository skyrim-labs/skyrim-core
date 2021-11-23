// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interface/ISkyrimInvestVault.sol";
import "./library/Ownable.sol";

contract SeniorToken is
    Initializable,
    ReentrancyGuardUpgradeable,
    Ownable,
    ERC20Upgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Underlying token.
    IERC20Upgradeable public underlyingToken;

    // Whether the vault address is valid or not.
    mapping(address => bool) public isVault;

    //--------------------------
    //-------- Events ----------
    //--------------------------
    event Mint(
        address indexed spender,
        address indexed recipient,
        uint256 indexed amount
    );
    event Burn(address indexed burner, address indexed recipient, uint256 indexed amount);

    event AddVault(ISkyrimInvestVault indexed newVaultAddress);
    event RemoveVault(ISkyrimInvestVault indexed oldVaultAddress);

    /**
     * @notice Expects to call this function only for one time.
     * @param underlying, underlying token to mint this junior token.
     */
    function initialize(address underlying) external initializer {
        underlyingToken = IERC20Upgradeable(underlying);

        __ReentrancyGuard_init();
        __Ownable_init();
        __ERC20_init("SeniorToken", "ST");
    }

    //---------------------------------
    //-------- Security Check ---------
    //---------------------------------

    /**
     * @notice Ensure this is a senior token contract.
     */
    function isSeniorToken() external pure returns (bool) {
        return true;
    }

    //---------------------------------
    //-------- Admin Functions --------
    //---------------------------------
    /**
     * @notice Before setting a new vault, should delete the ols one.
     * @dev Set a new vault contract.
     */
    function setVault(ISkyrimInvestVault newVaultAddress) external onlyOwner {
        require(newVaultAddress.isSkyrimVault(), "setVault: This is not a vault contract address!");
        isVault[address(newVaultAddress)] = true;

        emit AddVault(newVaultAddress);
    }

    /**
     * @dev Delete the old vault contract.
     */
    function deleteVault(ISkyrimInvestVault oldVaultAddress) external onlyOwner {
        require(oldVaultAddress.isSkyrimVault(), "setVault: This is not a vault contract address!");
        isVault[address(oldVaultAddress)] = false;

        emit RemoveVault(oldVaultAddress);
    }

    /**
     * @dev Withdraw underlying token to the vault to invest.
     */
    function withdrawUnderlyingToVault(uint256 amount) external nonReentrant {
        address caller = msg.sender;
        require(isVault[caller], "withdrawUnderlyingToVault: Only for the vault contract!");

        underlyingToken.safeTransfer(caller, amount);
    }

    /**
     * @dev Burn senior token due to loss.
     */
    function vaultBurnLoss(uint256 amount) external nonReentrant{
        address caller = msg.sender;
        require(isVault[caller], "vaultBurnLoss: Only for the vault contract!");

        _burn(caller, amount);
    }

    //---------------------------------
    //-------- User Functions ---------
    //---------------------------------

    /**
     * @dev Deposits underlying token to mint junior token.
     * @param recipient,the account to receive the minted junior token.
     * @param amount, the amount of underlying token to deposit.
     */
    function mint(address recipient, uint256 amount) external nonReentrant {
        address minter = msg.sender;
        _mint(recipient, amount);
        underlyingToken.safeTransferFrom(minter, address(this), amount);

        emit Mint(minter, recipient, amount);
    }

    /**
     * @dev Burns junior token to get underlying token.
     * @param amount, the amount of junior token to burn.
     */
    function burn(uint256 amount) external nonReentrant {
        address burner = msg.sender;
        _burn(burner, amount);
        underlyingToken.safeTransfer(burner, amount);

        emit Burn(burner, burner, amount);
    }

    /**
     * @dev Destroys `amount` senior tokens from `spender`, deducting from the caller's
     *      allowance.
     */
    function burnFrom(address spender, uint256 amount) external nonReentrant {
        address caller = msg.sender;
        uint256 decreasedAllowance = allowance(spender, caller).sub(amount, "burnFrom: Burn amount exceeds allowance!");

        _approve(spender, caller, decreasedAllowance);
        _burn(spender, amount);
        underlyingToken.safeTransfer(caller, amount);

        emit Burn(spender, caller, amount);
    }

    uint256[50] private __gap;
}
