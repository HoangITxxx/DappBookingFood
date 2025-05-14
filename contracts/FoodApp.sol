// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../structs/FoodTypes.sol";
import "../access/RoleAccess.sol";
import "../interfaces/IMenuManager.sol";
import "../interfaces/IOrderManager.sol";
import "../interfaces/IReviewManager.sol";
import "../interfaces/IRestaurantManager.sol";

contract FoodApp is OwnableUpgradeable, ReentrancyGuardUpgradeable, RoleAccess {
    address public menuManager;
    address public orderManager;
    address public reviewManager;
    address public restaurantManager;

    function initialize(address admin) public initializer {
        __Ownable_init(admin); 
        __ReentrancyGuard_init();
        initializeRoles(admin); 
    }

    // Setters cho các Manager
    function setMenuManager(address _menuManager) external onlyAdmin {
        require(_menuManager != address(0), "Invalid address");
        menuManager = _menuManager;
    }

    function setOrderManager(address _orderManager) external onlyAdmin {
        require(_orderManager != address(0), "Invalid address");
        orderManager = _orderManager;
    }

    function setReviewManager(address _reviewManager) external onlyAdmin {
        require(_reviewManager != address(0), "Invalid address");
        reviewManager = _reviewManager;
    }
    function setRestaurantManager(address _restaurantManager) external onlyAdmin {
        require(_restaurantManager != address(0), "Invalid address");
        restaurantManager = _restaurantManager;
    }

    // Menu functions (chuyển tiếp đến MenuManager)
    function addMenuItem(
        uint128 restaurantId,
        string memory name,
        uint128 price,
        string memory description,
        string memory category,
        uint128 preparationTime
    ) external onlyAdmin {
        require(menuManager != address(0), "MenuManager not set");
        IMenuManager(menuManager).addMenuItem(restaurantId, name, price, description, category, preparationTime);
    }

    function updateMenuItem(
        uint128 restaurantId,
        uint128 menuId,
        string memory name,
        uint128 price,
        bool available,
        string memory description,
        string memory category
    ) external onlyAdmin {
        require(menuManager != address(0), "MenuManager not set");
        IMenuManager(menuManager).updateMenuItem(restaurantId, menuId, name, price, available, description, category);
    }

    function removeMenuItem(uint128 restaurantId, uint128 menuId) external onlyAdmin {
        require(menuManager != address(0), "MenuManager not set");
        IMenuManager(menuManager).removeMenuItem(restaurantId, menuId);
    }

    // Order functions (chuyển tiếp đến OrderManager)
    function placeOrder(
        uint128 restaurantId,
        uint128[] memory itemIds,
        uint128[] memory quantities
    ) external payable onlyCustomer {
        require(orderManager != address(0), "OrderManager not set");
        IOrderManager(orderManager).placeOrder{value: msg.value}(restaurantId, itemIds, quantities);
    }

    function cancelOrder(uint128 orderId) external onlyCustomer {
        require(orderManager != address(0), "OrderManager not set");
        IOrderManager(orderManager).cancelOrder(orderId);
    }

    function completeOrder(uint128 orderId) external {
        require(orderManager != address(0), "OrderManager not set");
        IOrderManager(orderManager).completeOrder(orderId);
    }

    function updateOrderStatus(uint128 orderId, OrderStatus status) external {
        require(orderManager != address(0), "OrderManager not set");
        IOrderManager(orderManager).updateOrderStatus(orderId, status);
    }

    // Review functions (chuyển tiếp đến ReviewManager)
    function rateRestaurant(uint128 restaurantId, uint8 rating, string memory comment) external onlyCustomer {
        require(reviewManager != address(0), "ReviewManager not set");
        IReviewManager(reviewManager).rateRestaurant(restaurantId, rating, comment);
    }
    function registerRestaurant() external onlyAdmin returns (uint128) {
        require(restaurantManager != address(0), "RestaurantManager not set");
        return IRestaurantManager(restaurantManager).registerRestaurant();
    }
}