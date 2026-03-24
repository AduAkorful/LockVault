// SPDX-License-Identifier:MIT

pragma solidity 0.8.33;

import {ILockVault} from "./interfaces/ILockVault.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IVaultToken} from "./interfaces/IVaultToken.sol";
import {IMembershipNFT} from "./interfaces/IMembershipNFT.sol";
import {IMockOracleFeed} from "./interfaces/IMockOracleFeed.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract LockVault is ILockVault, Ownable2Step {
    using SafeERC20 for IERC20;

    // scaling factor used in reward calculations to preserve precision
    uint256 public constant PRECISION = 1e18;

    // maximum number of active stakes a single user may hold
    uint256 public constant MAX_ACTIVE_STAKES = 20;

    // staleness threshold for oracle price data
    uint256 public constant STALENESS_THRESHOLD = 1 hours;

    // Volume required for Bronze tier (1,000 tokens).
    uint256 public constant BRONZE_THRESHOLD = 1_000e18;

    // Volume required for Silver tier (5,000 tokens).
    uint256 public constant SILVER_THRESHOLD = 5_000e18;

    // Volume required for Gold tier (10,000 tokens).
    uint256 public constant GOLD_THRESHOLD = 10_000e18;

    // The VaultToken contract that this vault is authorized to mint
    IVaultToken public immutable VAULT_TOKEN;

    //  The MembershipNFT contract consulted for bonus multipliers.
    IMembershipNFT public immutable MEMBERSHIP_NFT;

    //  Address that receives the penalty portion of emergency withdrawals.
    address public treasury;

    // Amount of VaultToken minted per second per every staken token
    // Scaled by precision so 1e9 means 1e9/1e18 since we can't use floating point integers
    uint256 public immutable REWARD_RATE;

    // constant variable for the 30 days lock tier multiplier
    uint16 public constant THIRTY_DAYS_MULTIPLIER = 100;

    // constant variable for the 90 days lock tier multiplier
    uint16 public constant NINETY_DAYS_MULTIPLIER = 250;

    // constant variable for the 180 days lock tier multiplier
    uint16 public constant ONE_EIGHTY_DAYS_MULTIPLIER = 600;

    // constant variable for 30 days lock tier
    uint32 public constant THIRTY_DAYS_LOCK_TIER = 30 days;

    // constant variable for 90 days lock tier
    uint32 public constant NINETY_DAYS_LOCK_TIER = 90 days;

    // constant variable for 180 days lock tier
    uint32 public constant ONE_EIGHTY_DAYS_LOCK_TIER = 180 days;

    // constant variable for bronze tier rewards boost
    // rewards are a percentage so it is scaled during the calculation
    uint8 public constant BRONZE_TIER = 10;

    // constant variable for silver tier rewards
    uint8 public constant SILVER_TIER = 25;

    // constant variable for gold tier rewards
    uint8 public constant GOLD_TIER = 50;

    mapping(address => mapping(uint256 => Stake)) private _userStakes;

    // Total number of stakes created by a user
    mapping(address => uint256) public userStakeCount;

    // Number of active unclamed stakes per user.
    mapping(address => uint256) public activeStakeCount;

    // Total lifetime staked amount per user.
    mapping(address => uint256) public userTotalStake;

    // Total lifetime staked amount per user normalized to 18 decimals.
    mapping(address => uint256) public userTotalNormalizedStake;

    // Whether a token is currently whitelisted for new stakes.
    mapping(address => bool) public isWhitelisted;

    // Price feed address for each whitelisted token.
    mapping(address => address) public tokenPriceFeed;

    // Total amount of each token currently held by the vault.
    mapping(address => uint256) public totalStakedPerToken;

    // Total amount of each token normalized to 18 decimals
    mapping(address => uint256) public totalNormalizedStakePerToken;

    // Sets address of membership nft token, vault token and treasury to send forfeited tokens
    constructor(address _membershipNft, address _vaultToken, address _treasury, uint256 _rewardRate)
        Ownable(msg.sender)
    {
        if (_membershipNft == address(0) || _vaultToken == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert InvalidTreasury();
        if (_rewardRate == 0) revert ZeroAmount();

        MEMBERSHIP_NFT = IMembershipNFT(_membershipNft);
        VAULT_TOKEN = IVaultToken(_vaultToken);
        treasury = _treasury;
        REWARD_RATE = _rewardRate;
    }

    // Function to whitelist a token
    // Takes the token address and its respective price feed address
    function addToken(address token, address priceFeed) external onlyOwner {
        if (token == address(0) || priceFeed == address(0)) revert ZeroAddress();
        if (isWhitelisted[token]) revert TokenAlreadyWhitelisted(token);

        isWhitelisted[token] = true;
        tokenPriceFeed[token] = priceFeed;

        emit TokenWhitelisted(token, priceFeed);
    }

    // Function to delist a token
    // verifies if token has been whitelisted before it can work
    function removeToken(address token) external onlyOwner {
        if (!isWhitelisted[token]) revert NotWhitelisted(token);

        isWhitelisted[token] = false;

        emit TokenDelisted(token, block.timestamp);
    }

    // Takes in an address to set as treasury for receiving emergency withdrawal penalties
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidTreasury();
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    // Allows users to stake available whitelisted tokens based on specified amount and lock tier
    function stake(address token, uint256 amount, LockTier tier) external {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (!isWhitelisted[token]) revert NotWhitelisted(token);
        if (activeStakeCount[msg.sender] >= MAX_ACTIVE_STAKES) revert MaxStakesReached();

        // Transfer tokens first to prevent phantom stake if transfer fails
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 stakeIndex = userStakeCount[msg.sender];
        _userStakes[msg.sender][stakeIndex] =
            Stake({token: token, amount: amount, lockTier: tier, startTime: block.timestamp, claimed: false});

        uint8 decimals = IERC20Metadata(token).decimals();
        uint256 normalizedAmount = _normalize(amount, decimals);

        userStakeCount[msg.sender]++;
        activeStakeCount[msg.sender] += 1;
        totalStakedPerToken[token] += amount;
        totalNormalizedStakePerToken[token] += normalizedAmount;

        userTotalStake[msg.sender] += amount;
        userTotalNormalizedStake[msg.sender] += normalizedAmount;
        _checkAndMintMembership(msg.sender);

        emit Staked(msg.sender, token, amount, tier, stakeIndex);
    }

    // Allows users to withdraw their staked tokens and claim generated rewards after lock duration expiration
    function withdraw(uint256 stakeIndex) external {
        Stake storage s = _getStake(msg.sender, stakeIndex);

        uint256 unlockTime = s.startTime + _lockDuration(s.lockTier);
        if (block.timestamp < unlockTime) revert LockNotExpired(unlockTime);

        uint256 rewards = _calculateRewards(s, msg.sender);
        address token = s.token;
        uint256 principal = s.amount;

        s.claimed = true;
        activeStakeCount[msg.sender] -= 1;
        totalStakedPerToken[token] -= principal;

        emit Withdrawn(msg.sender, stakeIndex, principal, rewards);

        IERC20(token).safeTransfer(msg.sender, principal);

        if (rewards > 0) {
            try VAULT_TOKEN.mint(msg.sender, rewards) {}
            catch {
                emit RewardMintFailed(msg.sender, stakeIndex, rewards);
            }
        }
    }

    // Allows users to withdraw tokens before lock expiration, forfeiting half of rewards as penalty sent to treasury
    function emergencyWithdraw(uint256 stakeIndex) external {
        Stake storage s = _getStake(msg.sender, stakeIndex);

        uint256 unlockTime = s.startTime + _lockDuration(s.lockTier);
        if (block.timestamp >= unlockTime) revert LockNotExpired(0);

        uint256 totalRewards = _calculateRewards(s, msg.sender);
        uint256 userRewards = totalRewards / 2;
        uint256 penalty = totalRewards - userRewards;

        address token = s.token;
        uint256 principal = s.amount;

        s.claimed = true;
        activeStakeCount[msg.sender] -= 1;
        totalStakedPerToken[token] -= principal;

        emit EmergencyWithdrawn(msg.sender, stakeIndex, principal, userRewards, penalty);

        IERC20(token).safeTransfer(msg.sender, principal);
        if (userRewards > 0) {
            try VAULT_TOKEN.mint(msg.sender, userRewards) {}
            catch {
                emit RewardMintFailed(msg.sender, stakeIndex, userRewards);
            }
        }

        if (penalty > 0) {
            try VAULT_TOKEN.mint(treasury, penalty) {}
            catch {
                emit PenaltyMintFailed(treasury, stakeIndex, penalty);
            }
        }
    }

    function _normalize(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        uint256 normalizedAmount;
        if (decimals < 18) return normalizedAmount = amount * 10 ** (18 - decimals);
        else if (decimals > 18) return normalizedAmount = amount / 10 ** (decimals - 18);
        else return amount;
    }

    // Returns the pending rewards for a specific stake of a given user
    function getPendingRewards(address user, uint256 stakeIndex) external view returns (uint256) {
        if (stakeIndex >= userStakeCount[user]) {
            revert InvalidStakeIndex(stakeIndex, userStakeCount[user]);
        }

        Stake memory s = _userStakes[user][stakeIndex];
        if (s.claimed) return 0;
        return _calculateRewards(s, user);
    }

    //Called to upgrade user membership if they reach the required threshold
    function upgradeMembershipTier() external {
        uint256 userVolume = userTotalNormalizedStake[msg.sender];
        uint8 currentTier = uint8(MEMBERSHIP_NFT.getTier(msg.sender));
        uint8 newTier;

        if (currentTier == MEMBERSHIP_NFT.getBronzeTier() && userVolume >= SILVER_THRESHOLD) {
            newTier = MEMBERSHIP_NFT.getSilverTier();
        } else if (currentTier == MEMBERSHIP_NFT.getSilverTier() && userVolume >= GOLD_THRESHOLD) {
            newTier = MEMBERSHIP_NFT.getGoldTier();
        } else {
            revert UpgradeNotPossible();
        }

        MEMBERSHIP_NFT.upgradeTier(msg.sender, IMembershipNFT.Tier(newTier));

        emit MembershipUpgraded(msg.sender, newTier);
    }

    // Returns the total USD value locked across the provided tokens using chainlink price feed
    function getTotalValueLocked(address[] calldata tokens) external view returns (uint256 totalUsd) {
        uint256 tokenCount = tokens.length;
        for (uint256 i = 0; i < tokenCount; i++) {
            address token = tokens[i];

            if (!isWhitelisted[token]) revert NotWhitelisted(token);

            uint256 staked = totalNormalizedStakePerToken[token];
            if (staked == 0) continue;

            IMockOracleFeed feed = IMockOracleFeed(tokenPriceFeed[token]);
            (, int256 price,, uint256 updatedAt,) = feed.latestRoundData();

            if (price <= 0) revert InvalidPrice(token);
            if (block.timestamp - updatedAt > STALENESS_THRESHOLD) revert StalePrice(token);

            // result is in 8 decimals (standard USD feed precision)
            // casting to 'uint256' is safe because we revert above if price <= 0
            // forge-lint: disable-next-line(unsafe-typecast)
            totalUsd += Math.mulDiv(staked, uint256(price), 1e18);
        }
    }

    function _getStake(address user, uint256 index) private view returns (Stake storage s) {
        if (index >= userStakeCount[user]) {
            revert InvalidStakeIndex(index, userStakeCount[user]);
        }
        s = _userStakes[user][index];
        if (s.claimed) revert AlreadyClaimed(index);
    }

    function _lockDuration(LockTier tier) private pure returns (uint256) {
        if (tier == LockTier.ThirtyDays) return THIRTY_DAYS_LOCK_TIER;
        if (tier == LockTier.NinetyDays) return NINETY_DAYS_LOCK_TIER;
        return ONE_EIGHTY_DAYS_LOCK_TIER;
    }

    function _tierMultiplier(LockTier tier) private pure returns (uint256) {
        if (tier == LockTier.ThirtyDays) return THIRTY_DAYS_MULTIPLIER;
        if (tier == LockTier.NinetyDays) return NINETY_DAYS_MULTIPLIER;
        return ONE_EIGHTY_DAYS_MULTIPLIER;
    }

    function _membershipBonus(address user) private view returns (uint256) {
        try MEMBERSHIP_NFT.getTier(user) returns (IMembershipNFT.Tier tier) {
            if (tier == IMembershipNFT.Tier.Bronze) return BRONZE_TIER;
            if (tier == IMembershipNFT.Tier.Silver) return SILVER_TIER;
            return GOLD_TIER;
        } catch {
            return 0;
        }
    }

    function _calculateRewards(Stake memory s, address user) private view returns (uint256) {
        uint256 duration = _lockDuration(s.lockTier);
        uint256 elapsed = 0;
        if (block.timestamp > s.startTime) {
            elapsed = Math.min(block.timestamp - s.startTime, duration);
        }

        uint256 amountRate = Math.mulDiv(s.amount, REWARD_RATE, PRECISION);
        uint256 baseReward = Math.mulDiv(amountRate, elapsed, 1);
        uint256 tieredReward = Math.mulDiv(baseReward, _tierMultiplier(s.lockTier), 100);
        uint256 bonusPct = _membershipBonus(user);
        return baseReward + Math.mulDiv(tieredReward, 100 + bonusPct, 100);
    }

    function _checkAndMintMembership(address user) internal {
        if (MEMBERSHIP_NFT.getMemberInfo(user).tokenId != 0) return;

        uint256 volume = userTotalNormalizedStake[user];
        IMembershipNFT.Tier targetTier;
        bool eligible;

        if (volume >= GOLD_THRESHOLD) {
            targetTier = IMembershipNFT.Tier.Gold;
            eligible = true;
        } else if (volume >= SILVER_THRESHOLD) {
            targetTier = IMembershipNFT.Tier.Silver;
            eligible = true;
        } else if (volume >= BRONZE_THRESHOLD) {
            targetTier = IMembershipNFT.Tier.Bronze;
            eligible = true;
        }

        if (eligible) {
            MEMBERSHIP_NFT.mint(user, targetTier);
        }
    }
}
