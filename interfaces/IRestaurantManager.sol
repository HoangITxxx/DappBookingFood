// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRestaurantManager {
    event RestaurantRegistered(uint128 indexed restaurantId, address indexed owner);

    function registerRestaurant() external returns (uint128);
    function getRestaurantOwner(uint128 restaurantId) external view returns (address);
}