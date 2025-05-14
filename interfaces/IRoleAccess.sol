// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../structs/FoodTypes.sol"; // Đường dẫn đến FoodTypes.sol

interface IRoleAccess {
    event RoleGranted(address indexed user, Role indexed role, address indexed granter);
    event RoleRevoked(address indexed user, Role indexed role, address indexed revoker);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin); // Nếu có vai trò Admin đặc biệt trong RoleAccess

    // --- Functions to be called by Owner of RoleAccess or designated Admins ---
    function grantRole(address userAddress, Role roleToGrant) external;
    function revokeRole(address userAddress, Role roleToRevoke) external;
    // function addAdmin(address newAdminAddress) external; // Nếu có nhiều Admin cho RoleAccess
    // function removeAdmin(address adminAddressToRemove) external; // Nếu có nhiều Admin cho RoleAccess
    // function renounceAdminRole() external; // Admin của RoleAccess từ bỏ vai trò

    // --- View Functions (Called by any contract/user to check roles) ---
    function getRole(address userAddress) external view returns (Role);
    function hasRole(address userAddress, Role roleToCheck) external view returns (bool);
    function isAdmin(address userAddress) external view returns (bool);
    function isStaff(address userAddress) external view returns (bool);
    function isCustomer(address userAddress) external view returns (bool);
    function isRestaurantOwner(address userAddress) external view returns (bool);
}