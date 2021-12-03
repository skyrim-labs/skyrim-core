// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "./SkyrimInvestVault.sol";
import "./interface/ISeniorToken.sol";
import "./interface/IJuniorToken.sol";
import "./library/SafeMathRatio.sol";
import "hardhat/console.sol";
/**
 * @title Skyrim invest vault admin contract.
 */
contract SkyrimInvestVaultAdmin is SkyrimInvestVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using SafeMathRatio for uint256;

    function setStartTime(uint256 newStartTime) external onlyOwner nonReentrant {
        uint256 oldStartTime = startTime;
        startTime = newStartTime;

        emit NewStartTime(oldStartTime, newStartTime);
    }

    struct SettleProfitsLocalVars {
        uint256 profit;
        uint256 loss;
        TokenType tokenType;
        uint256 oldShareTRARewardRate;
        uint256 oldInvestmentPricePerPeriod;
        uint256 lockedInvestment;
        uint256 oldTRARewardRate;
        uint256 changedTRARewardRate;
        uint256 oldUnlockedInvestment;
        uint256 changedInvestmentPrice;
        uint256 finalInvestmentPrice;
        uint256 totalUnlockedInvestment;
        uint256 newJTSupplyRate;
        uint256 currentJTSupplyRate;
        uint256 oldJTSupplyRate;
        uint256 threeDaysAgoSupplyRate;
        uint256 burnedTimes;
    }

    /**
     * @notice Senior token details must be at the first place!!!
     * @dev Input profits and losses of the last investment, only for owner.
     *      eg: profits = [STProfit, JTProfit]
     *      eg: losses =  [STLoss, JTLoss]
     */
    function settleProfitsByOwner(
        uint256[] memory profits,
        uint256[] memory losses
    ) external onlyOwner nonReentrant {
        require(
            profits.length == losses.length && profits.length == 2,
            "profits & losses must have 2 elements!"
        );

        // let's deal with the profits and losses of ST and then JT
        for (uint8 i = 0; i < 2; i++) {
            require(
                profits[i] == 0 || losses[i] == 0,
                "One of profit or loss must be zero!"
            );

            SettleProfitsLocalVars memory _vars;
            _vars.profit = profits[i];
            _vars.loss = losses[i];
            _vars.tokenType = i == 0 ? TokenType.isSeniorToken : TokenType.isJuniorToken;
            _vars.oldShareTRARewardRate = TRAPricePerPeriod[_vars.tokenType];

            TotalInvestmentSnapshot storage totalInvestment = totalInvestmentsInfo[_vars.tokenType];
            _vars.totalUnlockedInvestment = totalInvestment.pendingInvestment;
            console.log("totalUnlockedInvestment %s", _vars.totalUnlockedInvestment);
            // Luckily we made money
            if (_vars.profit > 0) {
                totalTRARewards = totalTRARewards.add(_vars.profit);
                if (_vars.totalUnlockedInvestment == 0) {
                    _vars.changedTRARewardRate = 0;
                } else {
                    _vars.changedTRARewardRate = _vars.profit.rdiv(totalInvestment.totalShare);
                }
                console.log("changedTRARewardRate %s", _vars.changedTRARewardRate);

                totalInvestment.pendingInvestment = 0;
                totalInvestment.unlockedInvestment = _vars.totalUnlockedInvestment;

                TRAPricePerPeriod[_vars.tokenType] = _vars.changedTRARewardRate;
                // investmentPricePerPeriod[_vars.tokenType] = _vars.oldInvestmentPricePerPeriod;
            } else {
                // I'm sorry we lost out
                require(_vars.loss <= _vars.totalUnlockedInvestment, "Too much to lose!");
                // Loss senior token, decrease the exchange ratio of invested Token and invested Share.
                if (_vars.loss != 0 && _vars.loss == _vars.totalUnlockedInvestment) {
                    // All invested token has lost.
                    _vars.finalInvestmentPrice = BASE;
                    TRAPricePerPeriod[_vars.tokenType] = 0;
                } else {
                    if (_vars.loss != 0 && _vars.totalUnlockedInvestment != 0) {
                        _vars.changedInvestmentPrice = _vars.loss.rdivup(_vars.totalUnlockedInvestment);
                        _vars.finalInvestmentPrice = _vars.oldInvestmentPricePerPeriod.rmul(BASE.sub(_vars.changedInvestmentPrice));
                    } else {
                        _vars.finalInvestmentPrice = _vars.oldInvestmentPricePerPeriod;
                    }
                    TRAPricePerPeriod[_vars.tokenType] = _vars.oldShareTRARewardRate;
                }

                totalInvestment.pendingInvestment = 0;
                totalInvestment.unlockedInvestment = _vars.totalUnlockedInvestment.sub(_vars.loss);

                // investmentPricePerPeriod[_vars.tokenType] = _vars.finalInvestmentPrice;
                if (_vars.loss > 0) {
                    if (_vars.tokenType == TokenType.isSeniorToken) {
                        STToken.vaultBurnLoss(_vars.loss);
                    } else if (_vars.tokenType == TokenType.isJuniorToken) {
                        JTToken.vaultBurnLoss(_vars.loss);
                    }
                }
            }

            emit SettleProfits(_vars.tokenType, _vars.profit, _vars.loss);
        }
        currentState = PeriodState.End;
    }

    struct InvestByOwnerLocalVars {
        TokenType tokenType;
        uint256 currentInvestmentPrice;
        uint256 maxInvestmentAmount;
        uint256 expectWithdrawAmount;
    }

    /**
     * @dev Collect all invested token by owner.
     */
    function investByOwner(uint256[] memory investmentAmounts)
        external
        onlyOwner
        nonReentrant
    {
        require(investmentAmounts.length == 2, "investByOwner: New investments must have 2 elements!");
        for (uint256 i = 0; i < investmentAmounts.length; i++) {
            InvestByOwnerLocalVars memory _vars;
            _vars.expectWithdrawAmount = investmentAmounts[i];
            if (_vars.expectWithdrawAmount != 0) {
                _vars.tokenType = i == 0 ? TokenType.isSeniorToken : TokenType.isJuniorToken;
                _vars.currentInvestmentPrice = investmentPricePerPeriod[_vars.tokenType];
                TotalInvestmentSnapshot storage totalInvestment = totalInvestmentsInfo[_vars.tokenType];
                _vars.maxInvestmentAmount = totalInvestment.pendingInvestment;
                require(
                    _vars.expectWithdrawAmount <= _vars.maxInvestmentAmount,
                    "investByOwner: Too much to invest!"
                );
                if (i == 0) {
                    STToken.withdrawUnderlyingToVault(
                        _vars.expectWithdrawAmount
                    );
                } else {
                    JTToken.withdrawUnderlyingToVault(
                        _vars.expectWithdrawAmount
                    );
                }

                investedToken.safeTransfer(msg.sender, _vars.expectWithdrawAmount);

                emit InvestByOwner(_vars.tokenType, _vars.expectWithdrawAmount);
            }
        }
    }

    /**
     * @dev Set senior token supply rate, only for owner.
     */
    function setSeniorTokenSupplyRate(uint256 newSupplyRate)
        public
        onlyOwner
    {
        TokenType tokenType = TokenType.isSeniorToken;

        uint256 oldSupplyRate = seniorTokenSupplyRate;
        seniorTokenSupplyRate = newSupplyRate;

        emit NewSupplyRate(tokenType, oldSupplyRate, newSupplyRate);
    }

    /**
     * @dev Set token APY
     */
    function setAPY(TokenType _tokenType, uint256 _apy)
        public
        onlyOwner
    {
        APYs[_tokenType] = _apy;

        emit NewAPYSet(_tokenType, _apy);
    }

    /**
     * @dev Set junior token supply rate per locked time.
     */
    function _setJuniorTokenSupplyRateInternal(uint256 newSupplyRate) internal {
        uint256 oldSupplyRate = JTSupplyRatesPerPeriod;
        JTSupplyRatesPerPeriod = newSupplyRate;
        emit NewSupplyRate(TokenType.isJuniorToken, oldSupplyRate, newSupplyRate);
    }

    /**
     * @dev Set junior token supply rate, only for owner.
     */
    function setJuniorTokenSupplyRate(uint256 newSupplyRatePerLockTime)
        external
        onlyOwner
    {
        _setJuniorTokenSupplyRateInternal(newSupplyRatePerLockTime);
    }

    /**
     * @dev Update Peroid State
     */
    function setPeroidState(PeriodState _targetState) external onlyOwner nonReentrant {
        currentState = _targetState;
    }

    /**
     * @dev Get current senior token supply rate.
     */
    function getCurrentSTSupplyRate() external view returns (uint256) {
        return seniorTokenSupplyRate;
    }

    /**
     * @dev Get current junior token supply rate.
     */
    function getCurrentJTSupplyRate() external view returns (uint256) {
        return JTSupplyRatesPerPeriod;
    }
}
