// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../types/Structs.sol";

interface IRatingManager {
    event EmployeeRated(address indexed employee, address indexed customer, uint128 restaurantId, uint8 rating, string comment);
    event RestaurantRated(uint128 indexed restaurantId, address indexed customer, uint8 rating, string comment);

    function rateEmployee(address employee, uint128 restaurantId, uint8 rating, string memory comment) external;
    function rateRestaurant(uint128 restaurantId, uint8 rating, string memory comment) external;
    function getEmployeeRatings(address employee) external view returns (Structs.RatingForEmployee[] memory);
    function getRestaurantRatings(uint128 restaurantId) external view returns (Structs.RatingForRestaurant[] memory);
}