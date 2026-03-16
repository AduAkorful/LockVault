// ReadFunctions.ts
import type { Address } from "viem";
import { publicClient } from "../Clients";
import { LOCKVAULT_ADDRESS } from "../network";
import { LockVaultABI } from "../abi/LockVaultABI";

export async function getPendingRewards(user: Address, stakeIndex: bigint) {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "getPendingRewards",
    args: [user, stakeIndex],
  });
}

export async function getTotalValueLocked(tokens: Address[]) {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "getTotalValueLocked",
    args: [tokens],
  });
}

export async function getTreasury() {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "treasury",
  });
}

export async function getRewardRate() {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "REWARD_RATE",
  });
}

export async function getMaxActiveStakes() {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "MAX_ACTIVE_STAKES",
  });
}

export async function getMembershipNftAddress() {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "MEMBERSHIP_NFT",
  });
}

export async function getVaultTokenAddress() {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "VAULT_TOKEN",
  });
}

export async function getUserStakeCount(user: Address) {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "userStakeCount",
    args: [user],
  });
}

export async function getActiveStakeCount(user: Address) {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "activeStakeCount",
    args: [user],
  });
}

export async function getUserTotalStake(user: Address) {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "userTotalStake",
    args: [user],
  });
}

export async function getIsWhitelisted(token: Address) {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "isWhitelisted",
    args: [token],
  });
}

export async function getTokenPriceFeed(token: Address) {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "tokenPriceFeed",
    args: [token],
  });
}

export async function getTotalStakedPerToken(token: Address) {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "totalStakedPerToken",
    args: [token],
  });
}

export async function getTotalNormalizedStakePerToken(token: Address) {
  return publicClient.readContract({
    address: LOCKVAULT_ADDRESS,
    abi: LockVaultABI,
    functionName: "totalNormalizedStakePerToken",
    args: [token],
  });
}
