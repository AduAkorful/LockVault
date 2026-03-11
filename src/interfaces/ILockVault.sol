// SPDX-License-Identifier:MIT

pragma solidity 0.8.33;

interface ILockVault {
    // The three supported lock durations.
    enum LockTier {
        ThirtyDays,
        NinetyDays,
        OneEightyDays
    }

    // The data associated with creating a user stake
    // the token address, amount and duraton
    // start time is hardcoded and claimed is set to false at creation
    struct Stake {
        address token;
        uint256 amount;
        LockTier lockTier;
        uint256 startTime;
        bool claimed;
    }

    // Emitted when a vault token reward fails to mint to a user
    event RewardMintFailed(address indexed user, uint256 indexed stakeIndex, uint256 amount);

    // Emitted when a user successfully stakes a whitelisted token
    event Staked(address indexed user, address indexed token, uint256 amount, LockTier tier, uint256 stakeIndex);

    // Emitted when a user withdraws their principal and rewards after the lock expires
    event Withdrawn(address indexed user, uint256 indexed stakeIndex, uint256 principal, uint256 rewards);

    // Emitted when rewards are successfully distributed to a claiming user
    event RewardsClaimed(address indexed user, uint256 indexed stakeIndex, uint256 amount);

    // Emitted when a user withdraws early, taking half the rewards and forfeiting the penalty
    event EmergencyWithdrawn(
        address indexed user, uint256 indexed stakeIndex, uint256 principal, uint256 userRewards, uint256 penalty
    );

    // Emitted when a token is added to the valid staking whitelist
    event TokenWhitelisted(address indexed token, address indexed priceFeed);

    // Emitted when a token is removed from the staking whitelist
    event TokenDelisted(address indexed token, uint256 delistTime);

    // Emitted when the vault's reward rate per second is updated
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    // Emitted when the system treasury address for penalties is updated
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    // Emitted when penalty tokens fail to mint to the treasury
    event PenaltyMintFailed(address indexed recipietn, uint256 indexed stakeIndex, uint256 amount);

    // Emitted when membership tier is upgraded
    event MembershipUpgraded(address indexed user, uint8 newTier);
    // Thrown when an amount provided is zero
    error ZeroAmount();

    // Thrown when an invalid zero address is supplied
    error ZeroAddress();

    // Thrown when interacting with a token that is not whitelisted
    error NotWhitelisted(address token);

    // Thrown when a standard withdrawal is attempted before the stake unlocks
    error LockNotExpired(uint256 unlockTime);

    // Thrown when attempting an action on a stake that has already been claimed
    error AlreadyClaimed(uint256 stakeIndex);

    // Thrown when a user reaches their maximum limit of active stakes
    error MaxStakesReached();

    // Thrown when referencing a stake index that doesn't exist for the user
    error InvalidStakeIndex(uint256 index, uint256 length);

    // Thrown when the Chainlink oracle price is considered stale
    error StalePrice(address token);

    // Thrown when the Chainlink oracle returns an invalid or negative price
    error InvalidPrice(address token);

    // Thrown when an invalid address is set for the treasury
    error InvalidTreasury();

    // Thrown when adding a token that has already been whitelisted
    error TokenAlreadyWhitelisted(address token);

    // Thrown when you don't meet the requirements to upgrade your tier
    error UpgradeNotPossible();

    // Function to whitelist a token
    // Takes the token address and its respective price feed address
    function addToken(address token, address priceFeed) external;

    // Function to delist a token
    // verifies if token has been whitelisted before it can work
    function removeToken(address token) external;

    // Takes in an address to set as treasury for receiving emergency withdrawal penalties
    function setTreasury(address newTreasury) external;

    // Allows users to stake available whitelisted tokens based on specified amount and lock tier
    function stake(address token, uint256 amount, LockTier tier) external;

    // Allows users to withdraw their staked tokens and claim generated rewards after lock duration expiration
    function withdraw(uint256 stakeIndex) external;

    // Allows users to withdraw tokens before lock expiration, forfeiting half of rewards as penalty sent to treasury
    function emergencyWithdraw(uint256 stakeIndex) external;

    // Returns the pending rewards for a specific stake of a given user
    function getPendingRewards(address user, uint256 stakeIndex) external view returns (uint256);

    //Called to upgrade user membership if they reach the required threshold
    function upgradeMembershipTier(address user) external;

    // Returns the total USD value locked across the provided tokens using chainlink price feed
    function getTotalValueLocked(address[] calldata tokens) external view returns (uint256 totalUsd);
}
