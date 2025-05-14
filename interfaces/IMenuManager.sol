// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../structs/FoodTypes.sol";

interface IMenuManager {
    event MenuItemAdded(uint128 indexed menuId, uint128 indexed restaurantId, string name);

    function addMenuItem(
        uint128 restaurantId,
        string memory name,
        uint128 price,
        string memory description,
        string memory category,
        uint128 preparationTime
    ) external;

    function updateMenuItem(
        uint128 restaurantId,
        uint128 menuId,
        string memory name,
        uint128 price,
        bool available,
        string memory description,
        string memory category
    ) external;

    function removeMenuItem(uint128 restaurantId, uint128 menuId) external;

    function getMenuItem(uint128 restaurantId, uint128 menuId) external view returns (MenuItem memory);
}