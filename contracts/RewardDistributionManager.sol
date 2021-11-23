// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.8.0;

import "./library/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract RewardDistributionManager is Ownable, Initializable {
    address rewardDistributionManager;

    modifier onlyRewardDistributionManager() {
        require(msg.sender == rewardDistributionManager, "Caller is not reward distribution manager");
        _;
    }

    /**
     * @notice Expects to call this function only for one time.
     * @dev Initialize contracts and do the initial distribution.
     */
    function initialize() public initializer {
        __Ownable_init();
    }

    function setRewardDistributionManager(address _rewardDistribution)
        external
        onlyOwner
    {
        rewardDistributionManager = _rewardDistribution;
    }
}