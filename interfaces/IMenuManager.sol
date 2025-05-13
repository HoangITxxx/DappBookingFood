// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../types/Structs.sol";

interface IMenuManager {
    event MenuItemAdded(uint128 id, uint128 restaurantId, string name);
    event MenuItemUpdated(uint128 id, uint128 restaurantId);
    event MenuItemRemoved(uint128 id, uint128 restaurantId);
    event MenuItemRated(uint128 menuId, uint8 rating);

    function addMenuItem(
        uint128 restaurantId,
        string memory name,
        string memory imageUrl,
        string memory videoUrl,
        uint128 price,
        string memory description,
        string memory category
    ) external;

    function updateMenuItem(
        uint128 restaurantId,
        uint128 menuId,
        string memory name,
        string memory imageUrl,
        string memory videoUrl,
        uint128 price,
        bool available,
        string memory description,
        string memory category
    ) external;

    function removeMenuItem(uint128 restaurantId, uint128 menuId) external;
    function getMenuItems(uint128 restaurantId, uint128 start, uint128 limit)
        external
        view
        returns (Structs.MenuItem[] memory);
    function rateMenuItem(uint128 restaurantId, uint128 menuId, uint8 rating) external;
    function getAverageRating(uint128 restaurantId, uint128 menuId) external view returns (uint128);
}