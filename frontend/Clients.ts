import { createPublicClient, http } from "viem";
import { sepolia } from "viem/chains";

const RPC_URL = import.meta.env.VITE_SEPOLIA_RPC_URL;

if (!RPC_URL) {
  throw new Error("Missing VITE_SEPOLIA_RPC_URL in frontend .env");
}

export const publicClient = createPublicClient({
  chain: sepolia,
  transport: http(RPC_URL),
});
