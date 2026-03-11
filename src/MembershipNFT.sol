// SPDX-License-Identifier:MIT

pragma solidity 0.8.33;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IMembershipNFT} from "./interfaces/IMembershipNFT.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract MembershipNFT is ERC721, IMembershipNFT, Ownable2Step {
    // TokenId incremented before every mint
    uint256 private _nextTokenId;

    // The authorized LockVault contract permitted to call mint.
    address public vault;

    // A mapping of members info to their addresses
    mapping(address => MemberInfo) private _memberInfo;

    // Constructor defining nft name and symbol
    // Also defines the owner role
    constructor() ERC721("LockVault Membership", "LVM") Ownable(msg.sender) {}

    // Sets the _vault address of the LockVault contract
    function setVault(address _vault) external onlyOwner {
        if (vault != address(0)) revert VaultAlreadySet();
        if (_vault == address(0)) revert ZeroAddress();
        vault = _vault;

        emit VaultSet(_vault);
    }

    // getter function for the bronze tier
    function getBronzeTier() external pure returns (uint8) {
        return uint8(Tier.Bronze);
    }

    // getter function for silver tier
    function getSilverTier() external pure returns (uint8) {
        return uint8(Tier.Silver);
    }

    // getter function for gold tier
    function getGoldTier() external pure returns (uint8) {
        return uint8(Tier.Gold);
    }

    // Mints new membership nft to user based on their tier
    // Function is restricted to only the owner and it emits the MembershipMinted event
    function mint(address to, Tier tier) external {
        if (msg.sender != vault) revert NotVault();
        if (_memberInfo[to].tokenId != 0) revert AlreadyHasMembership();

        uint256 tokenId = ++_nextTokenId;

        _memberInfo[to] = MemberInfo({tier: tier, tokenId: tokenId});
        _safeMint(to, tokenId);

        emit MembershipMinted(to, tokenId, tier);
    }

    // Returns the membership tier of user
    function getTier(address user) external view returns (Tier) {
        if (_memberInfo[user].tokenId == 0) revert NoMembership();
        return _memberInfo[user].tier;
    }

    // Returns member information which is the tier and tokenId
    function getMemberInfo(address user) external view returns (MemberInfo memory info) {
        return _memberInfo[user];
    }

    // Internal logic to mint an nft which restricts transferring and burning tokens
    // Restricting address(0) means every user address can't mint and also ensures tokens are soulbound
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0)) revert SoulboundTransferForbidden();
        return super._update(to, tokenId, auth);
    }

    function upgradeTier(address user, Tier newTier) external {
        if (user == address(0)) revert ZeroAddress();
        if (_memberInfo[user].tokenId == 0) revert NoMembership();

        _memberInfo[user].tier = newTier;

        emit MembershipUpgraded(user, newTier);
    }
}
