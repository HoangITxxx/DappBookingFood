// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../structs/FoodTypes.sol";

contract RoleAccess {
    mapping(address => Role) public roles;
    mapping(address => uint128) public staffRestaurants;

    modifier onlyAdmin() {
        require(roles[msg.sender] == Role.Admin, "Only admin");
        _;
    }

    modifier onlyStaff(uint128 restaurantId) {
        require(staffRestaurants[msg.sender] == restaurantId, "Only staff of this restaurant");
        _;
    }

    modifier onlyCustomer() {
        require(roles[msg.sender] == Role.Customer || roles[msg.sender] == Role.Staff, "Only customer");
        _;
    }

    function initializeRoles(address admin) internal {
        roles[admin] = Role.Admin;
    }

    function assignStaff(address staff, uint128 restaurantId) external onlyAdmin {
        roles[staff] = Role.Staff;
        staffRestaurants[staff] = restaurantId;
    }

    function removeStaff(address staff) external onlyAdmin {
        delete staffRestaurants[staff];
        roles[staff] = Role.Customer;
    }

    function addMeAsCustomer() external {
        roles[msg.sender] = Role.Customer;
    }

    function addMeAsAdmin() external {
        roles[msg.sender] = Role.Admin;
    }


}