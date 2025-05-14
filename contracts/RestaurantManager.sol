// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../structs/FoodTypes.sol";
import "../access/RoleAccess.sol";
import "../interfaces/IRestaurantManager.sol";

contract RestaurantManager is OwnableUpgradeable, RoleAccess, IRestaurantManager {
    uint128 public nextRestaurantId;
    mapping(uint128 => address) public restaurantOwners;

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        initializeRoles(_owner);
        nextRestaurantId = 1;
    }

    function registerRestaurant() external onlyAdmin returns (uint128) {
        uint128 restaurantId = nextRestaurantId;
        restaurantOwners[restaurantId] = msg.sender;
        emit RestaurantRegistered(restaurantId, msg.sender);
        nextRestaurantId++;
        return restaurantId;
    }

    function getRestaurantOwner(uint128 restaurantId) external view override returns (address) {
        return restaurantOwners[restaurantId];
    }
}