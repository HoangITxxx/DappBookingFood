// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../structs/FoodTypes.sol";
import "../access/RoleAccess.sol";
import "../interfaces/IReviewManager.sol";

contract ReviewManager is OwnableUpgradeable, RoleAccess, IReviewManager {
    mapping(uint128 => Review[]) public restaurantReviews;

    function initialize(address admin) public initializer {
        __Ownable_init(admin);
        initializeRoles(admin);
    }

    function rateRestaurant(uint128 restaurantId, uint8 rating, string memory comment) external override onlyCustomer {
        require(rating >= 1 && rating <= 5, "Invalid rating");
        restaurantReviews[restaurantId].push(Review({
            customer: msg.sender,
            restaurantId: restaurantId,
            rating: rating,
            comment: comment,
            timestamp: uint128(block.timestamp)
        }));
        emit RestaurantRated(restaurantId, msg.sender, rating, comment);
    }

    function getReviews(uint128 restaurantId) external view override returns (Review[] memory) {
        return restaurantReviews[restaurantId];
    }
}