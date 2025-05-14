// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../structs/FoodTypes.sol";
import "../access/RoleAccess.sol";
import "../interfaces/IMenuManager.sol";

contract MenuManager is OwnableUpgradeable, RoleAccess, IMenuManager {
    uint128 public nextMenuId;
    mapping(uint128 => mapping(uint128 => MenuItem)) public menuByRestaurant;

    function initialize(address admin) public initializer {
        __Ownable_init(admin);
        initializeRoles(admin);
        nextMenuId = 1;
    }

    function addMenuItem(
        uint128 restaurantId,
        string memory name,
        uint128 price,
        string memory description,
        string memory category,
        uint128 preparationTime
    ) external override onlyAdmin {
        require(restaurantId > 0, "Invalid restaurantId");
        require(preparationTime > 0, "Invalid preparation time");
        menuByRestaurant[restaurantId][nextMenuId] = MenuItem({
            id: nextMenuId,
            restaurantId: restaurantId,
            name: name,
            price: price,
            available: true,
            description: description,
            category: category,
            totalRating: 0,
            ratingCount: 0,
            preparationTime: preparationTime
        });
        emit MenuItemAdded(nextMenuId, restaurantId, name);
        nextMenuId++;
    }

    function updateMenuItem(
        uint128 restaurantId,
        uint128 menuId,
        string memory name,
        uint128 price,
        bool available,
        string memory description,
        string memory category
    ) external override onlyAdmin {
        require(menuByRestaurant[restaurantId][menuId].id != 0, "Menu item does not exist");
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        item.name = name;
        item.price = price;
        item.available = available;
        item.description = description;
        item.category = category;
    }

    function removeMenuItem(uint128 restaurantId, uint128 menuId) external override onlyAdmin {
        require(menuByRestaurant[restaurantId][menuId].id != 0, "Menu item does not exist");
        delete menuByRestaurant[restaurantId][menuId];
    }

    function getMenuItem(uint128 restaurantId, uint128 menuId) external view override returns (MenuItem memory) {
        return menuByRestaurant[restaurantId][menuId];
    }
}