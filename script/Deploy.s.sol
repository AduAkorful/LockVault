// SPDX-License-Identifier:MIT

pragma solidity 0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {MembershipNFT} from "../src/MembershipNFT.sol";
import {LockVault} from "../src/LockVault.sol";
import {MockOracleFeed} from "../src/MockOracleFeed.sol";
import {MockEthToken} from "../src/MockEthToken.sol";

contract Deploy is Script {
    function run() external {
        // Direct configuration (updated as per your request)
        address treasury = msg.sender;
        uint256 rewardRate = 1e9;

        // Start broadcasting transactions using the account provided to forge script
        vm.startBroadcast();

        // 1. Deploy MembershipNFT
        MembershipNFT membershipNft = new MembershipNFT();
        console.log("MembershipNFT deployed at:", address(membershipNft));

        // 2. Deploy VaultToken
        VaultToken vaultToken = new VaultToken();
        console.log("VaultToken deployed at:", address(vaultToken));

        // 3. Deploy LockVault
        LockVault lockVault = new LockVault(address(membershipNft), address(vaultToken), treasury, rewardRate);
        console.log("LockVault deployed at:", address(lockVault));

        // 4. Link MembershipNFT and VaultToken to LockVault
        membershipNft.setVaultAddress(address(lockVault));
        console.log("Linked MembershipNFT to LockVault");

        // Set tier metadata URIs
        membershipNft.setTierUrIs(
            "ipfs://bafkreigoprtiwifyo4uw3fhhezaralnvjfrafyduahtswzgmzosnbsjn4a",
            "ipfs://bafkreibmsughfi4hlxzhe45u2g5rzwjxlf7mmg5pca3rm64qulcf5a5lcy",
            "ipfs://bafkreifmuh5afrq5ivyzjqrbljdy76tyx3flhgyzscbufp4ctvvseahyzi"
        );
        console.log("Set MembershipNFT tier URIs");

        vaultToken.setVaultAddress(address(lockVault));
        console.log("Linked VaultToken to LockVault");

        // 5. Deploy MockEthToken
        MockEthToken mockEthToken = new MockEthToken();
        console.log("MockEthToken deployed at:", address(mockEthToken));

        // 5. Deploy Mock Oracle Feed
        // Initial price of 2000 * 1e8 (Chainlink uses 8 decimals for USD feeds)
        MockOracleFeed ethFeed = new MockOracleFeed(2000 * 1e8);
        console.log("Mock ETH Feed deployed at:", address(ethFeed));

        // 6. Whitelist MockEthToken in LockVault with MockOracleFeed
        lockVault.addToken(address(mockEthToken), address(ethFeed));
        console.log("MockEthToken whitelisted in LockVault with MockOracleFeed");

        vm.stopBroadcast();

        console.log("\n--- Deployment Summary ---");
        console.log("Network ID:", block.chainid);
        console.log("LockVault:", address(lockVault));
        console.log("MembershipNFT:", address(membershipNft));
        console.log("VaultToken:", address(vaultToken));
        console.log("Mock ETH Feed:", address(ethFeed));
        console.log("Treasury:", treasury);
        console.log("Reward Rate:", rewardRate);
    }
}
