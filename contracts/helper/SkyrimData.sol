// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../interface/ISkyrimInvestVault.sol";


library SafeMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "math add overflow");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "math sub underflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "math mul overflow");
    }

    function div(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y > 0, "math div overflow");
        z = x / y;
    }
}


library SafeMathRatio {
    using SafeMath for uint256;

    uint256 private constant BASE = 10**18;
    uint256 private constant DOUBLE = 10**36;

    function divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.add(y.sub(1)).div(y);
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(y).div(BASE);
    }

    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(BASE).div(y);
    }

    function rdivup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(BASE).add(y.sub(1)).div(y);
    }
}


contract SkyrimData {
    using SafeMath for uint256;
    using SafeMathRatio for uint256;

    ISkyrimInvestVault public vault;
    constructor (ISkyrimInvestVault SkyrimVault) {
        require(SkyrimVault.isSkyrimVault(), "SkyrimData: Not a Skyrim vault contract!");
        vault = SkyrimVault;
    }

    /**
     * @dev Total investments by users with ST Token.
     */
    function totalInvestByST() public view returns (uint256 totalSTInvestedAmount) {
        (,,totalSTInvestedAmount,,) = vault.totalInvestmentsInfo(0);
    }

    /**
     * @dev Total investments by users with JT Token.
     */
    function totalInvestByJT() public view returns (uint256 totalJTInvestedAmount) {
        (,,totalJTInvestedAmount,,) = vault.totalInvestmentsInfo(1);
    }

    /**
     * @dev Total investments by users, including ST Token and JT Token.
     */
    function totalInvest() external view returns (uint256 total) {
        // Total investments by users with ST Token.
        total = total.add(totalInvestByST());
        // Total investments by users with JT Token.
        total = total.add(totalInvestByJT());
    }

    /**
     * @dev Invested ST Token amount by users.
     */
    function investAmountByST(address who) external view returns (uint256 STInvestedAmount) {
        (,,,,,,STInvestedAmount,,) = vault.accountInvestments(0, who);
    }

    /**
     * @dev Invested JT Token amount by users.
     */
    function investAmountByJT(address who) external view returns (uint256 JTInvestedAmount) {
        (,,,,,,JTInvestedAmount,,) = vault.accountInvestments(1, who);
    }

    /**
     * @notice Total TRA rewards including user has accrued rewards at the last action time and
     *         the accrued TRA amount from user's last action time to now.
     * @dev User's total TRA rewards
     *             = userHasAccruedRewards + calculatedAccruedRewards
     *             = userShareSnapshot.TRARewards + getAccruedTRARewards(tokenType, who)
     */
    function getUserTotalTRARewards(uint256 tokenType, address who) external view returns (uint256 rewards) {
        uint256 userTRARewards;
        (,,,,,,,userTRARewards,) = vault.accountInvestments(tokenType, who);

        uint256 accruedTRARewards = vault.getAccruedTRARewards(tokenType, who);

        rewards = accruedTRARewards.add(userTRARewards);
    }

    function getCurrentTime() external view returns(uint256) {
        return block.timestamp;
    }

    function remainningTime() external view returns(uint256) {
        uint256 currentPeriod = vault.getCurrentPeriod();
        uint256 lockTime = vault.lockTime();
        uint256 startTime = vault.startTime();
        if (currentPeriod > vault.period()) {
            return 0;
        }
        return lockTime - (block.timestamp - startTime) % lockTime;
    }

    /**
     * @dev Get current senior token supply rate.
     */
    function getCurrentSTSupplyRate() external view returns (uint256) {
        return vault.seniorTokenSupplyRate();
    }

    /**
     * @dev Get current junior token supply rate.
     */
    function getCurrentJTSupplyRate() external view returns (uint256 JTSupplyRate) {
        uint256 currentPeriod = vault.getCurrentPeriod();
        JTSupplyRate = vault.JTSupplyRatesPerPeriod(currentPeriod);
    }
}

