// SPDX-License-Identifier:MIT

pragma solidity 0.8.33;

interface IMembershipNFT {
    // Membership data showing the membership tier and the token owned by the member
    struct MemberInfo {
        Tier tier;
        uint256 tokenId;
    }

    // The three membership tiers ordered from lowest to highest
    enum Tier {
        Bronze,
        Silver,
        Gold
    }

    // Thrown when minting to an address that already holds a membership NFT
    error AlreadyHasMembership();

    // Thrown when input is a zero address
    error ZeroAddress();

    // Thrown when mint is called by an unauthorized address.
    error NotVault();

    // Thrown when getTier is called for an address with no membership NFT
    error NoMembership();

    // Thrown when any token transfer other than minting is attempted
    error SoulboundTransferForbidden();

    // Emitted when a membership nft is minted to a user
    event MembershipMinted(address indexed to, uint256 indexed tokenId, Tier tier);

    //Emitted when membership is upgraded
    event MembershipUpgraded(address indexed user, Tier indexed newTier);

    //Emitted when vault address is set
    event VaultSet(address vault);

    // Emitted when a metadata URI is updated for a tier
    event TierURIUpdated(Tier indexed tier, string uri);

    // Mints new membership nft to user based on their tier
    function mint(address to, Tier tier) external;

    // Sets metadata URI for a single tier
    function setTierURI(Tier tier, string calldata uri) external;

    // Sets metadata URIs for all tiers
    function setTierUrIs(string calldata bronzeUri, string calldata silverUri, string calldata goldUri) external;

    // Returns metadata URI for a tier
    function getTierURI(Tier tier) external view returns (string memory);

    // Returns the membership tier of user
    function getTier(address user) external view returns (Tier);

    // Returns member information which is the tier and tokenId
    function getMemberInfo(address user) external view returns (MemberInfo memory info);

    // Called to set LockVault address
    function setVaultAddress(address _vault) external;

    // getter function for the bronze tier
    function getBronzeTier() external view returns (uint8);

    // getter function for silver tier
    function getSilverTier() external view returns (uint8);

    // getter function for gold tier
    function getGoldTier() external view returns (uint8);

    // function to upgrade membership tier of user
    function upgradeTier(address user, Tier newTier) external;
}
