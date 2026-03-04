// SPDX-License-Identifier:MIT

pragma solidity 0.8.33;

interface IMockOracleFeed {
    event PriceUpdated(int256 price, uint256 updatedAt);

    error InvalidPrice();

    // Updates the mock price and the timestamp
    function setPrice(int256 price, uint256 updatedAt) external;

    // Returns the number of decimals used by this price feed
    function decimals() external pure returns (uint8);

    // Returns a description of the price feed
    function description() external pure returns (string memory);

    // Returns the version number of the aggregator interface
    function version() external pure returns (uint256);

    // Returns all data for the most recent price update
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
