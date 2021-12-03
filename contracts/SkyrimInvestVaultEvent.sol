// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./SkyrimInvestVaultStorage.sol";

/**
 * @title Skyrim invest vault events contract.
 */
contract SkyrimInvestVaultEvent is SkyrimInvestVaultStorage {
    event NewSTToken(
        ISeniorToken indexed oldSTToken,
        ISeniorToken indexed newSTToken
    );
    event NewJTToken(
        IJuniorToken indexed oldJTToken,
        IJuniorToken indexed newJTToken
    );
    event NewSkyrimToken(
        ISkyrimToken indexed oldSkyrimToken,
        ISkyrimToken indexed newSkyrimToken
    );

    event NewStartTime(uint256 indexed oldStartTime, uint256 indexed newStartTime);

    event Invest(TokenType tokenType, address from, address to, uint256 amount);
    event RewardRepaid(TokenType tokenType, address to, uint256 amount);

    event RedeemInvestedToken(
        TokenType tokenType,
        address from,
        uint256 investedShareAmount,
        uint256 investedAmount
    );

    event SettleProfits(TokenType tokenType, uint256 profit, uint256 loss);
    event InvestByOwner(TokenType tokenType, uint256 investment);

    event NewSupplyRate(
        TokenType tokenType,
        uint256 oldSupplyRate,
        uint256 newSupplyRate
    );

    event NewAPYSet(
        TokenType tokenType,
        uint256 apy
    );
}
