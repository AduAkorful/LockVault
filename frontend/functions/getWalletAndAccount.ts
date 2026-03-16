import type { Address } from "viem";
import { getConnection, getWalletClient } from "@wagmi/core";
import { wagmiConfig } from "./wagmiConfig";

export async function getWalletAndAccount() {
  const accountState = getConnection(wagmiConfig);

  if (!accountState.isConnected || !accountState.address) {
    throw new Error(
      "Wallet is not connected. Please connect with RainbowKit first.",
    );
  }

  const walletClient = await getWalletClient(wagmiConfig);

  if (!walletClient) {
    throw new Error(
      "Wallet client unavailable. Reconnect wallet and try again.",
    );
  }

  return {
    walletClient,
    account: accountState.address as Address,
  };
}
