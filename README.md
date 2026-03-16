# LockVault

## Project Overview
LockVault is a comprehensive decentralized staking protocol that enables users to deposit whitelisted ERC20 tokens into time-locked tiers (30, 90, or 180 days). In return for securing liquidity, users earn `VaultToken` (VTK) rewards dynamically calculated based on their lock duration and staking volume. The protocol features an integrated `MembershipNFT` system that automatically mints "soulbound" tier-based NFTs (Bronze, Silver, Gold) to high-volume stakers, granting them permanent reward multipliers. Membership metadata is managed per tier and exposed through standard ERC721 metadata (`tokenURI`) with IERC4906-compatible interface support for metadata updates. The protocol also includes an emergency withdrawal function that penalizes early unstaking by forfeiting 50% of accrued rewards to the protocol treasury while returning the initial principal.

## Design Decisions

### Access Control Pattern
I utilized OpenZeppelin's `Ownable2Step` for the primary administrative access control across the protocol. 
* **Why:** Unlike standard `Ownable`, which transfers ownership in a single transaction, `Ownable2Step` mitigates the catastrophic risk of accidentally transferring ownership to an incorrect or dead address. The new owner must actively `acceptOwnership()`, creating a safe fail-safe mechanism for admin roles (like setting reward rates or whitelisting tokens).

### NFT Minting Authorization Mechanism
The `MembershipNFT` and `VaultToken` contracts enforce vault-only access on their `mint()` functions via an inline `if (msg.sender != vault) revert NotVault()` check, so they can *only* be called by the `LockVault` contract address. 
* **Trust Model:** This assumes a "Hub and Spoke" trust model where the `LockVault` is the absolute source of truth for all state changes, calculations, and qualifications. The NFT and Token contracts are "dumb" ledgers that fully trust the Vault's math.
* **Trade-offs:** 
  * *Pros:* Keeps the NFT and Token contracts extremely simple, cheap to deploy, and isolates complex logic into one place. 
  * *Cons:* If the `LockVault` contract is ever compromised or needs to be upgraded, the deployer can call `setVaultAddress()` on both `MembershipNFT` and `VaultToken` to re-point both to the new vault address. During that transition, trust is temporarily placed in the deployer wallet holding the `Ownable` rights to execute those switches.

### Data Structure Strategy for Stakes
`LockVault` handles user deposits using a custom `Stake` struct, which is tracked via a double mapping: `mapping(address => mapping(uint256 => Stake)) private _userStakes;`.
* **Why Not an Array?** Instead of an array that grows infinitely (which increases gas costs for iterative loops or risks "Out of Gas" errors during bulk actions), this mapping pattern assigns a unique `stakeIndex` to each deposit.
* **Active State Tracking:** Users maintain independent stakes. They can withdraw `stakeIndex(0)` without affecting `stakeIndex(1)`. The use of `activeStakeCount` alongside a `MAX_ACTIVE_STAKES` variable protects the protocol from being spammed by infinite micro-stakes from a single user.

### Reward Engine and Math Precision
Rewards are calculated per second based on the principal amount, time elapsed, and two distinct multipliers (Tier Lock + Membership NFT).
* **Preserving Precision:** To handle token fractions without floating-point math issues, the `rewardRate` is scaled up by a `PRECISION` constant (`1e18`). During calculation `(_calculateRewards)`, the implementation uses staged `Math.mulDiv` operations (amount-rate, elapsed time, tier multiplier, and membership bonus) to keep arithmetic precise and overflow-safe.
* **Modular Math:** Multipliers are applied sequentially. First, the time lock tier multiplier (e.g., `250%` for 90 days), and finally the NFT bonus percentage (e.g., `+50%` for Gold).

### Edge Case Handling
* **Staking Zero Tokens:** The `stake()` function enforces a strict `if (amount == 0)` revert right at the top. This prevents users from artificially pumping their `userStakeCount` or emitting empty log events that clutter external indexers.
* **Delisted Tokens:** If an admin decides to remove an ERC20 from the whitelist (`removeToken()`), it immediately halts *new* deposits. However, existing active stakes containing that token are intentionally preserved. The `withdraw()` logic does not check `isWhitelisted`, allowing users to retrieve their principal and earned rewards respectfully.
* **Reward Token Cap Hit Mid-Claim:** `VaultToken` has a hard `MAX_SUPPLY` of 10M tokens. If a user tries to withdraw rewards but the max supply is exhausted, the `withdraw` transaction does **NOT** revert. I used a low-level `try/catch` block around the `.mint()` function. If the mint fails, the contract logs a `RewardMintFailed` event but still returns the user's principal collateral, ensuring user funds are never permanently locked due to protocol success/depletion.

