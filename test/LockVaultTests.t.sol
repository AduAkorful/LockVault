// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {LockVault} from "../src/LockVault.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {MembershipNFT} from "../src/MembershipNFT.sol";
import {MockOracleFeed} from "../src/MockOracleFeed.sol";
import {ILockVault} from "../src/interfaces/ILockVault.sol";
import {IMembershipNFT} from "../src/interfaces/IMembershipNFT.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MCK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LockVaultTest is Test {
    LockVault public vault;
    VaultToken public vaultToken;
    MembershipNFT public membershipNft;
    MockOracleFeed public priceFeed;
    MockERC20 public stakingToken;

    address public owner = address(100);
    address public user = address(101);
    address public treasury = address(102);

    uint256 public constant REWARD_RATE = 1e9;

    function setUp() public {
        vm.startPrank(owner);

        membershipNft = new MembershipNFT();
        vaultToken = new VaultToken();
        vault = new LockVault(address(membershipNft), address(vaultToken), treasury);

        // Link contracts - This can only be done once per instance
        membershipNft.setVault(address(vault));
        vaultToken.setVaultAddress(address(vault));
        vault.setRewardRate(REWARD_RATE);

        priceFeed = new MockOracleFeed(2000 * 1e8, block.timestamp);
        stakingToken = new MockERC20();

        vault.addToken(address(stakingToken), address(priceFeed));

        vm.stopPrank();

        stakingToken.mint(user, 100_000 * 1e18);
        vm.prank(user);
        stakingToken.approve(address(vault), type(uint256).max);
    }

    // --- VaultToken Tests ---

    function test_VaultTokenMintingAndCap() public {
        // Deploy fresh instances to avoid state crossover logic
        vm.startPrank(owner);
        VaultToken freshToken = new VaultToken();
        address dummyVault = address(0x999);
        freshToken.setVaultAddress(dummyVault); 
        vm.stopPrank();

        uint256 maxSupply = freshToken.MAX_SUPPLY();
        
        vm.prank(dummyVault);
        freshToken.mint(user, maxSupply);
        assertEq(freshToken.totalSupply(), maxSupply);

        vm.expectRevert(); // CapExceeded
        vm.prank(dummyVault);
        freshToken.mint(user, 1);
    }

    function test_VaultToken_OnlyVault() public {
        vm.prank(user);
        vm.expectRevert(); // NotVault
        vaultToken.mint(user, 100);
    }

    // --- MembershipNFT Tests ---

    function test_MembershipNFT_Soulbound() public {
        vm.startPrank(owner);
        MembershipNFT freshNft = new MembershipNFT();
        
        // Use a dummy address for the vault so we can bypass 'NotVault' during minting
        address dummyVault = address(0x999);
        freshNft.setVault(dummyVault);
        vm.stopPrank();

        // Mint as the customized "vault"
        vm.prank(dummyVault);
        freshNft.mint(user, IMembershipNFT.Tier.Bronze);
        
        assertEq(freshNft.balanceOf(user), 1);

        uint256 tokenId = 1;

        vm.prank(user);
        vm.expectRevert(); // SoulboundTransferForbidden
        freshNft.transferFrom(user, address(666), tokenId);
    }

    function test_MembershipNFT_TierRetrieval() public {
        vm.startPrank(owner);
        MembershipNFT freshNft = new MembershipNFT();
        address dummyVault = address(0x999);
        freshNft.setVault(dummyVault);
        vm.stopPrank();

        // Mint as the vault
        vm.prank(dummyVault);
        freshNft.mint(user, IMembershipNFT.Tier.Gold);

        assertEq(uint256(freshNft.getTier(user)), uint256(IMembershipNFT.Tier.Gold));
    }

    // --- MockPriceFeed Tests ---

    function test_MockPriceFeed_SettingAndRetrieval() public {
        int256 newPrice = 3000 * 1e8;
        vm.prank(owner);
        priceFeed.setPrice(newPrice, block.timestamp);

        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
        assertEq(price, newPrice);
        assertEq(updatedAt, block.timestamp);
    }

    // --- Staking and Withdrawal Tests ---

    function test_StakingAndWithdrawal() public {
        uint256 stakeAmount = 1000 * 1e18;
        vm.prank(user);
        vault.stake(address(stakingToken), stakeAmount, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + 31 days);

        uint256 preBalance = vaultToken.balanceOf(user);
        vm.prank(user);
        vault.withdraw(0);
        uint256 postBalance = vaultToken.balanceOf(user);

        assertTrue(postBalance > preBalance, "Rewards should be minted");
        assertEq(stakingToken.balanceOf(user), 100_000 * 1e18);
    }

    function test_EmergencyWithdrawal() public {
        uint256 stakeAmount = 1000 * 1e18;
        vm.prank(user);
        vault.stake(address(stakingToken), stakeAmount, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + 10 days);

        uint256 preBalanceToken = vaultToken.balanceOf(user);
        uint256 preBalanceTreasury = vaultToken.balanceOf(treasury);

        vm.prank(user);
        vault.emergencyWithdraw(0);

        uint256 postBalanceToken = vaultToken.balanceOf(user);
        uint256 postBalanceTreasury = vaultToken.balanceOf(treasury);

        assertTrue(postBalanceToken > preBalanceToken, "User should get half rewards");
        assertTrue(postBalanceTreasury > preBalanceTreasury, "Treasury should get half rewards");
        assertEq(stakingToken.balanceOf(user), 100_000 * 1e18);
    }

    // --- Membership Bonus Tests ---

    function test_MembershipBonusApplied() public {
        uint256 stakeAmount = 10_000 * 1e18;
        
        vm.prank(user);
        vault.stake(address(stakingToken), stakeAmount, ILockVault.LockTier.ThirtyDays);

        assertEq(uint256(membershipNft.getTier(user)), uint256(IMembershipNFT.Tier.Gold));

        vm.warp(block.timestamp + 31 days);
        
        vm.prank(user);
        vault.withdraw(0);
        
        uint256 rewards = vaultToken.balanceOf(user);
        assertTrue(rewards > 0);
    }

    // --- Access Control Tests ---

    function test_AccessControl_Unauthorized() public {
        vm.prank(user); // Should fail because not owner
        vm.expectRevert(); 
        vault.setRewardRate(2e9);
    }

    // --- Whitelisting Tests ---

    function test_WhitelistingAndDelisting() public {
        vm.startPrank(owner);
        vault.removeToken(address(stakingToken));
        assertFalse(vault.isWhitelisted(address(stakingToken)));

        vm.stopPrank();
        
        vm.prank(user);
        vm.expectRevert(); // Reverts with NotWhitelisted
        vault.stake(address(stakingToken), 100, ILockVault.LockTier.ThirtyDays);
    }

    // --- Fuzz Tests ---

    function testFuzz_StakeAmountAndRewardMath(uint256 amount, uint256 time) public {
        amount = bound(amount, 1e18, 10_000 * 1e18);
        time = bound(time, 30 days, 365 days);

        stakingToken.mint(user, amount);
        vm.prank(user);
        stakingToken.approve(address(vault), amount);

        vm.prank(user);
        vault.stake(address(stakingToken), amount, ILockVault.LockTier.ThirtyDays);

        vm.warp(block.timestamp + time);

        // Crucial: get index BEFORE the prank or use startPrank
        uint256 lastIndex = vault.userStakeCount(user) - 1;
        
        vm.prank(user);
        vault.withdraw(lastIndex);

        assertTrue(vaultToken.balanceOf(user) > 0);
    }
}
