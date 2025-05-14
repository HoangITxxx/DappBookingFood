// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../structs/FoodTypes.sol";
import "./OrderManager.sol";
import "./ReviewManager.sol";

contract FoodAnalytics {
    OrderManager public orderManager;
    ReviewManager public reviewManager;

    constructor(address _orderManager, address _reviewManager) {
        orderManager = OrderManager(_orderManager);
        reviewManager = ReviewManager(_reviewManager);
    }

    function getRestaurantAverageRating(uint128 restaurantId) external view returns (uint128 averageRating) {
        Review[] memory reviews = reviewManager.getReviews(restaurantId);
        if (reviews.length == 0) return 0;

        uint128 totalRating = 0;
        for (uint128 i = 0; i < reviews.length; i++) {
            totalRating += reviews[i].rating;
        }
        return totalRating / uint128(reviews.length);
    }

    function getTotalOrdersByRestaurant(uint128 restaurantId) external view returns (uint128 totalOrders) {
        uint128 count = 0;
        for (uint128 i = 1; i < orderManager.nextOrderId(); i++) {
            Order memory order = orderManager.getOrder(i);
            if (order.restaurantId == restaurantId) count++;
        }
        return count;
    }
}