import type { Address } from "viem";
import { parseEventLogs } from "viem";
import { publicClient } from "../Clients";
import { getWalletAndAccount } from "./getWalletAndAccount";
import { LOCKVAULT_ADDRESS } from "../network";
import { LockVaultABI } from "../abi/LockVaultABI";
import { ERC20ABI } from "../abi/ERC20TokenABI";

// Enum mapping known by the evm as just numbers
export type LockTier = 0 | 1 | 2;

export async function addToken(token: Address, priceFeed: Address) {
  try {
    const { walletClient, account } = await getWalletAndAccount();

    const hash = await walletClient.writeContract({
      address: LOCKVAULT_ADDRESS,
      abi: LockVaultABI,
      functionName: "addToken",
      args: [token, priceFeed],
      account,
    });

    await publicClient.waitForTransactionReceipt({ hash });

    return { hash };
  } catch (error) {
    throw new Error(`addToken failed: ${String(error)}`);
  }
}

export async function removeToken(token: Address) {
  try {
    const { walletClient, account } = await getWalletAndAccount();

    const hash = await walletClient.writeContract({
      address: LOCKVAULT_ADDRESS,
      abi: LockVaultABI,
      functionName: "removeToken",
      args: [token],
      account,
    });

    await publicClient.waitForTransactionReceipt({ hash });
    return { hash };
  } catch (error) {
    throw new Error(`removeToken failed: ${String(error)}`);
  }
}

export async function setTreasury(newTreasury: Address) {
  try {
    const { walletClient, account } = await getWalletAndAccount();

    const hash = await walletClient.writeContract({
      address: LOCKVAULT_ADDRESS,
      abi: LockVaultABI,
      functionName: "setTreasury",
      args: [newTreasury],
      account,
    });

    await publicClient.waitForTransactionReceipt({ hash });
    return { hash };
  } catch (error) {
    throw new Error(`setTreasury failed: ${String(error)}`);
  }
}

export async function approveToken(token: Address, amount: bigint) {
  try {
    const { walletClient, account } = await getWalletAndAccount();

    const allowance = await publicClient.readContract({
      address: token,
      abi: ERC20ABI,
      functionName: "allowance",
      args: [account, LOCKVAULT_ADDRESS],
    });

    if (allowance >= amount) {
      return {
        approvalNeeded: false,
        approvedAmount: allowance,
        approvalTxHash: null,
      };
    }

    const approvalTxHash = await walletClient.writeContract({
      address: token,
      abi: ERC20ABI,
      functionName: "approve",
      args: [LOCKVAULT_ADDRESS, amount],
      account,
    });

    const receipt = await publicClient.waitForTransactionReceipt({
      hash: approvalTxHash,
    });

    const log = parseEventLogs({
      abi: ERC20ABI,
      logs: receipt.logs,
      eventName: "Approval",
    })[0];

    return {
      approvalNeeded: true,
      approvedAmount: log.args.value,
      approvalTxHash,
    };
  } catch (error) {
    throw new Error(`approveToken failed: ${String(error)}`);
  }
}

export async function stake(token: Address, amount: bigint, tier: LockTier) {
  try {
    const { walletClient, account } = await getWalletAndAccount();

    const hash = await walletClient.writeContract({
      address: LOCKVAULT_ADDRESS,
      abi: LockVaultABI,
      functionName: "stake",
      args: [token, amount, tier],
      account,
    });

    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    // Parse first Staked event from receipt.
    const log = parseEventLogs({
      abi: LockVaultABI,
      logs: receipt.logs,
      eventName: "Staked",
    })[0];

    return {
      hash,
      stakeIndex: log.args.stakeIndex,
    };
  } catch (error) {
    throw new Error(`stake failed: ${String(error)}`);
  }
}

export async function withdraw(stakeIndex: bigint) {
  try {
    const { walletClient, account } = await getWalletAndAccount();

    const hash = await walletClient.writeContract({
      address: LOCKVAULT_ADDRESS,
      abi: LockVaultABI,
      functionName: "withdraw",
      args: [stakeIndex],
      account,
    });

    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    const log = parseEventLogs({
      abi: LockVaultABI,
      logs: receipt.logs,
      eventName: "Withdrawn",
    })[0];

    return {
      hash,
      principal: log.args.principal,
      rewards: log.args.rewards,
    };
  } catch (error) {
    throw new Error(`withdraw failed: ${String(error)}`);
  }
}

export async function emergencyWithdraw(stakeIndex: bigint) {
  try {
    const { walletClient, account } = await getWalletAndAccount();

    const hash = await walletClient.writeContract({
      address: LOCKVAULT_ADDRESS,
      abi: LockVaultABI,
      functionName: "emergencyWithdraw",
      args: [stakeIndex],
      account,
    });

    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    const log = parseEventLogs({
      abi: LockVaultABI,
      logs: receipt.logs,
      eventName: "EmergencyWithdrawn",
    })[0];

    return {
      hash,
      principal: log.args.principal,
      userRewards: log.args.userRewards,
      penalty: log.args.penalty,
    };
  } catch (error) {
    throw new Error(`emergencyWithdraw failed: ${String(error)}`);
  }
}

export async function upgradeMembershipTier() {
  try {
    const { walletClient, account } = await getWalletAndAccount();

    const hash = await walletClient.writeContract({
      address: LOCKVAULT_ADDRESS,
      abi: LockVaultABI,
      functionName: "upgradeMembershipTier",
      args: [],
      account,
    });

    const receipt = await publicClient.waitForTransactionReceipt({ hash });

    const log = parseEventLogs({
      abi: LockVaultABI,
      logs: receipt.logs,
      eventName: "MembershipUpgraded",
    })[0];

    return {
      hash,
      newTier: Number(log.args.newTier),
    };
  } catch (error) {
    throw new Error(`upgradeMembershipTier failed: ${String(error)}`);
  }
}
