// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {IVaultToken} from "../src/interfaces/IVaultToken.sol";

contract VaultTokenUnitTest is Test {
    VaultToken internal vaultToken;

    address internal owner = address(this);
    address internal vault = address(0xA11CE);
    address internal user = address(0xB0B);

    function setUp() public {
        vaultToken = new VaultToken();
    }

    function test_Constructor_SetsMetadata() public view {
        assertEq(vaultToken.name(), "VaultToken");
        assertEq(vaultToken.symbol(), "VTK");
        assertEq(vaultToken.owner(), owner);
    }

    function test_SetVaultAddress_RevertsForNonOwner() public {
        vm.prank(user);
        vm.expectRevert();
        vaultToken.setVaultAddress(vault);
    }

    function test_SetVaultAddress_RevertsForZeroAddress() public {
        vm.expectRevert(IVaultToken.ZeroAddress.selector);
        vaultToken.setVaultAddress(address(0));
    }

    function test_SetVaultAddress_SetsVault() public {
        vaultToken.setVaultAddress(vault);
        assertEq(vaultToken.vault(), vault);
    }

    function test_Mint_RevertsForNonVault() public {
        vm.expectRevert(IVaultToken.NotVault.selector);
        vaultToken.mint(user, 1e18);
    }

    function test_Mint_RevertsOnCapExceeded() public {
        vaultToken.setVaultAddress(vault);
        uint256 maxSupply = vaultToken.MAX_SUPPLY();

        vm.prank(vault);
        vaultToken.mint(user, maxSupply);

        vm.prank(vault);
        vm.expectRevert(IVaultToken.CapExceeded.selector);
        vaultToken.mint(user, 1);
    }

    function test_Mint_SucceedsWithinCap() public {
        vaultToken.setVaultAddress(vault);

        vm.prank(vault);
        vaultToken.mint(user, 123e18);

        assertEq(vaultToken.balanceOf(user), 123e18);
        assertEq(vaultToken.totalSupply(), 123e18);
    }
}
