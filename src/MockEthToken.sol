// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockEthToken is ERC20 {
    
    constructor() ERC20("MockEthToken", "METH") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
