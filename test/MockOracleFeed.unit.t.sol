// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {MockOracleFeed} from "../src/MockOracleFeed.sol";
import {IMockOracleFeed} from "../src/interfaces/IMockOracleFeed.sol";

contract MockOracleFeedUnitTest is Test {
    MockOracleFeed internal feed;

    address internal nonOwner = address(0xCA11);

    function setUp() public {
        feed = new MockOracleFeed(2_000e8);
    }

    function test_Constructor_SetsInitialRoundData() public view {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();
        assertEq(roundId, 1);
        assertEq(answer, 2_000e8);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 1);
    }

    function test_SetPrice_RevertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        feed.setPrice(1_999e8);
    }

    function test_SetPrice_RevertsForInvalidPrice() public {
        vm.expectRevert(IMockOracleFeed.InvalidPrice.selector);
        feed.setPrice(0);
    }

    function test_SetPrice_UpdatesDataAndRound() public {
        vm.warp(block.timestamp + 100);
        feed.setPrice(3_000e8);

        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();
        assertEq(roundId, 2);
        assertEq(answer, 3_000e8);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 2);
    }

    function test_MetadataFunctions() public view {
        assertEq(feed.decimals(), 8);
        assertEq(feed.description(), "Mock /USD");
        assertEq(feed.version(), 4);
    }
}