// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum Role { Admin, Staff, Customer }
enum OrderStatus { Placed, Confirmed, Preparing, Ready, Cancelled, Completed }

struct MenuItem {
    uint128 id;
    uint128 restaurantId;
    string name;
    uint128 price;
    bool available;
    string description;
    string category;
    uint128 totalRating;
    uint128 ratingCount;
    uint128 preparationTime;
}

struct Order {
    uint128 id;
    address customer;
    uint128 restaurantId;
    uint128[] itemIds;
    uint128[] quantities;
    uint128 totalPrice;
    OrderStatus status;
    uint128 timestamp;
    uint128 preparationTime;
}

struct Review {
    address customer;
    uint128 restaurantId;
    uint8 rating;
    string comment;
    uint128 timestamp;
}