// SPDX-License-Identifier:MIT

pragma solidity 0.8.33;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IVaultToken} from "./interfaces/IVaultToken.sol";

contract VaultToken is ERC20, IVaultToken, Ownable2Step {
    // Set variable for maximum supply
    uint256 public constant MAX_SUPPLY = 10_000_000e18;

    // Initialize vault address to restrict minting function
    address public vault;

    // Constructor function set here since we are deploying a single token instance
    constructor() ERC20("VaultToken", "VTK") Ownable(msg.sender) {}

    // Function to set vault address which can be done only by the deployer
    function setVaultAddress(address _vault) external onlyOwner {
        if (vault != address(0)) revert VaultAlreadySet();
        if (_vault == address(0)) revert ZeroAddress();
        vault = _vault;
        emit VaultSet(_vault);
    }

    // Function to mint tokens which verifies the max supply won't be exceeded
    // Can only be called by the vault contract since onlyVault modifier is applied
    function mint(address _to, uint256 _amount) external {
        if (msg.sender != vault) revert NotVault();
        if (totalSupply() + _amount > MAX_SUPPLY) revert CapExceeded();
        _mint(_to, _amount);
    }
}
