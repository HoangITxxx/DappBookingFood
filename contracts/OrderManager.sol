// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../structs/FoodTypes.sol";
import "../access/RoleAccess.sol";
import "../interfaces/IOrderManager.sol";
import "./MenuManager.sol";

contract OrderManager is OwnableUpgradeable, RoleAccess, IOrderManager {
    uint128 public nextOrderId;
    mapping(uint128 => Order) public orders;
    mapping(address => uint128[]) public customerOrders;
    MenuManager public menuManager;

    function initialize(address admin, address _menuManager) public initializer {
        __Ownable_init(admin);
        initializeRoles(admin);
        menuManager = MenuManager(_menuManager);
        nextOrderId = 1;
    }

    function placeOrder(
        uint128 restaurantId,
        uint128[] memory itemIds,
        uint128[] memory quantities
    ) external payable override onlyCustomer {
        require(itemIds.length == quantities.length && itemIds.length > 0, "Invalid order data");

        uint128 totalPrice = 0;
        uint128 totalPreparationTime = 0;
        for (uint128 i = 0; i < itemIds.length; i++) {
            MenuItem memory item = menuManager.getMenuItem(restaurantId, itemIds[i]);
            require(item.id != 0 && item.available, "Invalid or unavailable menu item");
            totalPrice += item.price * quantities[i];
            totalPreparationTime = totalPreparationTime > item.preparationTime ? totalPreparationTime : item.preparationTime;
        }
        require(msg.value >= totalPrice, "Insufficient payment");

        orders[nextOrderId] = Order({
            id: nextOrderId,
            customer: msg.sender,
            restaurantId: restaurantId,
            itemIds: itemIds,
            quantities: quantities,
            totalPrice: totalPrice,
            status: OrderStatus.Placed,
            timestamp: uint128(block.timestamp),
            preparationTime: totalPreparationTime
        });
        customerOrders[msg.sender].push(nextOrderId);
        emit OrderPlaced(nextOrderId, msg.sender, totalPrice, totalPreparationTime);
        nextOrderId++;
    }

    function cancelOrder(uint128 orderId) external override onlyCustomer {
        Order memory order = orders[orderId];
        require(order.customer == msg.sender, "Not your order");
        require(order.status == OrderStatus.Placed, "Cannot cancel");
        orders[orderId].status = OrderStatus.Cancelled;
    }

    function completeOrder(uint128 orderId) external override onlyStaff(orders[orderId].restaurantId) {
        Order memory order = orders[orderId];
        require(order.status == OrderStatus.Ready, "Order not ready");
        orders[orderId].status = OrderStatus.Completed;
    }

    function updateOrderStatus(uint128 orderId, OrderStatus status) external override onlyStaff(orders[orderId].restaurantId) {
        orders[orderId].status = status;
    }

    function getOrder(uint128 orderId) external view override returns (Order memory) {
        return orders[orderId];
    }
}