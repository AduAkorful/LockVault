import type { Address } from "viem";

const lockVaultAddress = import.meta.env.VITE_LOCKVAULT_ADDRESS as
  | Address
  | undefined;

if (!lockVaultAddress) {
  throw new Error("Missing VITE_LOCKVAULT_ADDRESS in frontend .env");
}

export const LOCKVAULT_ADDRESS = lockVaultAddress;
