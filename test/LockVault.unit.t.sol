// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {LockVault} from "../src/LockVault.sol";
import {MembershipNFT} from "../src/MembershipNFT.sol";
import {MockOracleFeed} from "../src/MockOracleFeed.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {ILockVault} from "../src/interfaces/ILockVault.sol";
import {IMembershipNFT} from "../src/interfaces/IMembershipNFT.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LocalMockERC20Decimals is ERC20 {
    uint8 private immutable _customDecimals;

    constructor(string memory name_, string memory symbol_, uint8 customDecimals_) ERC20(name_, symbol_) {
        _customDecimals = customDecimals_;
    }

    function decimals() public view override returns (uint8) {
        return _customDecimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LockVaultUnitTest is Test {
    LockVault internal vault;
    MembershipNFT internal membershipNft;
    VaultToken internal vaultToken;

    LocalMockERC20Decimals internal token18;
    LocalMockERC20Decimals internal token6;
    LocalMockERC20Decimals internal token20;

    MockOracleFeed internal feed18;
    MockOracleFeed internal feed6;
    MockOracleFeed internal feed20;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA901);
    address internal treasury = address(0x7777);

    uint256 internal constant REWARD_RATE = 1e9;

    function setUp() public {
        membershipNft = new MembershipNFT();
        vaultToken = new VaultToken();
        vault = new LockVault(address(membershipNft), address(vaultToken), treasury, REWARD_RATE);

        membershipNft.setVaultAddress(address(vault));
        vaultToken.setVaultAddress(address(vault));

        token18 = new LocalMockERC20Decimals("Token18", "TK18", 18);
        token6 = new LocalMockERC20Decimals("Token6", "TK06", 6);
        token20 = new LocalMockERC20Decimals("Token20", "TK20", 20);

        feed18 = new MockOracleFeed(2_000e8);
        feed6 = new MockOracleFeed(1_000e8);
        feed20 = new MockOracleFeed(500e8);

        vault.addToken(address(token18), address(feed18));
        vault.addToken(address(token6), address(feed6));
        vault.addToken(address(token20), address(feed20));

        token18.mint(alice, 1_000_000e18);
        token6.mint(alice, 2_000_000e6);
        token20.mint(alice, 1_000_000e20);

        token18.mint(bob, 1_000_000e18);
        token18.mint(carol, 1_000_000e18);

        vm.startPrank(alice);
        token18.approve(address(vault), type(uint256).max);
        token6.approve(address(vault), type(uint256).max);
        token20.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        token18.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(carol);
        token18.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function _deployVaultWithUnlinkedMintToken() internal returns (LockVault failingVault, LocalMockERC20Decimals failingToken) {
        MembershipNFT localNft = new MembershipNFT();
        VaultToken localVaultToken = new VaultToken();

        failingVault = new LockVault(address(localNft), address(localVaultToken), treasury, REWARD_RATE);
        localNft.setVaultAddress(address(failingVault));

        MockOracleFeed localFeed = new MockOracleFeed(2_000e8);
        failingToken = new LocalMockERC20Decimals("FailToken", "FAIL", 18);

        failingVault.addToken(address(failingToken), address(localFeed));

        failingToken.mint(alice, 1_000_000e18);
        vm.startPrank(alice);
        failingToken.approve(address(failingVault), type(uint256).max);
        vm.stopPrank();
    }

    function test_Constructor_RevertZeroMembership() public {
        vm.expectRevert(ILockVault.ZeroAddress.selector);
        new LockVault(address(0), address(vaultToken), treasury, REWARD_RATE);
    }

    function test_Constructor_RevertZeroVaultToken() public {
        vm.expectRevert(ILockVault.ZeroAddress.selector);
        new LockVault(address(membershipNft), address(0), treasury, REWARD_RATE);
    }

    function test_Constructor_RevertInvalidTreasury() public {
        vm.expectRevert(ILockVault.InvalidTreasury.selector);
        new LockVault(address(membershipNft), address(vaultToken), address(0), REWARD_RATE);
    }

    function test_Constructor_RevertZeroRewardRate() public {
        vm.expectRevert(ILockVault.ZeroAmount.selector);
        new LockVault(address(membershipNft), address(vaultToken), treasury, 0);
    }

    function test_AddToken_RevertZeroAddress() public {
        vm.expectRevert(ILockVault.ZeroAddress.selector);
        vault.addToken(address(0), address(feed18));
    }

    function test_AddToken_RevertAlreadyWhitelisted() public {
        vm.expectRevert(abi.encodeWithSelector(ILockVault.TokenAlreadyWhitelisted.selector, address(token18)));
        vault.addToken(address(token18), address(feed18));
    }

    function test_AddToken_RevertNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.addToken(address(0x123), address(0x456));
    }

    function test_RemoveToken_RevertNotWhitelisted() public {
        vm.expectRevert(abi.encodeWithSelector(ILockVault.NotWhitelisted.selector, address(0x9999)));
        vault.removeToken(address(0x9999));
    }

    function test_RemoveToken_RevertNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.removeToken(address(token18));
    }

    function test_RemoveToken_Success() public {
        vault.removeToken(address(token18));
        assertFalse(vault.isWhitelisted(address(token18)));
    }

    function test_SetTreasury_RevertNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.setTreasury(address(0xABCD));
    }

    function test_SetTreasury_RevertZeroAddress() public {
        vm.expectRevert(ILockVault.InvalidTreasury.selector);
        vault.setTreasury(address(0));
    }

    function test_SetTreasury_Success() public {
        address newTreasury = address(0xABCD);
        vault.setTreasury(newTreasury);
        assertEq(vault.treasury(), newTreasury);
    }

    function test_Stake_RevertZeroAddressToken() public {
        vm.prank(alice);
        vm.expectRevert(ILockVault.ZeroAddress.selector);
        vault.stake(address(0), 1e18, ILockVault.LockTier.ThirtyDays);
    }

    function test_Stake_RevertZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(ILockVault.ZeroAmount.selector);
        vault.stake(address(token18), 0, ILockVault.LockTier.ThirtyDays);
    }

    function test_Stake_RevertNotWhitelisted() public {
        LocalMockERC20Decimals randomToken = new LocalMockERC20Decimals("Random", "RND", 18);
        randomToken.mint(alice, 100e18);

        vm.startPrank(alice);
        randomToken.approve(address(vault), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(ILockVault.NotWhitelisted.selector, address(randomToken)));
        vault.stake(address(randomToken), 1e18, ILockVault.LockTier.ThirtyDays);
        vm.stopPrank();
    }

    function test_Stake_RevertWhenMaxActiveStakesReached() public {
        vm.startPrank(alice);
        for (uint256 i = 0; i < vault.MAX_ACTIVE_STAKES(); i++) {
            vault.stake(address(token18), 1e18, ILockVault.LockTier.ThirtyDays);
        }

        vm.expectRevert(ILockVault.MaxStakesReached.selector);
        vault.stake(address(token18), 1e18, ILockVault.LockTier.ThirtyDays);
        vm.stopPrank();
    }

    function test_Stake_UpdatesAccountingAndMintsBronze() public {
        vm.prank(alice);
        vault.stake(address(token18), 1_000e18, ILockVault.LockTier.ThirtyDays);

        assertEq(vault.userStakeCount(alice), 1);
        assertEq(vault.activeStakeCount(alice), 1);
        assertEq(vault.totalStakedPerToken(address(token18)), 1_000e18);
        assertEq(vault.userTotalStake(alice), 1_000e18);
        assertEq(vault.userTotalNormalizedStake(alice), 1_000e18);

        IMembershipNFT.MemberInfo memory info = membershipNft.getMemberInfo(alice);
        assertEq(info.tokenId, 1);
        assertEq(uint8(info.tier), uint8(IMembershipNFT.Tier.Bronze));
    }

    function test_Stake_NormalizesDecimalsLessThan18() public {
        vm.prank(alice);
        vault.stake(address(token6), 1_000e6, ILockVault.LockTier.ThirtyDays);

        assertEq(vault.userTotalNormalizedStake(alice), 1_000e18);
        assertEq(vault.totalNormalizedStakePerToken(address(token6)), 1_000e18);
    }

    function test_Stake_NormalizesDecimalsGreaterThan18() public {
        vm.prank(alice);
        vault.stake(address(token20), 1_000e20, ILockVault.LockTier.ThirtyDays);

        assertEq(vault.userTotalNormalizedStake(alice), 1_000e18);
        assertEq(vault.totalNormalizedStakePerToken(address(token20)), 1_000e18);
    }

    function test_GetPendingRewards_RevertInvalidIndex() public {
        vm.expectRevert(abi.encodeWithSelector(ILockVault.InvalidStakeIndex.selector, 0, 0));
        vault.getPendingRewards(alice, 0);
    }

    function test_GetPendingRewards_ReturnsZeroForClaimedStake() public {
        vm.prank(alice);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + 31 days);

        vm.prank(alice);
        vault.withdraw(0);

        assertEq(vault.getPendingRewards(alice, 0), 0);
    }

    function test_Withdraw_RevertInvalidIndex() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ILockVault.InvalidStakeIndex.selector, 0, 0));
        vault.withdraw(0);
    }

    function test_Withdraw_RevertBeforeUnlock() public {
        vm.prank(alice);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.ThirtyDays);

        uint256 unlockTime = block.timestamp + vault.THIRTY_DAYS_LOCK_TIER();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ILockVault.LockNotExpired.selector, unlockTime));
        vault.withdraw(0);
    }

    function test_Withdraw_CoversAllTierDurationPaths() public {
        vm.startPrank(alice);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.ThirtyDays);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.NinetyDays);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.OneEightyDays);
        vm.stopPrank();

        vm.warp(block.timestamp + 181 days);

        uint256 r0 = vault.getPendingRewards(alice, 0);
        uint256 r1 = vault.getPendingRewards(alice, 1);
        uint256 r2 = vault.getPendingRewards(alice, 2);

        assertGt(r0, 0);
        assertGt(r1, r0);
        assertGt(r2, r1);

        vm.startPrank(alice);
        vault.withdraw(0);
        vault.withdraw(1);
        vault.withdraw(2);
        vm.stopPrank();

        assertEq(vault.activeStakeCount(alice), 0);
    }

    function test_Withdraw_RevertAlreadyClaimed() public {
        vm.prank(alice);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + 31 days);

        vm.startPrank(alice);
        vault.withdraw(0);
        vm.expectRevert(abi.encodeWithSelector(ILockVault.AlreadyClaimed.selector, 0));
        vault.withdraw(0);
        vm.stopPrank();
    }

    function test_Withdraw_EmitsRewardMintFailedWhenMintReverts() public {
        (LockVault failingVault, LocalMockERC20Decimals failingToken) = _deployVaultWithUnlinkedMintToken();

        vm.prank(alice);
        failingVault.stake(address(failingToken), 100e18, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + 31 days);

        vm.expectEmit(true, true, false, true);
        emit ILockVault.RewardMintFailed(alice, 0, failingVault.getPendingRewards(alice, 0));

        vm.prank(alice);
        failingVault.withdraw(0);
    }

    function test_EmergencyWithdraw_RevertInvalidIndex() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ILockVault.InvalidStakeIndex.selector, 0, 0));
        vault.emergencyWithdraw(0);
    }

    function test_EmergencyWithdraw_RevertIfLockExpired() public {
        vm.prank(alice);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + 31 days);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ILockVault.LockNotExpired.selector, 0));
        vault.emergencyWithdraw(0);
    }

    function test_EmergencyWithdraw_SplitsRewardsAndReturnsPrincipal() public {
        uint256 startBal = token18.balanceOf(alice);

        vm.prank(alice);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + 10 days);
        uint256 expectedTotalReward = vault.getPendingRewards(alice, 0);

        vm.prank(alice);
        vault.emergencyWithdraw(0);

        assertEq(token18.balanceOf(alice), startBal);
        assertEq(vaultToken.balanceOf(alice) + vaultToken.balanceOf(treasury), expectedTotalReward);
        assertEq(vault.activeStakeCount(alice), 0);
    }

    function test_EmergencyWithdraw_RevertAlreadyClaimed() public {
        vm.prank(alice);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + 10 days);

        vm.startPrank(alice);
        vault.emergencyWithdraw(0);
        vm.expectRevert(abi.encodeWithSelector(ILockVault.AlreadyClaimed.selector, 0));
        vault.emergencyWithdraw(0);
        vm.stopPrank();
    }

    function test_EmergencyWithdraw_EmitsMintFailureEventsWhenMintReverts() public {
        (LockVault failingVault, LocalMockERC20Decimals failingToken) = _deployVaultWithUnlinkedMintToken();

        vm.prank(alice);
        failingVault.stake(address(failingToken), 100e18, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + 5 days);
        uint256 totalReward = failingVault.getPendingRewards(alice, 0);
        uint256 userReward = totalReward / 2;
        uint256 penalty = totalReward - userReward;

        vm.expectEmit(true, true, false, true);
        emit ILockVault.RewardMintFailed(alice, 0, userReward);
        vm.expectEmit(true, true, false, true);
        emit ILockVault.PenaltyMintFailed(treasury, 0, penalty);

        vm.prank(alice);
        failingVault.emergencyWithdraw(0);
    }

    function test_UpgradeMembershipTier_RevertWhenNotEligible() public {
        vm.prank(alice);
        vault.stake(address(token18), 1_000e18, ILockVault.LockTier.ThirtyDays);

        vm.prank(alice);
        vm.expectRevert(ILockVault.UpgradeNotPossible.selector);
        vault.upgradeMembershipTier();
    }

    function test_UpgradeMembershipTier_BronzeToSilver() public {
        vm.startPrank(alice);
        vault.stake(address(token18), 1_000e18, ILockVault.LockTier.ThirtyDays);
        vault.stake(address(token18), 4_000e18, ILockVault.LockTier.ThirtyDays);
        vault.upgradeMembershipTier();
        vm.stopPrank();

        assertEq(uint8(membershipNft.getTier(alice)), uint8(IMembershipNFT.Tier.Silver));
    }

    function test_UpgradeMembershipTier_SilverToGold() public {
        vm.startPrank(alice);
        vault.stake(address(token18), 5_000e18, ILockVault.LockTier.ThirtyDays);
        vault.stake(address(token18), 5_000e18, ILockVault.LockTier.ThirtyDays);
        vault.upgradeMembershipTier();
        vm.stopPrank();

        assertEq(uint8(membershipNft.getTier(alice)), uint8(IMembershipNFT.Tier.Gold));
    }

    function test_MembershipBonus_CoversNoBonusBronzeSilverGold() public {
        vm.prank(address(vault));
        membershipNft.mint(bob, IMembershipNFT.Tier.Bronze);

        vm.prank(address(vault));
        membershipNft.mint(carol, IMembershipNFT.Tier.Gold);

        address dave = address(0xDAE0);
        token18.mint(dave, 1_000_000e18);
        vm.prank(dave);
        token18.approve(address(vault), type(uint256).max);

        vm.startPrank(alice);
        vault.stake(address(token18), 1_000e18, ILockVault.LockTier.ThirtyDays);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.ThirtyDays);
        vm.stopPrank();

        vm.startPrank(bob);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.ThirtyDays);
        vm.stopPrank();

        vm.startPrank(carol);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.ThirtyDays);
        vm.stopPrank();

        vm.startPrank(dave);
        vault.stake(address(token18), 100e18, ILockVault.LockTier.ThirtyDays);
        vm.stopPrank();

        vm.warp(block.timestamp + 5 days);

        uint256 noBonusReward = vault.getPendingRewards(dave, 0);
        uint256 bronzeReward = vault.getPendingRewards(bob, 0);
        uint256 autoBronzeReward = vault.getPendingRewards(alice, 1);
        uint256 goldReward = vault.getPendingRewards(carol, 0);

        assertEq(bronzeReward, autoBronzeReward);
        assertGt(bronzeReward, noBonusReward);
        assertGt(goldReward, bronzeReward);

        vm.prank(address(vault));
        membershipNft.upgradeTier(bob, IMembershipNFT.Tier.Silver);
        uint256 silverReward = vault.getPendingRewards(bob, 0);
        assertGt(silverReward, bronzeReward);
    }

    function test_GetTotalValueLocked_RevertForNotWhitelistedToken() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(0x12345);

        vm.expectRevert(abi.encodeWithSelector(ILockVault.NotWhitelisted.selector, tokens[0]));
        vault.getTotalValueLocked(tokens);
    }

    function test_GetTotalValueLocked_HandlesZeroStakeTokenAndCalculates() public {
        vm.prank(alice);
        vault.stake(address(token18), 10e18, ILockVault.LockTier.ThirtyDays);

        address[] memory tokens = new address[](3);
        tokens[0] = address(token18);
        tokens[1] = address(token6);
        tokens[2] = address(token20);

        uint256 tvl = vault.getTotalValueLocked(tokens);
        uint256 expected = (10e18 * 2_000e8) / 1e18;
        assertEq(tvl, expected);
    }

    function test_GetTotalValueLocked_RevertInvalidPrice() public {
        LocalMockERC20Decimals badToken = new LocalMockERC20Decimals("Bad", "BAD", 18);
        MockOracleFeed badFeed = new MockOracleFeed(-1);
        vault.addToken(address(badToken), address(badFeed));

        badToken.mint(alice, 100e18);
        vm.startPrank(alice);
        badToken.approve(address(vault), type(uint256).max);
        vault.stake(address(badToken), 100e18, ILockVault.LockTier.ThirtyDays);
        vm.stopPrank();

        address[] memory tokens = new address[](1);
        tokens[0] = address(badToken);

        vm.expectRevert(abi.encodeWithSelector(ILockVault.InvalidPrice.selector, address(badToken)));
        vault.getTotalValueLocked(tokens);
    }

    function test_GetTotalValueLocked_RevertStalePrice() public {
        vm.prank(alice);
        vault.stake(address(token18), 10e18, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + vault.STALENESS_THRESHOLD() + 1);

        address[] memory tokens = new address[](1);
        tokens[0] = address(token18);

        vm.expectRevert(abi.encodeWithSelector(ILockVault.StalePrice.selector, address(token18)));
        vault.getTotalValueLocked(tokens);
    }
}