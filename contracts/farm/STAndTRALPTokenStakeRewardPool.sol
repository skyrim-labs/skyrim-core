// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../RewardDistributionManager.sol";
import "../SkyrimToken.sol";

contract STAndTRAV2PairTokenWrapper {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public STAndTRAV2PairToken;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    constructor (address pairTokenAddress) {
        STAndTRAV2PairToken = IERC20Upgradeable(pairTokenAddress);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) virtual public {
        uint256 _before = STAndTRAV2PairToken.balanceOf(address(this));
        STAndTRAV2PairToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 _after = STAndTRAV2PairToken.balanceOf(address(this));
        uint256 _amount = _after.sub(_before);

        _totalSupply = _totalSupply.add(_amount);
        _balances[msg.sender] = _balances[msg.sender].add(_amount);
    }

    function withdraw(uint256 amount) virtual public {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        STAndTRAV2PairToken.safeTransfer(msg.sender, amount);
    }
}

contract STAndTRALPTokenStakeRewardPool is STAndTRAV2PairTokenWrapper, RewardDistributionManager {
    using SafeMathUpgradeable for uint256;
    using MathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for SkyrimToken;

    SkyrimToken public TRAToken;
    uint256 public constant DURATION = 100 weeks;

    uint256 public constant startTime = 1616151776;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored = 0;
    bool private open = true;
    uint256 private constant _gunit = 1e18;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event SetOpen(bool _open);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(address pairToken, address TRAToken_) STAndTRAV2PairTokenWrapper(pairToken) {
        TRAToken = SkyrimToken(TRAToken_);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return periodFinish.min(block.timestamp);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(_gunit)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(_gunit)
                .add(rewards[account]);
    }

    function stake(uint256 amount) override public checkOpen checkStart updateReward(msg.sender){
        require(amount > 0, "JTAndTRAV2PairPool: Cannot stake 0");
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) override public checkStart updateReward(msg.sender){
        require(amount > 0, "JTAndTRAV2PairPool: Cannot withdraw 0");
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public checkStart updateReward(msg.sender){
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            TRAToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    modifier checkStart() {
        require(block.timestamp > startTime,"JTAndTRAV2PairPool: Not start");
        _;
    }

    modifier checkOpen() {
        require(open, "JTAndTRAV2PairPool: Pool is closed");
        _;
    }

    function getPeriodFinish() external view returns (uint256) {
        return periodFinish;
    }

    function isOpen() external view returns (bool) {
        return open;
    }

    function setOpen(bool _open) external onlyOwner {
        open = _open;
        emit SetOpen(_open);
    }

    function notifyRewardAmount(uint256 reward)
        external
        onlyRewardDistributionManager
        checkOpen
        updateReward(address(0)){
        if (block.timestamp > startTime){
            if (block.timestamp >= periodFinish) {
                uint256 period = block.timestamp.sub(startTime).div(DURATION).add(1);
                periodFinish = startTime.add(period.mul(DURATION));
                rewardRate = reward.div(periodFinish.sub(block.timestamp));
            } else {
                uint256 remaining = periodFinish.sub(block.timestamp);
                uint256 leftover = remaining.mul(rewardRate);
                rewardRate = reward.add(leftover).div(remaining);
            }
            lastUpdateTime = block.timestamp;
        }else {
          uint256 b = TRAToken.balanceOf(address(this));
          rewardRate = reward.add(b).div(DURATION);
          periodFinish = startTime.add(DURATION);
          lastUpdateTime = startTime;
        }

        TRAToken.mint(address(this),reward);
        emit RewardAdded(reward);

        _checkRewardRate();
    }

    function _checkRewardRate() internal view returns (uint256) {
        return DURATION.mul(rewardRate).mul(_gunit);
    }
}