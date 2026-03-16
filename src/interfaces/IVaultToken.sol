// SPDX-License-Identifier:MIT

pragma solidity 0.8.33;

interface IVaultToken {
    // Emitted when authorized minter is set
    event VaultSet(address indexed vault);

    // Thrown when address is a zero address
    error ZeroAddress();

    //Thrown when mint function is called by an address other than the vault
    error NotVault();

    // Thrown when a mint would push the total supply past the max supply
    error CapExceeded();

    // Called to set the address of the vault for minting
    function setVaultAddress(address _vault) external;

    // Mints tokens to an address
    function mint(address _to, uint256 _amount) external;
}
