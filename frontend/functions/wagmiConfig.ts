import "@rainbow-me/rainbowkit/styles.css";
import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia } from "wagmi/chains";

const projectId =
  import.meta.env.VITE_WALLETCONNECT_PROJECT_ID;

if (!projectId) {
  throw new Error("Missing VITE_WALLETCONNECT_PROJECT_ID in frontend .env");
}

export const wagmiConfig = getDefaultConfig({
  appName: "LockVault",
  projectId,
  chains: [sepolia],
  ssr: false,
});
