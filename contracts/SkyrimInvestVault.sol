// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "./SkyrimInvestVaultEvent.sol";
import "./library/SafeMathRatio.sol";
import "hardhat/console.sol";
contract SkyrimInvestVault is SkyrimInvestVaultEvent {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using SafeMathRatio for uint256;

    /**
     * @notice Expects to call this function only for one time.
     * @param investStartTime, time to start investing.
     * @param newSTToken, senior token to stake.
     * @param newJTToken, junior token to stake.
     */
    function initialize(
        uint256 investStartTime,
        ISeniorToken newSTToken,
        IJuniorToken newJTToken,
        ISkyrimToken newSkyrimToken,
        IERC20Upgradeable newInvestedToken
    ) public initializer {
        require(investStartTime >= block.timestamp, "initialize: Start time has expired!");
        startTime = investStartTime;

        currentState = PeriodState.None;

        STToken = newSTToken;
        JTToken = newJTToken;

        require(newSkyrimToken.isSkyrimToken(), "This is not a Skyrim token address!");
        SkyrimToken = newSkyrimToken;

        investedToken = newInvestedToken;

        burnedTimes[TokenType.isSeniorToken] = 0;
        burnedTimes[TokenType.isJuniorToken] = 0;

        investmentPricePerPeriod[TokenType.isSeniorToken] = BASE;
        investmentPricePerPeriod[TokenType.isJuniorToken] = BASE;

        __ReentrancyGuard_init();
        __Ownable_init();

        emit NewStartTime(0, investStartTime);
    }

    //-------------------------------
    //------- Internal Functions ----
    //-------------------------------

    /**
     * @dev Caller redeems share token in current price for the invested token.
     */
    function _redeemInternal(
        TokenType tokenType,
        address recipient,
        uint256 redeemShareTokenAmount,
        uint256 redeemUnderlyingAmount
    ) internal {
        require(
            redeemShareTokenAmount == 0 || redeemUnderlyingAmount == 0,
            "One of redeemShareTokenAmount or redeemUnderlyingAmount must be zero!"
        );

        uint256 actualRedeemInvestmentAmount;
        uint256 actualRedeemShareTokenAmount;

        uint256 currentInvestmentPrice = investmentPricePerPeriod[tokenType];

        if(redeemShareTokenAmount > 0) {
            /**
             * Get invested token price and calculate the amount of invested token
             * to be redeemed:
             *    actualRedeemShareTokenAmount = redeemShareTokenAmount
             *    actualRedeemInvestmentAmount = redeemShareTokenAmount * currentInvestmentPrice
             */
            actualRedeemShareTokenAmount = redeemShareTokenAmount;
            actualRedeemInvestmentAmount = redeemShareTokenAmount.rmul(currentInvestmentPrice);
        } else {
            /**
             * Get invested token price and calculate the amount to be redeemed:
             *  actualRedeemShareTokenAmount = redeemUnderlyingAmount / currentInvestmentPrice
             *  actualRedeemInvestmentAmount = redeemUnderlyingAmount
             */
            actualRedeemShareTokenAmount = redeemUnderlyingAmount.rdivup(currentInvestmentPrice);
            actualRedeemInvestmentAmount = redeemUnderlyingAmount;
        }

        uint256 maxRedeemAmount = getValidInvestmentAmount(tokenType, recipient);
        console.log("maxRedeemAmount %s", maxRedeemAmount);
        require(actualRedeemInvestmentAmount <= maxRedeemAmount, "Too much to redeem!");

        if (tokenType == TokenType.isSeniorToken) {
            IERC20Upgradeable(address(STToken)).safeTransfer(recipient, actualRedeemInvestmentAmount);
        } else if(tokenType == TokenType.isJuniorToken) {
            IERC20Upgradeable(address(JTToken)).safeTransfer(recipient, actualRedeemInvestmentAmount);
        }
        TotalInvestmentSnapshot storage totalInvestment = totalInvestmentsInfo[tokenType];
        totalInvestment.unlockedInvestment = totalInvestment.unlockedInvestment.sub(actualRedeemInvestmentAmount);
        totalInvestment.totalInvestmentByUsers = totalInvestment.totalInvestmentByUsers.sub(actualRedeemInvestmentAmount);
        totalInvestment.totalShare = totalInvestment.totalShare.sub(actualRedeemShareTokenAmount);

        // Update the balance of the share token.
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][recipient];
        userShareSnapshot.totalInvestAmount = userShareSnapshot.totalInvestAmount.sub(actualRedeemInvestmentAmount);
        userShareSnapshot.pendingShareBalance = userShareSnapshot.pendingShareBalance.sub(actualRedeemShareTokenAmount);

        emit RedeemInvestedToken(tokenType, recipient, actualRedeemShareTokenAmount, actualRedeemInvestmentAmount);
    }

    /**
     * @notice Must call this function after calling `_updateTRAReward` to update invested token TRA rewards.
     * @dev When user executes new action, such as: `invest`, `redeem` and `harvestTRARewards`,
     *      updates the user's share details to the latest state.
     */
    function _updateShareDetail(TokenType tokenType, address who, uint256 investAmount) internal {
        require(investAmount > 0, "updateShareDetail: investAmount must greater than 0");

        uint256 currentInvestmentPrice = getCurrentInvestmentPriceByToken(tokenType);
        uint256 investAmountShare = investAmount.rdiv(currentInvestmentPrice);
        console.log("currentInvestmentPrice %s", currentInvestmentPrice);
        console.log("investAmount           %s", investAmount);
        console.log("investAmountShare      %s", investAmountShare);

        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];
        userShareSnapshot.totalInvestAmount = userShareSnapshot.totalInvestAmount.add(investAmount);
        userShareSnapshot.pendingShareBalance = userShareSnapshot.pendingShareBalance.add(investAmountShare);
        userShareSnapshot.pendingInvestAmount = userShareSnapshot.pendingInvestAmount.add(investAmount);

        // Update pool info
        TotalInvestmentSnapshot storage totalInvestment = totalInvestmentsInfo[tokenType];
        totalInvestment.pendingInvestment = totalInvestment.pendingInvestment.add(investAmount);
        totalInvestment.totalInvestmentByUsers  = totalInvestment.totalInvestmentByUsers.add(investAmount);
        totalInvestment.totalShare = totalInvestment.totalShare.add(investAmountShare);
        console.log("totalInvestAmount      %s", userShareSnapshot.totalInvestAmount);
        console.log("pendingInvestment      %s", totalInvestment.pendingInvestment);

        emit Invest(tokenType, msg.sender, who, investAmount);
    }

    /**
     * @dev Calculates the accrued TRA amount and update.
     */
    function _updateTRAReward(TokenType tokenType, address who) internal {
        // Get the user's share details.
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];

        uint256 accruedTRA = getAccruedTRARewards(tokenType, who);
        console.log("accruedTRA %s", accruedTRA);
        if (accruedTRA > 0) {
            userShareSnapshot.TRARewards = userShareSnapshot.TRARewards.add(accruedTRA);
        }
        // Records current TRA price period.
        // userShareSnapshot.TRAPricePeriod = 1;
        emit RewardRepaid(tokenType, who, accruedTRA);
    }

    /**
     * @dev Invest senior tokens.
     */
    function _investST(address spender, address recipient, uint256 investAmount) internal {
        // Transfer ST token to invest.
        IERC20Upgradeable(address(STToken)).safeTransferFrom(spender, address(this), investAmount);

        // Should update user's investment share details.
        _updateShareDetail(TokenType.isSeniorToken, recipient, investAmount);
    }

    /**
     * @dev Invest junior tokens.
     */
    function _investJT(address spender, address recipient, uint256 investAmount) internal {
        // Transfer JT token to invest.
        IERC20Upgradeable(address(JTToken)).safeTransferFrom(spender, address(this), investAmount);

        // Should update user's investment share details.
        _updateShareDetail(TokenType.isJuniorToken, recipient, investAmount);
    }

    //---------------------------------
    //-------- Security Check ---------
    //---------------------------------

    /**
     * @notice Ensure this is a  Skyrim vault contract.
     */
    function isSkyrimVault() external pure returns (bool) {
        return true;
    }

    //-------------------------------
    //------- Users Functions -------
    //-------------------------------

    /**
     * @dev Invest senior token.
     * @param recipient, account to receive the ST share.
     * @param amount, amount of senior token to invest.
     */
    function investST(address recipient, uint256 amount) external nonReentrant {
        require(currentState == PeriodState.Ready, "investST: The investment is not in the subscription period");
        require(recipient != address(0), "investST: Recipient account can not be zero address!");
        require(amount != 0, "investST: Invest amount can not be zero!");
        require(block.timestamp >= startTime, "investST: Invest is not open!");
        harvestAllTRARewards();
        _investST(msg.sender, recipient, amount);
    }

    /**
     * @dev Invest junior token.
     * @param recipient, account to receive the JT share.
     * @param amount, amount of junior token to invest.
     */
    function investJT(address recipient, uint256 amount) external nonReentrant {
        require(currentState == PeriodState.Ready, "investJT: The investment is not in the subscription period");
        require(recipient != address(0), "investJT: Recipient account can not be zero address!");
        require(amount != 0, "investJT: Invest amount can not be zero!");
        require(block.timestamp >= startTime, "investJT: Invest is not open!");
        harvestAllTRARewards();
        _investJT(msg.sender, recipient, amount);
    }

    /**
     * @dev Get all TRA rewards and withdraw all invested token at the same time.
     */
    function exit(TokenType tokenType) external {
        require(currentState == PeriodState.End || currentState == PeriodState.Ready, "The investment is not over yet");
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][msg.sender];
        redeemInvestmentByShareToken(tokenType, userShareSnapshot.pendingShareBalance);
    }

    /**
     * @dev Caller gets all TRA rewards, including invest by ST and JT.
     */
    function harvestAllTRARewards() public {
        harvestTRARewards(TokenType.isSeniorToken);
        harvestTRARewards(TokenType.isJuniorToken);
    }

    /**
     * @dev Caller gets TRA rewards of investing ST or JT.
     */
    function harvestTRARewards(TokenType tokenType) public {
        address caller = msg.sender;

        _updateTRAReward(tokenType, caller);

        // Mint TRA rewars to caller.
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][caller];
        uint256 validTRARewards = userShareSnapshot.TRARewards;
        console.log("validTRARewards %s", validTRARewards);
        if (validTRARewards > 0) {
            SkyrimToken.mint(caller, validTRARewards);
            // Clear the TRA rewards.
            userShareSnapshot.TRARewards = 0;
        }
    }

    /**
     * @dev Redeem invested token by specified share token.
     */
    function redeemInvestmentByShareToken(TokenType tokenType, uint256 redeemShareTokenAmount) public nonReentrant {
        require(currentState == PeriodState.Ready || currentState == PeriodState.End, "can not redeem");
        harvestAllTRARewards();
        _redeemInternal(tokenType, msg.sender, redeemShareTokenAmount, 0);
    }

    /**
     * @dev Redeem specified invested token.
     */
    function redeemInvestment(TokenType tokenType, uint256 reddemInvestmeTokenAmount) public nonReentrant {
        require(currentState == PeriodState.Ready || currentState == PeriodState.End, "can not redeem");
        harvestAllTRARewards();
        _redeemInternal(tokenType, msg.sender, 0, reddemInvestmeTokenAmount);
    }

    struct ShareLocalVars {
        uint256 pendingInvestmentPrice;
        uint256 userBurnedTimes;
        uint256 userTRAPricePeriod;
        uint256 latestTRARate;
        uint256 shareTRAPrice;
        uint256 shareRewards;
        uint256 unlockedShareBalance;
        uint256 lockedShareBalance;
        uint256 lockedShareTRAPrice;
        uint256 lockedShareRewards;
        uint256 pendingShareBalance;
        uint256 pendingPeriod;
        uint256 pendingShareTRAPrice;
        uint256 pendingShareRewards;
    }

    /**
     * @dev Calculate the accrued TRA amount from user's last action time to now.
     *      User's total TRA rewards
     *             = TRA rewards of the unlocked share balance
     *               + TRA rewards of the locked share balance
     *               + TRA rewards of the pending invest balance
     */
    function getAccruedTRARewards(TokenType tokenType, address who) public view returns (uint256 rewards) {
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];

        ShareLocalVars memory _vars;
        _vars.userBurnedTimes = userShareSnapshot.burnedTimes;
        _vars.pendingPeriod = userShareSnapshot.pendingSharePeriod;
        _vars.pendingShareBalance = getUserValidPendingShareAmount(tokenType, who);
        _vars.lockedShareBalance = getUserValidLockedShareAmount(tokenType, who);
        _vars.unlockedShareBalance = getUserValidUnlockShareAmount(tokenType, who);

        // User has not invested any token of this `tokenType`.
        if (_vars.unlockedShareBalance == 0 && _vars.lockedShareBalance == 0 && _vars.pendingShareBalance == 0) {
            return 0;
        }
        
        if (hasBurnedAll(tokenType, who)) {
            // Has lost all invested token.
            _vars.latestTRARate = burnedTRARate[tokenType][_vars.userBurnedTimes];
        } else {
            _vars.latestTRARate = TRAPricePerPeriod[tokenType];
        }
        console.log("_vars.latestTRARate %s", _vars.latestTRARate);
        // Calculate TRA rewards based on unlocked share amount and its share period.
        if (_vars.unlockedShareBalance > 0) {
            // _vars.userTRAPricePeriod = userShareSnapshot.TRAPricePeriod;
            // _vars.shareTRAPrice = TRAPricePerPeriod[tokenType];
            _vars.shareRewards = _vars.unlockedShareBalance.rmul(_vars.latestTRARate);
            rewards = rewards.add(_vars.shareRewards);
            console.log("_vars.unlockedShareBalance %s", _vars.unlockedShareBalance);
            console.log("_vars.latestTRARate %s", _vars.latestTRARate);
            console.log("_vars.shareTRAPrice %s", _vars.shareTRAPrice);
            console.log("_vars.shareRewards %s",  _vars.shareRewards);
            console.log("rewards %s", rewards);
        }
    }

    /**
     * @notice Total TRA rewards including user has accrued rewards at the last action time and
     *         the accrued TRA amount from user's last action time to now.
     * @dev User's total TRA rewards
     *             = userHasAccruedRewards + calculatedAccruedRewards
     *             = userShareSnapshot.TRARewards + getAccruedTRARewards(tokenType, who)
     */
    function getUserTotalTRARewards(TokenType tokenType, address who) external view returns (uint256 rewards) {
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];
        uint256 accruedTRARewards = getAccruedTRARewards(tokenType, who);
        rewards = accruedTRARewards.add(userShareSnapshot.TRARewards);
    }

    /**
     * @dev Calculate current investment price for token.
     */
    function getCurrentInvestmentPriceByToken(TokenType _tokenType) public view returns (uint256) {
        return investmentPricePerPeriod[_tokenType];
    }

    /**
     * @dev Get how many periods passed after user did last investment by token.
     */
    function getUserPeriodsAfterInvestment(
        TokenType tokenType,
        address who
    ) public view returns (uint256) {
        return 2;
    }

    /**
     * @dev If user invested multiple times, shares will stay in their own period.
     */
    function shouldUnlockNoneShares(
        TokenType tokenType,
        address who
    ) public view returns (bool) {
        return getUserPeriodsAfterInvestment(tokenType, who) == 0;
    }

    /**
     * @dev 1 period passed, pending => locked, locked => unlocked
     */
    function shouldUnlockUserLockedShares(
        TokenType tokenType,
        address who
    ) public view returns (bool) {
        return getUserPeriodsAfterInvestment(tokenType, who) == 1;
    }

    /**
     * @dev 2+ periods passed, pending => unlocked, locked => unlocked
     */
    function shouldUnlockAllUserShares(
        TokenType tokenType,
        address who
    ) public view returns (bool) {
        return getUserPeriodsAfterInvestment(tokenType, who) > 1;
    }

    function getUserValidPendingShareAmount(
        TokenType tokenType,
        address who
    ) public view returns (uint256) {
        if (hasBurnedAll(tokenType, who)) {
            return 0;
        }

        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];

        if (shouldUnlockNoneShares(tokenType, who)) {
            return userShareSnapshot.pendingShareBalance;
        }

        return 0;
    }

    function getUserValidLockedShareAmount(
        TokenType tokenType,
        address who
    ) public view returns (uint256 validShareAmount) {
        if (hasBurnedAll(tokenType, who)) {
            return 0;
        }

        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];

        if (shouldUnlockNoneShares(tokenType, who)) {
            return userShareSnapshot.lockedShareBalance;
        }

        if (shouldUnlockUserLockedShares(tokenType, who)) {
            return userShareSnapshot.pendingShareBalance;
        }

        return 0;
    }

    function getUserValidUnlockShareAmount(
        TokenType tokenType,
        address who
    ) public view returns (uint256 validShareAmount) {
        if (hasBurnedAll(tokenType, who)) {
            return 0;
        }

        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];

        console.log("userShareSnapshot.unlockedShareBalance %s", userShareSnapshot.unlockedShareBalance);
        console.log("userShareSnapshot.lockedShareBalance %s", userShareSnapshot.lockedShareBalance);
        console.log("userShareSnapshot.pendingShareBalance %s", userShareSnapshot.pendingShareBalance);

        // if (shouldUnlockNoneShares(tokenType, who)) {
        //     return userShareSnapshot.unlockedShareBalance;
        // }

        // if (shouldUnlockUserLockedShares(tokenType, who)) {
        //     return userShareSnapshot.unlockedShareBalance.add(userShareSnapshot.lockedShareBalance);
        // }

        if (currentState == PeriodState.End) {
            return userShareSnapshot.unlockedShareBalance.add(userShareSnapshot.lockedShareBalance).add(userShareSnapshot.pendingShareBalance);
        }

        return 0;
    }

    /**
     * @notice Only unlocked share can be withdrawn.
     * @dev Calculate how many senior token that a user can withdraw now and whether he has
     *      locked share token.
     */
    function getValidInvestmentAmount(
        TokenType tokenType,
        address who
    ) public view returns (uint256 validInvestmentAmount) {
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];
        uint256 shareAmount = userShareSnapshot.pendingShareBalance;
        uint256 sharePrice = getCurrentInvestmentPriceByToken(tokenType);

        // Calculate amount: valid share amount * price.
        return shareAmount.rmul(sharePrice);
    }

    /**
     * @notice Only unlocked share can be withdrawn.
     * @dev Calculate how many token that a user can withdraw now and whether he has
     *      locked share token.
     */
    function getTotalInvestmentShareAmount(
        TokenType tokenType,
        address who
    ) public view returns (uint256 validInvestmentAmount) {
        if (hasBurnedAll(tokenType, who)) {
            return 0;
        }

        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];

        // Calculate amount: valid share amount * price.
        return userShareSnapshot.pendingShareBalance.add(userShareSnapshot.lockedShareBalance).add(userShareSnapshot.unlockedShareBalance);
    }

    /**
     * @notice Only unlocked share can be withdrawn.
     * @dev Calculate how many token that a user can withdraw now and whether he has
     *      locked share token.
     */
    function getTotalInvestmentAmount(
        TokenType tokenType,
        address who
    ) public view returns (uint256 validInvestmentAmount) {
        uint256 shareAmount = getTotalInvestmentShareAmount(tokenType, who);
        uint256 sharePrice = getCurrentInvestmentPriceByToken(tokenType);

        // Calculate amount: valid share amount * price.
        return shareAmount.rmul(sharePrice);
    }

    /**
     * @dev Whether the user has lost all invested token.
     */
    function hasBurnedAll(TokenType tokenType, address who) public view returns (bool burnedAll) {
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];

        uint256 userBurnedTimes = userShareSnapshot.burnedTimes;

        if (userBurnedTimes < burnedTimes[tokenType]) {
            // Has lost all invested ST/JT token.
            burnedAll = true;
        } else {
            burnedAll = false;
        }
    }

    function getAPY(TokenType _tokenType) external view returns(uint256) {
        return APYs[_tokenType];
    }
}
