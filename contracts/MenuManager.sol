// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./RestaurantManager.sol";

contract MenuManager {
    RestaurantManager public restaurantManager;

    struct MenuItem {
        uint128 id;
        uint128 restaurantId;
        string name;
        string imageUrl;
        string videoUrl;
        uint128 price;
        bool available;
        string description;
        string category;
        uint128 totalRating;
        uint128 ratingCount;
    }

    uint128 private nextMenuId = 1;
    mapping(uint128 => mapping(uint128 => MenuItem)) public menuByRestaurant;
    mapping(uint128 => uint128[]) public restaurantMenuIds;

    event MenuItemAdded(uint128 id, uint128 restaurantId, string name);
    event MenuItemUpdated(uint128 id, uint128 restaurantId);
    event MenuItemRemoved(uint128 id, uint128 restaurantId);
    event MenuItemRated(uint128 menuId, uint8 rating);

    modifier onlyStaffOrAdminOrOwner(uint128 restaurantId) {
        require(
            restaurantManager.roles(msg.sender) == RestaurantManager.Role.Staff &&
            restaurantManager.staffRestaurant(msg.sender) == restaurantId ||
            restaurantManager.roles(msg.sender) == RestaurantManager.Role.Admin ||
            restaurantManager.restaurantOwners(restaurantId) == msg.sender,
            "Unauthorized: Staff, Admin, or Owner only"
        );
        _;
    }

    modifier validMenuItemId(uint128 restaurantId, uint128 menuId) {
        require(menuId > 0 && menuId < nextMenuId, "Invalid menu item ID");
        require(menuByRestaurant[restaurantId][menuId].id != 0, "Menu item does not exist");
        _;
    }

    constructor(address _restaurantManager) {
        restaurantManager = RestaurantManager(_restaurantManager);
    }

    function addMenuItem(
        uint128 restaurantId,
        string memory name,
        string memory imageUrl,
        string memory videoUrl,
        uint128 price,
        string memory description,
        string memory category
    ) external onlyStaffOrAdminOrOwner(restaurantId) {
        require(bytes(name).length > 0 && price > 0, "Invalid data");
        require(restaurantManager.restaurantOwners(restaurantId) != address(0), "Restaurant does not exist");
        menuByRestaurant[restaurantId][nextMenuId] = MenuItem({
            id: nextMenuId,
            restaurantId: restaurantId,
            name: name,
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            price: price,
            available: true,
            description: description,
            category: category,
            totalRating: 0,
            ratingCount: 0
        });
        restaurantMenuIds[restaurantId].push(nextMenuId);
        emit MenuItemAdded(nextMenuId, restaurantId, name);
        nextMenuId++;
    }

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
    ) external onlyStaffOrAdminOrOwner(restaurantId) validMenuItemId(restaurantId, menuId) {
        require(bytes(name).length > 0 && price > 0, "Invalid data");
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        item.name = name;
        item.imageUrl = imageUrl;
        item.videoUrl = videoUrl;
        item.price = price;
        item.available = available;
        item.description = description;
        item.category = category;
        emit MenuItemUpdated(menuId, restaurantId);
    }

    function removeMenuItem(uint128 restaurantId, uint128 menuId) 
        external 
        onlyStaffOrAdminOrOwner(restaurantId) 
        validMenuItemId(restaurantId, menuId) 
    {
        delete menuByRestaurant[restaurantId][menuId];
        emit MenuItemRemoved(menuId, restaurantId);
    }

    function rateMenuItem(uint128 restaurantId, uint128 menuId, uint8 rating) 
        external 
        validMenuItemId(restaurantId, menuId) 
    {
        require(rating >= 1 && rating <= 5, "Invalid rating");
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        item.totalRating += rating;
        item.ratingCount += 1;
        emit MenuItemRated(menuId, rating);
    }

    function getMenuItem(uint128 restaurantId, uint128 menuId) 
        external 
        view 
        validMenuItemId(restaurantId, menuId) 
        returns (MenuItem memory) 
    {
        return menuByRestaurant[restaurantId][menuId];
    }

    function getAverageRating(uint128 restaurantId, uint128 menuId) 
        external 
        view 
        validMenuItemId(restaurantId, menuId) 
        returns (uint128) 
    {
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        if (item.ratingCount == 0) return 0;
        return item.totalRating / item.ratingCount;
    }

    // Note: getAllMenuByRestaurant is commented in original code, so not included here
    // Can be added if needed
}