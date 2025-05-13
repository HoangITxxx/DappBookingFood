// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../types/Structs.sol";

interface IRestaurantManager {
    event RestaurantRegistered(uint128 restaurantId, address owner);
    event StaffAssigned(address staff, uint128 restaurantId);
    event RoleAssigned(address user, Structs.Role role);
    event ServiceFeeUpdated(uint8 newPercentage);
    event PaymentReleased(address recipient, uint128 amount);

    function registerRestaurant() external returns (uint128);
    function assignStaff(address staff, uint128 restaurantId) external;
    function setServiceFeePercentage(uint8 percentage) external;
}