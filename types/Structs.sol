// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Structs {
    enum Role { Customer, Staff, Admin }
    enum OrderStatus { Placed, Confirmed, Preparing, Ready, Cancelled, Completed }

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

    struct Order {
        uint128 id;
        address customer;
        uint128 restaurantId;
        uint128[] itemIds;
        uint128[] quantities;
        uint128 totalPrice;
        OrderStatus status;
        uint128 timestamp;
    }

    struct OrderDetail {
        uint128 menuId;
        uint128 quantity;
        uint128 price;
        string name;
    }

    struct RatingForEmployee {
        address customer;
        address employee;
        uint128 restaurantId;
        uint8 rating;
        string comment;
        uint128 timestamp;
    }

    struct RatingForRestaurant {
        address customer;
        uint128 restaurantId;
        uint8 rating;
        string comment;
        uint128 timestamp;
    }
}