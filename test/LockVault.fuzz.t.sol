// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {LockVault} from "../src/LockVault.sol";
import {MembershipNFT} from "../src/MembershipNFT.sol";
import {MockOracleFeed} from "../src/MockOracleFeed.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {ILockVault} from "../src/interfaces/ILockVault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FuzzMockERC20Decimals is ERC20 {
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

contract LockVaultFuzzTest is Test {
    LockVault internal vault;
    MembershipNFT internal membershipNft;
    VaultToken internal vaultToken;
    FuzzMockERC20Decimals internal stakingToken;
    MockOracleFeed internal feed;

    address internal user = address(0xFEED);
    address internal treasury = address(0xBEEF);

    uint256 internal constant REWARD_RATE = 1e9;

    function setUp() public {
        membershipNft = new MembershipNFT();
        vaultToken = new VaultToken();
        vault = new LockVault(address(membershipNft), address(vaultToken), treasury, REWARD_RATE);

        membershipNft.setVaultAddress(address(vault));
        vaultToken.setVaultAddress(address(vault));

        stakingToken = new FuzzMockERC20Decimals("Stake", "STK", 18);
        feed = new MockOracleFeed(2_000e8);
        vault.addToken(address(stakingToken), address(feed));

        stakingToken.mint(user, 10_000_000e18);
        vm.prank(user);
        stakingToken.approve(address(vault), type(uint256).max);
    }

    function testFuzz_StakeThenWithdraw_MintsRewards(uint256 amount, uint256 elapsed, uint8 tierRaw) public {
        amount = bound(amount, 1e18, 50_000e18);
        elapsed = bound(elapsed, 0, 365 days);
        uint8 tierBounded = uint8(bound(tierRaw, 0, 2));

        vm.prank(user);
        vault.stake(address(stakingToken), amount, ILockVault.LockTier(tierBounded));

        vm.warp(block.timestamp + elapsed);

        uint256 duration;
        if (tierBounded == uint8(ILockVault.LockTier.ThirtyDays)) {
            duration = vault.THIRTY_DAYS_LOCK_TIER();
        } else if (tierBounded == uint8(ILockVault.LockTier.NinetyDays)) {
            duration = vault.NINETY_DAYS_LOCK_TIER();
        } else {
            duration = vault.ONE_EIGHTY_DAYS_LOCK_TIER();
        }

        if (elapsed < duration) {
            vm.prank(user);
            vm.expectRevert();
            vault.withdraw(0);
            return;
        }

        uint256 pendingBefore = vault.getPendingRewards(user, 0);
        vm.prank(user);
        vault.withdraw(0);

        assertEq(stakingToken.balanceOf(user), 10_000_000e18);
        assertEq(vault.getPendingRewards(user, 0), 0);
        assertEq(vaultToken.balanceOf(user), pendingBefore);
    }

    function testFuzz_EmergencyWithdraw_RewardSplitConservation(uint256 amount, uint256 elapsed) public {
        amount = bound(amount, 1e18, 50_000e18);
        elapsed = bound(elapsed, 0, 29 days);

        vm.prank(user);
        vault.stake(address(stakingToken), amount, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + elapsed);

        uint256 totalReward = vault.getPendingRewards(user, 0);

        vm.prank(user);
        vault.emergencyWithdraw(0);

        assertEq(vaultToken.balanceOf(user) + vaultToken.balanceOf(treasury), totalReward);
        assertEq(stakingToken.balanceOf(user), 10_000_000e18);
    }

    function testFuzz_GetTotalValueLocked_UsesNormalizedStake(uint256 amount6Decimals) public {
        FuzzMockERC20Decimals token6 = new FuzzMockERC20Decimals("Token6", "TK6", 6);
        MockOracleFeed token6Feed = new MockOracleFeed(1_234e8);
        vault.addToken(address(token6), address(token6Feed));

        amount6Decimals = bound(amount6Decimals, 1e6, 10_000_000e6);

        token6.mint(user, amount6Decimals);
        vm.startPrank(user);
        token6.approve(address(vault), amount6Decimals);
        vault.stake(address(token6), amount6Decimals, ILockVault.LockTier.ThirtyDays);
        vm.stopPrank();

        address[] memory tokens = new address[](1);
        tokens[0] = address(token6);

        uint256 expected = ((amount6Decimals * 1e12) * 1_234e8) / 1e18;
        uint256 tvl = vault.getTotalValueLocked(tokens);

        assertEq(tvl, expected);
    }
}