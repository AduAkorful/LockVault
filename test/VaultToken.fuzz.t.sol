// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {VaultToken} from "../src/VaultToken.sol";

contract VaultTokenFuzzTest is Test {
    VaultToken internal vaultToken;
    address internal vault = address(0xCAFE);
    address internal receiver = address(0xD00D);

    function setUp() public {
        vaultToken = new VaultToken();
        vaultToken.setVaultAddress(vault);
    }

    function testFuzz_MintWithinCap(uint256 amount) public {
        uint256 maxSupply = vaultToken.MAX_SUPPLY();
        amount = bound(amount, 1, maxSupply);

        vm.prank(vault);
        vaultToken.mint(receiver, amount);

        assertEq(vaultToken.balanceOf(receiver), amount);
        assertEq(vaultToken.totalSupply(), amount);
    }

    function testFuzz_MintRevertsWhenAboveCap(uint256 amount) public {
        uint256 maxSupply = vaultToken.MAX_SUPPLY();
        amount = bound(amount, 1, maxSupply);

        vm.prank(vault);
        vaultToken.mint(receiver, maxSupply - amount + 1);

        vm.prank(vault);
        vm.expectRevert();
        vaultToken.mint(receiver, amount);
    }
}
