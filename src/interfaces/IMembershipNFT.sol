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

    // Thrown when set vault is called more than once.
    error VaultAlreadySet();

    // Thrown when getTier is called for an address with no membership NFT
    error NoMembership();

    // Thrown when any token transfer other than minting is attempted
    error SoulboundTransferForbidden();

    // Emitted when a membership nft is minted to a user
    event MembershipMinted(address indexed to, uint256 indexed tokenId, Tier tier);

    // Mints new membership nft to user based on their tier
    function mint(address to, Tier tier) external;

    // Returns the membership tier of user
    function getTier(address user) external view returns (Tier);

    // Returns member information which is the tier and tokenId
    function getMemberInfo(address user) external view returns (MemberInfo memory info);

    // Called to set LockVault address
    function setVault(address _vault) external;
}
