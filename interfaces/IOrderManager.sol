// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../types/Structs.sol";

interface IOrderManager {
    event OrderPlaced(uint128 id, address customer, uint128 totalPrice);
    event OrderStatusUpdated(uint128 id, Structs.OrderStatus status);
    event OrderCancelled(uint128 id, address customer);
    event RefundProcessed(address customer, uint128 totalPrice);
    event OrderCompleted(uint128 orderId, address customer);

    function placeOrder(
        uint128 restaurantId,
        uint128[] memory itemIds,
        uint128[] memory quantities
    ) external payable;

    function cancelOrder(uint128 orderId) external;
    function completeOrder(uint128 orderId) external;
    function updateOrderStatus(uint128 orderId, Structs.OrderStatus status) external;
    function getMyOrders() external view returns (Structs.Order[] memory);
    function getOrderDetails(uint128 orderId)
        external
        view
        returns (
            Structs.Order memory order,
            Structs.MenuItem[] memory items,
            uint128[] memory quantities
        );
    function getAllOrders(uint128 start, uint128 limit)
        external
        view
        returns (Structs.Order[] memory);
}