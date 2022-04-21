// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "./SkyrimInvestVaultEvent.sol";
import "./library/SafeMathRatio.sol";

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
        emit NewStartTime(0, investStartTime);

        currentPeriod = 1;

        _setSeniorToken(newSTToken);
        _setJuniorToken(newJTToken);
        _setSkyrimToken(newSkyrimToken);

        investedToken = newInvestedToken;

        burnedTimes[TokenType.isSeniorToken] = 0;
        burnedTimes[TokenType.isJuniorToken] = 3;

        investmentPricePerPeriod[TokenType.isSeniorToken][0] = BASE;
        investmentPricePerPeriod[TokenType.isJuniorToken][0] = BASE;

        __ReentrancyGuard_init();
        __Ownable_init();
    }

    //-------------------------------
    //----- Internal Functions ------
    //-------------------------------

    /**
     * @dev Sets a new senior token.
     */
    function _setSeniorToken(ISeniorToken newSTToken) internal {
        require(newSTToken.isSeniorToken(), "_setSeniorToken: This is not a senior token address!");
        // Gets old senior token.
        ISeniorToken oldSTToken = STToken;
        // Sets new senior token.
        STToken = newSTToken;

        emit NewSTToken(oldSTToken, newSTToken);
    }

    /**
     * @dev Sets a new junior token.
     */
    function _setJuniorToken(IJuniorToken newJTToken) internal {
        require(newJTToken.isJuniorToken(), "_setJuniorToken: This is not a junior token address!");
        // Gets old junior token.
        IJuniorToken oldJTToken = JTToken;
        // Sets new junior token.
        JTToken = newJTToken;

        emit NewJTToken(oldJTToken, newJTToken);
    }

    /**
     * @dev Sets a new Skyrim token.
     */
    function _setSkyrimToken(ISkyrimToken newSkyrimToken) internal {
        require(newSkyrimToken.isSkyrimToken(), "_setSkyrimToken: This is not a Skyrim token address!");
        // Gets old Skyrim token.
        ISkyrimToken oldJTToken = SkyrimToken;
        // Sets new Skyrim token.
        SkyrimToken = newSkyrimToken;

        emit NewSkyrimToken(oldJTToken, newSkyrimToken);
    }

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
            "_redeemInternal: One of redeemShareTokenAmount or redeemUnderlyingAmount must be zero!"
        );

        uint256 actualRedeemInvestmentAmount;
        uint256 actualRedeemShareTokenAmount;

        TotalInvestmentSnapshot storage totalInvestment = totalInvestmentsInfo[tokenType];

        uint256 currentInvestmentPrice = investmentPricePerPeriod[tokenType][currentPeriod.sub(1)];

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
        require(actualRedeemInvestmentAmount <= maxRedeemAmount, "_redeemInternal: Too much to redeem!");

        // Update the balance of the share token.
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][recipient];

        if (tokenType == TokenType.isSeniorToken) {
            IERC20Upgradeable(address(STToken)).safeTransfer(recipient, actualRedeemInvestmentAmount);
        } else if(tokenType == TokenType.isJuniorToken) {
            IERC20Upgradeable(address(JTToken)).safeTransfer(recipient, actualRedeemInvestmentAmount);
        }
        totalInvestment.unlockedInvestment = totalInvestment.unlockedInvestment.sub(actualRedeemInvestmentAmount);
        totalInvestment.totalInvestmentByUsers = totalInvestment.totalInvestmentByUsers.sub(actualRedeemInvestmentAmount);
        totalInvestment.totalShare = totalInvestment.totalShare.sub(actualRedeemShareTokenAmount);

        userShareSnapshot.totalInvestAmount = userShareSnapshot.totalInvestAmount.sub(actualRedeemInvestmentAmount);
        userShareSnapshot.unlockedShareBalance = userShareSnapshot.unlockedShareBalance.sub(actualRedeemShareTokenAmount);

        emit RedeemInvestedToken(tokenType, recipient, actualRedeemShareTokenAmount, actualRedeemInvestmentAmount);
    }

    /**
     * @notice Must call this function after calling `_updateTRAReward` to update invested token TRA rewards.
     * @dev When user executes new action, such as: `invest`, `redeem` and `harvestTRARewards`,
     *      updates the user's share details to the latest state.
     */
    function _updateShareDetail(TokenType tokenType, address who, uint256 investAmount) internal {
        require(investAmount > 0, "_updateShareDetail: investAmount must greater than 0");

        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];
        TotalInvestmentSnapshot storage totalInvestment = totalInvestmentsInfo[tokenType];
        uint256 currentBurnedTimes = burnedTimes[tokenType];
        uint256 currentInvestmentPrice = getCurrentInvestmentPriceByToken(tokenType);
        uint256 investAmountShare = investAmount.rdiv(currentInvestmentPrice);

        if(userShareSnapshot.burnedTimes < currentBurnedTimes) {
            // TODO: Should effect `totalInvestment`
            // Has lost all investments.
            userShareSnapshot.pendingInvestAmount = 0;
            userShareSnapshot.lockedShareBalance = 0;
            userShareSnapshot.pendingShareBalance = 0;
            userShareSnapshot.unlockedShareBalance = 0;
            // Records current burned times.
            userShareSnapshot.burnedTimes = currentBurnedTimes;
        }

        totalInvestment.pendingInvestment = totalInvestment.pendingInvestment.add(investAmount);
        totalInvestment.totalInvestmentByUsers  = totalInvestment.totalInvestmentByUsers.add(investAmount);
        totalInvestment.totalShare = totalInvestment.totalShare.add(investAmountShare);

        userShareSnapshot.totalInvestAmount = userShareSnapshot.totalInvestAmount.add(investAmount);

        emit Invest(tokenType, msg.sender, who, investAmount);

        // This is the first time that user invests.
        if (userShareSnapshot.pendingSharePeriod == 0) {
            // update share amount
            userShareSnapshot.pendingShareBalance = investAmountShare;
            // todo: lock for 1 day instead of 1 period
            userShareSnapshot.pendingSharePeriod = currentPeriod;
            userShareSnapshot.lockedSharePeriod = currentPeriod.add(1);
            userShareSnapshot.pendingInvestAmount = investAmount;
            // Records current burned times.
            userShareSnapshot.burnedTimes = currentBurnedTimes;
            // Records current TRA price period.
            userShareSnapshot.TRAPricePeriod = currentPeriod.sub(1);
            return;
        }

        // 2nd investment from user
        if (userShareSnapshot.pendingSharePeriod == currentPeriod) {
            // update share amount
            userShareSnapshot.pendingShareBalance = userShareSnapshot.pendingShareBalance.add(investAmountShare);
            // Additional funds from users at the same day.
            userShareSnapshot.pendingInvestAmount = userShareSnapshot.pendingInvestAmount.add(investAmount);
            // Records current TRA price period.
            userShareSnapshot.TRAPricePeriod = currentPeriod.sub(1);
            return;
        }

        // Unlock user's token if currentPeriod > userShareSnapshot.pendingSharePeriod
        if (userShareSnapshot.pendingSharePeriod < currentPeriod) {
            // Invested at latest period
            if (userShareSnapshot.pendingSharePeriod == currentPeriod.sub(1)) {
                // Pending investment is under locked period.
                userShareSnapshot.unlockedShareBalance = userShareSnapshot.unlockedShareBalance.add(userShareSnapshot.lockedShareBalance);
                userShareSnapshot.lockedShareBalance = userShareSnapshot.pendingShareBalance;
            } else {
                // Invested very early. Share locked time has passed.
                userShareSnapshot.unlockedShareBalance = userShareSnapshot.unlockedShareBalance.add(userShareSnapshot.lockedShareBalance).add(userShareSnapshot.pendingShareBalance);
                userShareSnapshot.lockedShareBalance = 0;
            }
            // Updates user's pending invested token amount.
            userShareSnapshot.pendingShareBalance = investAmountShare;
            userShareSnapshot.pendingSharePeriod = currentPeriod;
            userShareSnapshot.lockedSharePeriod = currentPeriod.add(1);
            userShareSnapshot.pendingInvestAmount = investAmount;
        }
    }

    /**
     * @notice Callable anytime.
     * @dev When 2 periods are passed, all investments from user will be unlocked,
     *      user this method to update user's share value.
     */
    function _rebalanceUserShare(TokenType tokenType, address who) internal {
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];
        TotalInvestmentSnapshot storage totalInvestment = totalInvestmentsInfo[tokenType];
        uint256 currentBurnedTimes = burnedTimes[tokenType];

        if(userShareSnapshot.burnedTimes < currentBurnedTimes) {
            // TODO: Should effect `totalInvestment`
            totalInvestment.totalInvestmentByUsers = totalInvestment.totalInvestmentByUsers.sub(userShareSnapshot.pendingInvestAmount);
            totalInvestment.totalShare = totalInvestment.totalShare.sub(userShareSnapshot.lockedShareBalance).sub(userShareSnapshot.unlockedShareBalance);
            // Has lost all investments.
            userShareSnapshot.pendingInvestAmount = 0;
            userShareSnapshot.lockedShareBalance = 0;
            userShareSnapshot.unlockedShareBalance = 0;
            // Records current burned times.
            userShareSnapshot.burnedTimes = currentBurnedTimes;
        }

        if (userShareSnapshot.pendingSharePeriod <= currentPeriod.sub(2)) {
            // Invested very early. Share locked time has passed.
            userShareSnapshot.unlockedShareBalance = userShareSnapshot.unlockedShareBalance.add(userShareSnapshot.lockedShareBalance).add(userShareSnapshot.pendingShareBalance);
            userShareSnapshot.lockedShareBalance = 0;
            userShareSnapshot.pendingShareBalance = 0;
        }

        if (userShareSnapshot.pendingSharePeriod == currentPeriod.sub(1)) {
            // locked should go to unlocked
            userShareSnapshot.unlockedShareBalance = userShareSnapshot.unlockedShareBalance.add(userShareSnapshot.lockedShareBalance);
            userShareSnapshot.lockedShareBalance = userShareSnapshot.pendingShareBalance;
            userShareSnapshot.pendingShareBalance = 0;
        }
    }

    /**
     * @dev Calculates the accrued TRA amount and update.
     */
    function _updateTRAReward(TokenType tokenType, address who) internal {

        // Get the user's share details.
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];

        uint256 accruedTRA = getAccruedTRARewards(tokenType, who);
        if (accruedTRA > 0) {
            userShareSnapshot.TRARewards = userShareSnapshot.TRARewards.add(accruedTRA);
        }
        // Records current TRA price period.
        userShareSnapshot.TRAPricePeriod = currentPeriod.sub(1);
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
        require(recipient != address(0), "investJT: Recipient account can not be zero address!");
        require(amount != 0, "investJT: Invest amount can not be zero!");
        require(block.timestamp >= startTime, "investJT: Invest is not open!");
        harvestAllTRARewards();
        _investJT(msg.sender, recipient, amount);
    }

    /**
     * @dev Get all TRA rewards and withdraw all invested token at the same time.
     */
    function exit(TokenType tokenType) external nonReentrant {
        harvestTRARewards(tokenType);

        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][msg.sender];

        require(
            userShareSnapshot.lockedSharePeriod != currentPeriod
            && userShareSnapshot.pendingSharePeriod != currentPeriod.sub(1),
            "exit: Has locked share!"
        );

        redeemInvestmentByShareToken(tokenType, userShareSnapshot.unlockedShareBalance);
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
        if (validTRARewards > 0) {
            SkyrimToken.mint(caller,validTRARewards);
            // Clear the TRA rewards.
            userShareSnapshot.TRARewards = 0;
        }
    }

    /**
     * @dev Redeem invested token by specified share token.
     */
    function redeemInvestmentByShareToken(TokenType tokenType, uint256 redeemShareTokenAmount) public nonReentrant {
        harvestAllTRARewards();
        _rebalanceUserShare(tokenType, msg.sender);
        _redeemInternal(tokenType, msg.sender, redeemShareTokenAmount, 0);
    }

    /**
     * @dev Redeem specified invested token.
     */
    function redeemInvestment(TokenType tokenType, uint256 reddemInvestmeTokenAmount) public nonReentrant {
        harvestAllTRARewards();
        _rebalanceUserShare(tokenType, msg.sender);
        _redeemInternal(tokenType, msg.sender, 0, reddemInvestmeTokenAmount);
    }

    struct ShareLocalVars {
        uint256 currentPeriod;
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
        if (_vars.pendingPeriod == 0 && _vars.unlockedShareBalance == 0 && _vars.lockedShareBalance == 0 && _vars.pendingShareBalance == 0) {
            return 0;
        }

        if (hasBurnedAll(tokenType, who)) {
            // Has lost all invested token.
            _vars.latestTRARate = burnedTRARate[tokenType][_vars.userBurnedTimes];
        } else {
            _vars.latestTRARate = TRAPricePerPeriod[tokenType][currentPeriod.sub(1)];
        }

        // Calculate TRA rewards based on unlocked share amount and its share period.
        if (_vars.unlockedShareBalance > 0) {
            _vars.userTRAPricePeriod = userShareSnapshot.TRAPricePeriod;
            _vars.shareTRAPrice = TRAPricePerPeriod[tokenType][_vars.userTRAPricePeriod];
            _vars.shareRewards = _vars.unlockedShareBalance.rmul(_vars.latestTRARate.sub(_vars.shareTRAPrice));
            rewards = rewards.add(_vars.shareRewards);
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

    function getLatestSettlementPeriod() public view returns (uint256) {
        return currentPeriod.sub(1);
    }

    /**
     * @dev Calculate current investment price for token.
     */
    function getCurrentInvestmentPriceByToken(TokenType _tokenType) public view returns (uint256) {
        return investmentPricePerPeriod[_tokenType][getLatestSettlementPeriod()];
    }

    /**
     * @dev Calculate current investment price for ST token.
     */
    function getCurrentInvestmentPriceForST() public view returns (uint256) {
        return investmentPricePerPeriod[TokenType.isSeniorToken][getLatestSettlementPeriod()];
    }

    /**
     * @dev Calculate current investment price for JT token.
     */
    function getCurrentInvestmentPriceForJT() public view returns (uint256) {
        return investmentPricePerPeriod[TokenType.isJuniorToken][getLatestSettlementPeriod()];
    }

    /**
     * @notice Only unlocked share can be withdrawn.
     * @dev Calculate how many senior token that a user can withdraw now and whether he has
     *      locked share token.
     */
    function getValidInvestmentShareAmount(
        TokenType tokenType,
        address who
    ) public view returns (uint256) {
        return getUserValidUnlockShareAmount(tokenType, who);
    }

    /**
     * @dev Get how many periods passed after user did last investment by token.
     */
    function getUserPeriodsAfterInvestment(
        TokenType tokenType,
        address who
    ) public view returns (uint256) {
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[tokenType][who];
        // todo
        return currentPeriod.sub(userShareSnapshot.pendingSharePeriod);
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
        if (shouldUnlockNoneShares(tokenType, who)) {
            return userShareSnapshot.unlockedShareBalance;
        }

        if (shouldUnlockUserLockedShares(tokenType, who)) {
            return userShareSnapshot.unlockedShareBalance.add(userShareSnapshot.lockedShareBalance);
        }

        if (shouldUnlockAllUserShares(tokenType, who)) {
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
        uint256 shareAmount = getValidInvestmentShareAmount(tokenType, who);
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

    /**
     * @dev Get current period.
     */
    function getCurrentPeriod() external view returns (uint256) {
        return currentPeriod;
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
     * @dev Total investments by users with ST Token.
     */
    function totalInvestByST() public view returns (uint256 totalSTInvestedAmount) {
        TotalInvestmentSnapshot storage totalSTInvestment = totalInvestmentsInfo[TokenType.isSeniorToken];
        totalSTInvestedAmount = totalSTInvestment.totalInvestmentByUsers;
    }

    /**
     * @dev Total investments by users with JT Token.
     */
    function totalInvestByJT() public view returns (uint256 totalJTInvestedAmount) {
        TotalInvestmentSnapshot storage totalSTInvestment = totalInvestmentsInfo[TokenType.isJuniorToken];
        totalJTInvestedAmount = totalSTInvestment.totalInvestmentByUsers;
    }

    /**
     * @dev Invested ST Token amount by users.
     */
    function investAmountByST(address who) external view returns (uint256 STInvestedAmount) {
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[TokenType.isSeniorToken][who];
        STInvestedAmount = userShareSnapshot.totalInvestAmount;
    }

    /**
     * @dev Invested JT Token amount by users.
     */
    function investAmountByJT(address who) external view returns (uint256 JTInvestedAmount) {
        AccountShareSnapshot storage userShareSnapshot = accountInvestments[TokenType.isJuniorToken][who];
        JTInvestedAmount = userShareSnapshot.totalInvestAmount;
    }

    function getAPY(TokenType _tokenType) external view returns(uint256) {
        return APYs[_tokenType];
    }
}