## Security Considerations
Throughout the development of `LockVault`, several critical attack vectors were identified and mitigated:

1. **Reentrancy Attacks:**
   * *Vector:* A malicious token contract could attempt to re-enter the vault during withdrawal or staking to drain funds.
   * *Mitigation:* The contract strictly follows the **Checks-Effects-Interactions** pattern. Specifically in `withdraw()` and `emergencyWithdraw()`, the user's state (`activeStakeCount`, `totalStakedPerToken`, `s.claimed`) is fully updated *before* any external `safeTransfer` or `.mint()` calls are made. 

2. **Stale or Manipulated Oracle Pricing:**
   * *Vector:* The `getTotalValueLocked` function relies on Chainlink data. If an oracle feed stops updating, the vault might calculate metrics based on a drastically outdated price, causing incorrect TVL reporting or UI glitches.
   * *Mitigation:* A strict staleness check (`updateTime > STALENESS_THRESHOLD`) and a baseline price check (`price <= 0`) are implemented. If the oracle data is stale or invalid, the calculation safely reverts.

3. **Denial of Service (DoS) via Array Iteration:**
   * *Vector:* If a user could create an infinite number of stakes, looping through their stakes could eventually exceed the block gas limit, permanently trapping their funds or breaking global tracking.
   * *Mitigation:* A strict cap of `MAX_ACTIVE_STAKES = 20` is enforced per user. Furthermore, the contract intentionally avoids looping through dynamic arrays. Mappings and counters (`userStakeCount`) are used for O(1) state resolution.

4. **Malicious Token Integration:**
   * *Vector:* Exotic tokens (e.g., fee-on-transfer tokens) or malicious tokens without proper `approve`/`transferFrom` returns could break the vault accounting.
   * *Mitigation:* The contract utilizes OpenZeppelin's `SafeERC20` wrapper for all token interactions. The admin must explicitly whitelist tokens via `addToken()`, establishing a trusted perimeter. Token amounts are normalized to 18-decimal precision internally, so different ERC20 decimal formats are supported in accounting and reward-threshold tracking.

## Setup & Run Instructions

**Prerequisites**
Ensure you have [Foundry](https://book.getfoundry.sh/) installed on your machine.

**1. Compilation**
Clone the repository and compile the smart contracts utilizing the standard Forge command:
```bash
forge build
```

**2. Testing**
The repository includes a comprehensive testing suite that tests minting logic, caps, edge cases, and includes fuzz-testing for reward mathematics. To run the tests:
```bash
forge test -vvv
```

**3. Deployment Environment Setup**
First, set up your environment variables by copying the template file:
```bash
cp .env.example .env
```
Open the `.env` file and fill in your `RPC_URL` and `ETHERSCAN_API_KEY` (if verifying).

Next, import your private key into the secure Foundry keystore (replace `mywallet` with your preferred wallet name, which will prompt you to enter an interactive password and secret key):
```bash
cast wallet import mywallet --interactive
```

**4. Deploying**
A deployment script (`Deploy.s.sol`) is included to instantiate the LockVault, VaultToken, MembershipNFT, MockEthToken, and a Mock Oracle Feed on your chosen network. The script also links vault permissions and sets tier metadata URIs.

Source your environment variables:
```bash
source .env
```

Execute the deployment script (make sure you use the wallet name you configured during the `cast wallet import` step). *Note: After running this command, you will be prompted in the terminal to enter your keystore password to authorize the transaction.*

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --account mywallet --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
```

**5. Frontend Integration Environment Setup**
The frontend integration reads runtime values from `import.meta.env` (`VITE_*` keys). Copy the frontend template and set your values:

```bash
cp frontend/.env.example frontend/.env
```

Required frontend variables:
- `VITE_SEPOLIA_RPC_URL`
- `VITE_WALLETCONNECT_PROJECT_ID`
- `VITE_LOCKVAULT_ADDRESS`

---

## Live Deployments (Sepolia Testnet)

If you would rather interact with the deployed protocol directly without cloning the repository, you can access the verified contracts on the Sepolia testnet using the links below:

// To be updated after some updates.

### How to Interact via Etherscan

1. Navigate to the **LockVault** contract link above.
2. Click on the **Contract** tab, then select **Read Contract** or **Write Contract**.
3. If writing (e.g., staking or withdrawing), click the **"Connect to Web3"** button (usually indicating MetaMask or WalletConnect) to link your Sepolia wallet.
4. You can now call functions directly from your browser! 
   * *Tip:* To stake, remember you will first need to approve the LockVault to spend your underlying ERC20 tokens on the token's own Etherscan page.

