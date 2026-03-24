// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {MembershipNFT} from "../src/MembershipNFT.sol";
import {IMembershipNFT} from "../src/interfaces/IMembershipNFT.sol";

contract MembershipNFTFuzzTest is Test {
    MembershipNFT internal membershipNft;

    address internal vault = address(0x1234);
    address internal user = address(0x5678);

    function setUp() public {
        membershipNft = new MembershipNFT();
        membershipNft.setVaultAddress(vault);
    }

    function testFuzz_SetTierURI_RoundTrip(string memory uri) public {
        membershipNft.setTierURI(IMembershipNFT.Tier.Bronze, uri);
        assertEq(membershipNft.getTierURI(IMembershipNFT.Tier.Bronze), uri);
    }

    function testFuzz_MintAndUpgradePreservesTokenOwnership(uint8 initialTierRaw, uint8 newTierRaw) public {
        uint8 boundedInitial = uint8(bound(initialTierRaw, 0, 2));
        uint8 boundedNew = uint8(bound(newTierRaw, 0, 2));

        vm.prank(vault);
        membershipNft.mint(user, IMembershipNFT.Tier(boundedInitial));

        vm.prank(vault);
        membershipNft.upgradeTier(user, IMembershipNFT.Tier(boundedNew));

        IMembershipNFT.MemberInfo memory info = membershipNft.getMemberInfo(user);
        assertEq(info.tokenId, 1);
        assertEq(uint8(info.tier), boundedNew);
        assertEq(membershipNft.ownerOf(1), user);
    }
}
