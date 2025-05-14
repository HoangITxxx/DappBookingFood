// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../structs/FoodTypes.sol";

interface IOrderManager {
    event OrderPlaced(uint128 indexed orderId, address indexed customer, uint128 totalPrice, uint128 preparationTime);

    function placeOrder(uint128 restaurantId, uint128[] memory itemIds, uint128[] memory quantities) external payable;
    function cancelOrder(uint128 orderId) external;
    function completeOrder(uint128 orderId) external;
    function updateOrderStatus(uint128 orderId, OrderStatus status) external;

    function getOrder(uint128 orderId) external view returns (Order memory);
}