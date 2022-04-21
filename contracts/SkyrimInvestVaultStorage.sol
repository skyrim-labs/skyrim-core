// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interface/ISkyrimToken.sol";
import "./interface/IJuniorToken.sol";
import "./interface/ISeniorToken.sol";
import "./library/Ownable.sol";

/**
 * @title Skyrim invest vault storage contract.
 */
contract SkyrimInvestVaultStorage is
    Initializable,
    ReentrancyGuardUpgradeable,
    Ownable
{
    uint256 public constant BASE = 10**18;
    // Start time of the investing.
    uint256 public startTime;

    enum TokenType {
        isSeniorToken,
        isJuniorToken
    }

    // Senior token.
    ISeniorToken public STToken;

    // Exchange ratio of invested Token and invested Share per period.
    mapping(TokenType => mapping(uint256 => uint256)) public investmentPricePerPeriod;
    // Exchange ratio of invested Share and invested TRA per period.
    mapping(TokenType => mapping(uint256 => uint256)) public TRAPricePerPeriod;

    uint256 internal currentPeriod;
    uint256 public totalTRARewards;

    struct TotalInvestmentSnapshot {
        // In a new investing round, total amount of pending investment.
        uint256 pendingInvestment;
        // In the last investing round, total amount of locked investment.
        uint256 lockedInvestment;
        // In the last investing round, total amount of unlocked investment.
        uint256 unlockedInvestment;
        // Total share amount that users have invested.
        uint256 totalShare;
        // Total amount that users have invested.
        uint256 totalInvestmentByUsers;
    }
    mapping(TokenType => TotalInvestmentSnapshot) public totalInvestmentsInfo;

    // Supply interest rates per period
    mapping(uint256 => uint256) public JTSupplyRatesPerPeriod;
    uint256 public seniorTokenSupplyRate;


    // Times that losts all invested token.
    mapping(TokenType => uint256) public APYs;
    uint256 public constant APYRatio = 10000;

    // Times that losts all invested token.
    mapping(TokenType => uint256) public burnedTimes;
    // When loss all invested token, records the `TRARatePerSTShare` at that time.
    mapping(TokenType => mapping(uint256 => uint256)) public burnedTRARate;

    struct AccountShareSnapshot {
        uint256 unlockedShareBalance; // Total unlocked share balance
        uint256 pendingShareBalance; // Total pending share balance
        uint256 TRAPricePeriod; // Period of TRA rate when the user executed
        uint256 lockedShareBalance; // share amount that be locked
        uint256 pendingSharePeriod; // Period of pending invested
        uint256 lockedSharePeriod; // Period of locked share
        uint256 pendingInvestAmount; // Pending to invest
        uint256 totalInvestAmount;  // Total invested amount by user
        uint256 TRARewards; // Accrued TRA rewards
        uint256 burnedTimes; // Times of lossing all token
    }
    // Details about user's investment.
    mapping(TokenType => mapping(address => AccountShareSnapshot))
        public accountInvestments;

    // Junior token.
    IJuniorToken public JTToken;

    // Skyrim token.
    ISkyrimToken public SkyrimToken;

    // Invest token
    IERC20Upgradeable public investedToken;
}
