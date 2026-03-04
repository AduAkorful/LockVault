// SPDX-License-Identifier:MIT

pragma solidity 0.8.33;

import {IMockOracleFeed} from "./interfaces/IMockOracleFeed.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract MockOracleFeed is IMockOracleFeed, Ownable2Step {
    // Variable for current token price
    // Variable is int because some price feeds may be negative
    int256 private _price;

    // Timestamp current price was updated
    uint256 private _updatedAt;

    // Variable for rounds
    uint80 private _roundId;

    // Sets price to begin with and the timestamp for that
    // Sets the owner address for the onlyOwner modifier
    constructor(int256 initialPrice, uint256 initialUpdatedAt) Ownable(msg.sender) {
        _price = initialPrice;
        _updatedAt = initialUpdatedAt;
        _roundId = 1;
    }

    // Updates the mock price and the timestamp
    function setPrice(int256 price, uint256 updatedAt) external onlyOwner {
        if (price <= 0) revert InvalidPrice();
        ++_roundId;
        _price = price;
        _updatedAt = updatedAt;
        emit PriceUpdated(price, updatedAt);
    }

    // Returns the number of decimals used by this price feed
    function decimals() external pure returns (uint8) {
        return 8;
    }

    // Returns a description of the price feed
    function description() external pure returns (string memory) {
        return "Mock /USD";
    }

    // Returns the version number of the aggregator interface
    function version() external pure returns (uint256) {
        return 4;
    }

    // Returns all data for the most recent price update
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }
}
