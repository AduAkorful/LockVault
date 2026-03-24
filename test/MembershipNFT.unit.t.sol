// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {MembershipNFT} from "../src/MembershipNFT.sol";
import {IMembershipNFT} from "../src/interfaces/IMembershipNFT.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract MembershipNFTUnitTest is Test {
    MembershipNFT internal membershipNft;

    address internal vault = address(0x1111);
    address internal user = address(0x2222);
    address internal nonOwner = address(0x3333);

    function setUp() public {
        membershipNft = new MembershipNFT();
    }

    function test_Constructor_SetsMetadataAndOwner() public view {
        assertEq(membershipNft.name(), "LockVault Membership");
        assertEq(membershipNft.symbol(), "LVM");
        assertEq(membershipNft.owner(), address(this));
    }

    function test_SupportsInterface() public view {
        assertTrue(membershipNft.supportsInterface(type(IERC4906).interfaceId));
        assertTrue(membershipNft.supportsInterface(type(IERC721).interfaceId));
        assertFalse(membershipNft.supportsInterface(bytes4(0xffffffff)));
    }

    function test_SetVaultAddress_RevertZeroAddress() public {
        vm.expectRevert(IMembershipNFT.ZeroAddress.selector);
        membershipNft.setVaultAddress(address(0));
    }

    function test_SetVaultAddress_RevertNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        membershipNft.setVaultAddress(vault);
    }

    function test_SetVaultAddress_Success() public {
        membershipNft.setVaultAddress(vault);
        assertEq(membershipNft.vault(), vault);
    }

    function test_TierGetters_ReturnExpectedValues() public view {
        assertEq(membershipNft.getBronzeTier(), uint8(IMembershipNFT.Tier.Bronze));
        assertEq(membershipNft.getSilverTier(), uint8(IMembershipNFT.Tier.Silver));
        assertEq(membershipNft.getGoldTier(), uint8(IMembershipNFT.Tier.Gold));
    }

    function test_Mint_RevertNotVault() public {
        vm.expectRevert(IMembershipNFT.NotVault.selector);
        membershipNft.mint(user, IMembershipNFT.Tier.Bronze);
    }

    function test_Mint_RevertAlreadyHasMembership() public {
        membershipNft.setVaultAddress(vault);

        vm.startPrank(vault);
        membershipNft.mint(user, IMembershipNFT.Tier.Bronze);
        vm.expectRevert(IMembershipNFT.AlreadyHasMembership.selector);
        membershipNft.mint(user, IMembershipNFT.Tier.Silver);
        vm.stopPrank();
    }

    function test_Mint_AndGetters_Success() public {
        membershipNft.setVaultAddress(vault);

        vm.prank(vault);
        membershipNft.mint(user, IMembershipNFT.Tier.Silver);

        assertEq(membershipNft.balanceOf(user), 1);
        assertEq(uint8(membershipNft.getTier(user)), uint8(IMembershipNFT.Tier.Silver));

        IMembershipNFT.MemberInfo memory info = membershipNft.getMemberInfo(user);
        assertEq(uint8(info.tier), uint8(IMembershipNFT.Tier.Silver));
        assertEq(info.tokenId, 1);
    }

    function test_SetTierURI_AndTokenURI_Success() public {
        membershipNft.setVaultAddress(vault);

        membershipNft.setTierURI(IMembershipNFT.Tier.Bronze, "ipfs://bronze");
        membershipNft.setTierURI(IMembershipNFT.Tier.Silver, "ipfs://silver");
        membershipNft.setTierURI(IMembershipNFT.Tier.Gold, "ipfs://gold");

        vm.prank(vault);
        membershipNft.mint(user, IMembershipNFT.Tier.Bronze);

        assertEq(membershipNft.getTierURI(IMembershipNFT.Tier.Bronze), "ipfs://bronze");
        assertEq(membershipNft.tokenURI(1), "ipfs://bronze");
    }

    function test_SetTierURIs_BatchUpdate() public {
        membershipNft.setTierUrIs("b", "s", "g");

        assertEq(membershipNft.getTierURI(IMembershipNFT.Tier.Bronze), "b");
        assertEq(membershipNft.getTierURI(IMembershipNFT.Tier.Silver), "s");
        assertEq(membershipNft.getTierURI(IMembershipNFT.Tier.Gold), "g");
    }

    function test_GetTier_RevertNoMembership() public {
        vm.expectRevert(IMembershipNFT.NoMembership.selector);
        membershipNft.getTier(user);
    }

    function test_TokenURI_RevertForMissingToken() public {
        vm.expectRevert();
        membershipNft.tokenURI(999);
    }

    function test_SoulboundTransfer_Reverts() public {
        membershipNft.setVaultAddress(vault);

        vm.prank(vault);
        membershipNft.mint(user, IMembershipNFT.Tier.Bronze);

        vm.prank(user);
        vm.expectRevert(IMembershipNFT.SoulboundTransferForbidden.selector);
        membershipNft.transferFrom(user, nonOwner, 1);
    }

    function test_UpgradeTier_RevertNotVault() public {
        vm.expectRevert(IMembershipNFT.NotVault.selector);
        membershipNft.upgradeTier(user, IMembershipNFT.Tier.Gold);
    }

    function test_UpgradeTier_RevertZeroAddress() public {
        membershipNft.setVaultAddress(vault);
        vm.prank(vault);
        vm.expectRevert(IMembershipNFT.ZeroAddress.selector);
        membershipNft.upgradeTier(address(0), IMembershipNFT.Tier.Gold);
    }

    function test_UpgradeTier_RevertNoMembership() public {
        membershipNft.setVaultAddress(vault);
        vm.prank(vault);
        vm.expectRevert(IMembershipNFT.NoMembership.selector);
        membershipNft.upgradeTier(user, IMembershipNFT.Tier.Gold);
    }

    function test_UpgradeTier_Success() public {
        membershipNft.setVaultAddress(vault);

        vm.prank(vault);
        membershipNft.mint(user, IMembershipNFT.Tier.Bronze);

        vm.prank(vault);
        membershipNft.upgradeTier(user, IMembershipNFT.Tier.Gold);

        assertEq(uint8(membershipNft.getTier(user)), uint8(IMembershipNFT.Tier.Gold));
    }
}
