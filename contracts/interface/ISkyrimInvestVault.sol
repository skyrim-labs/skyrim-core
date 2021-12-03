// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface ISkyrimInvestVault {
    /**
     * @notice Security checks when setting Skyrim vault contract, always expect to return true.
     */
    function isSkyrimVault() external returns (bool);

    function totalInvestmentsInfo(uint256 tokenType) external view returns (uint256,uint256,uint256,uint256,uint256);
    function accountInvestments(uint256 tokenType, address who) external view returns (uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256);
    function period() external view returns (uint256);
    function getCurrentPeriod() external view returns (uint256);
    function lockTime() external view returns (uint256);
    function startTime() external view returns (uint256);
    function seniorTokenSupplyRate() external view returns (uint256);
    function JTSupplyRatesPerPeriod() external view returns (uint256);
    function hasBurnedAll(uint256 tokenType, address who) external view returns (bool);
    function burnedTRARate(uint256 tokenType, uint256 when) external view returns (uint256);
    function TRAPricePerPeriod(uint256 tokenType, uint256 when) external view returns (uint256);
    function investmentPricePerPeriod(uint256 tokenType, uint256 when) external view returns (uint256);
    function getAccruedTRARewards(uint256 tokenType, address who) external view returns (uint256);
}
