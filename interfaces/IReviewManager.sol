// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../structs/FoodTypes.sol";

interface IReviewManager {
    event RestaurantRated(uint128 indexed restaurantId, address indexed customer, uint8 rating, string comment);

    function rateRestaurant(uint128 restaurantId, uint8 rating, string memory comment) external;

    function getReviews(uint128 restaurantId) external view returns (Review[] memory);
}