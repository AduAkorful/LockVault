// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {MockOracleFeed} from "../src/MockOracleFeed.sol";

contract MockOracleFeedFuzzTest is Test {
    MockOracleFeed internal feed;

    function setUp() public {
        feed = new MockOracleFeed(1e8);
    }

    function testFuzz_SetPriceAcceptsPositiveValues(int256 price) public {
        vm.assume(price > 0);

        feed.setPrice(price);
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();

        assertEq(answer, price);
        assertEq(updatedAt, block.timestamp);
    }
}
