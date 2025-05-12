// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract RestaurantManager is Ownable {
    using Address for address payable;

    enum Role { Customer, Staff, Admin }

    uint128 private nextRestaurantId = 1;
    uint8 public serviceFeePercentage = 5;
    uint8 public constant MAX_SERVICE_FEE = 20;

    mapping(address => Role) public roles;
    mapping(address => uint128) public pendingWithdrawals;
    mapping(address => uint128[]) public ownerRestaurants;
    mapping(uint128 => address) public restaurantOwners;
    mapping(address => uint128) public staffRestaurant;

    event RestaurantRegistered(uint128 restaurantId, address owner);
    event StaffAssigned(address staff, uint128 restaurantId);
    event RoleAssigned(address user, Role role);
    event ServiceFeeUpdated(uint8 newPercentage);
    event PaymentReleased(address recipient, uint128 amount);

    modifier onlyAdmin() {
        require(roles[msg.sender] == Role.Admin, "Unauthorized: Admin only");
        _;
    }

    modifier onlyRestaurantOwner(uint128 restaurantId) {
        require(restaurantOwners[restaurantId] == msg.sender, "Not restaurant owner");
        _;
    }

    constructor() Ownable(msg.sender) {
        roles[msg.sender] = Role.Admin;
    }

    function registerRestaurant() external returns (uint128) {
        uint128 restaurantId = nextRestaurantId;
        restaurantOwners[restaurantId] = msg.sender;
        ownerRestaurants[msg.sender].push(restaurantId);
        emit RestaurantRegistered(restaurantId, msg.sender);
        nextRestaurantId++;
        return restaurantId;
    }

    function assignStaff(address staff, uint128 restaurantId) 
        external 
        onlyRestaurantOwner(restaurantId) 
    {
        require(staff != address(0), "Invalid address");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        roles[staff] = Role.Staff;
        staffRestaurant[staff] = restaurantId;
        emit StaffAssigned(staff, restaurantId);
    }

    function assignRole(address user, Role role) external onlyAdmin {
        require(user != address(0), "Invalid address");
        roles[user] = role;
        if (role != Role.Staff) {
            delete staffRestaurant[user];
        }
        emit RoleAssigned(user, role);
    }

    function setServiceFeePercentage(uint8 percentage) external onlyAdmin {
        require(percentage <= MAX_SERVICE_FEE, "Service fee too high");
        serviceFeePercentage = percentage;
        emit ServiceFeeUpdated(percentage);
    }

    function withdrawServiceFees() external onlyAdmin {
        uint128 balance = pendingWithdrawals[owner()];
        require(balance > 0, "No funds available");
        pendingWithdrawals[owner()] = 0;
        payable(owner()).sendValue(balance);
        emit PaymentReleased(owner(), balance);
    }
    function addPendingWithdrawal(address recipient, uint128 amount) external {
        require(msg.sender == owner() || roles[msg.sender] == Role.Admin, "Unauthorized");
        pendingWithdrawals[recipient] += amount;
    }
}