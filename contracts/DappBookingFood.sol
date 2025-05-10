// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract SMCFoodDapp is ReentrancyGuard, Ownable {
    using Address for address payable;
    
    enum Role { Customer, Staff, Admin }
    enum OrderStatus { Placed, Confirmed, Preparing, Ready, Cancelled, Completed }

    struct MenuItem {
        uint id;
        string name;
        uint price; 
        bool available;
        string description;
    }

    struct Order {
        uint id;
        address customer;
        uint[] itemIds;
        uint[] quantities;
        uint totalPrice;
        OrderStatus status;
        uint timestamp;
        // address staffAssigned;
    }

    uint private nextMenuId = 1;
    uint private nextOrderId = 1;
    uint public serviceFeePercentage = 5;
    uint public constant MAX_SERVICE_FEE = 20; 

    mapping(address => Role) public roles;
    mapping(uint => MenuItem) public menu;
    mapping(uint => Order) public orders;
    mapping(address => uint) public pendingWithdrawals;
    mapping(address => uint[]) public customerOrders;
    // mapping(address => uint[]) public staffAssignedOrders;

    // Events
    event MenuItemAdded(uint id, string name);
    event MenuItemUpdated(uint id);
    event MenuItemRemoved(uint id);
    event OrderPlaced(uint id, address customer, uint totalPrice);
    event OrderStatusUpdated(uint id, OrderStatus status);
    event OrderCancelled(uint id, address customer);
    event RefundProcessed(address customer, uint totalPrice);
    event PaymentReleased(address recipient, uint amount);
    event RoleAssigned(address user, Role role);
    event ServiceFeeUpdated(uint newPercentage);

    modifier onlyAdmin() {
        require(roles[msg.sender] == Role.Admin, "Unauthorized: Admin only");
        _;
    }

    modifier onlyStaffOrAdmin() {
        require(
            roles[msg.sender] == Role.Staff || 
            roles[msg.sender] == Role.Admin, 
            "Unauthorized: Staff or Admin only"
        );
        _;
    }

    modifier onlyCustomer() {
        require(roles[msg.sender] == Role.Customer, "Unauthorized: Customer only");
        _;
    }

    modifier validOrderId(uint orderId) {
        require(orderId > 0 && orderId < nextOrderId, "Invalid order ID");
        _;
    }

    modifier validMenuItemId(uint menuId) {
        require(menuId > 0 && menuId < nextMenuId, "Invalid menu item ID");
        _;
    }

    constructor() Ownable(msg.sender) {
        roles[msg.sender] = Role.Admin;
    }

    // ================== Admin functions ==================

    function assignRole(address user, Role role) external onlyAdmin {
        require(user != address(0), "Invalid address");
        require(role != Role.Customer || user == msg.sender, "Cannot assign customer role");
        
        roles[user] = role;
        emit RoleAssigned(user, role);
    }

    function addMenuItem(
        string memory name, 
        uint price, 
        string memory description
    ) external onlyAdmin {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(price > 0, "Price must be greater than 0");
        
        menu[nextMenuId] = MenuItem(nextMenuId, name, price, true, description);
        emit MenuItemAdded(nextMenuId, name);
        nextMenuId++;
    }

    function updateMenuItem(
        uint menuId, 
        string memory name, 
        uint price, 
        bool available,
        string memory description
    ) external onlyAdmin validMenuItemId(menuId) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(price > 0, "Price must be greater than 0");
        
        menu[menuId] = MenuItem(menuId, name, price, available, description);
        emit MenuItemUpdated(menuId);
    }

    function removeMenuItem(uint menuId) external onlyAdmin validMenuItemId(menuId) {
        require(menu[menuId].id != 0, "Item already removed");
        delete menu[menuId];
        emit MenuItemRemoved(menuId);
    }

    function setServiceFeePercentage(uint percentage) external onlyAdmin {
        require(percentage <= MAX_SERVICE_FEE, "Service fee too high");
        serviceFeePercentage = percentage;
        emit ServiceFeeUpdated(percentage);
    }

    function withdrawServiceFees() external onlyAdmin nonReentrant {
        uint balance = pendingWithdrawals[owner()];
        require(balance > 0, "No funds available");
        
        pendingWithdrawals[owner()] = 0;
        payable(owner()).sendValue(balance);
        
        emit PaymentReleased(owner(), balance);
    }

    // ================== Customer functions ==================

    function placeOrder(
        uint[] memory itemIds, 
        uint[] memory quantities
    ) external payable onlyCustomer nonReentrant {
        require(itemIds.length > 0, "Must select at least one item");
        require(itemIds.length == quantities.length, "Invalid items/quantities length");
        require(itemIds.length <= 10, "Too many items in one order"); 
        
        uint256 total = 0;
        
        for (uint i = 0; i < itemIds.length; i++) {
            require(itemIds[i] > 0 && itemIds[i] < nextMenuId, "Invalid menu item ID");
            require(quantities[i] > 0 && quantities[i] <= 100, "Invalid quantity");
            
            MenuItem storage item = menu[itemIds[i]];
            require(item.id != 0, "Menu item does not exist");
            require(item.available, "Menu item not available");
            
            total += item.price * quantities[i];
        }
        
        uint serviceFee = (total * serviceFeePercentage) / 100;
        uint totalAmount = total + serviceFee;
        
        require(msg.value >= totalAmount, "Insufficient payment");
        
        unchecked {
            if (msg.value > totalAmount) {
                payable(msg.sender).sendValue(msg.value - totalAmount);
            }
        }
        
        orders[nextOrderId] = Order({
            id: nextOrderId,
            customer: msg.sender,
            itemIds: itemIds,
            quantities: quantities,
            totalPrice: total,
            status: OrderStatus.Placed,
            timestamp: block.timestamp
            // staffAssigned: address(0)
        });
        
        customerOrders[msg.sender].push(nextOrderId);
        pendingWithdrawals[owner()] += serviceFee;
        
        emit OrderPlaced(nextOrderId, msg.sender, total);
        nextOrderId++;
    }

    function cancelOrder(uint orderId) external onlyCustomer nonReentrant validOrderId(orderId) {
        Order storage order = orders[orderId];
        
        require(order.customer == msg.sender, "Not your order");
        require(
            order.status == OrderStatus.Placed || 
            order.status == OrderStatus.Confirmed,
            "Cannot cancel at this stage"
        );
        
        order.status = OrderStatus.Cancelled;
        
        uint refundAmount = order.totalPrice;
        require(refundAmount <= address(this).balance, "Insufficient contract balance");
        
        payable(msg.sender).sendValue(refundAmount);
        
        emit OrderCancelled(orderId, msg.sender);
        emit RefundProcessed(msg.sender, refundAmount);
    }

    function completeOrder(uint orderId) external onlyCustomer nonReentrant validOrderId(orderId) {
        Order storage order = orders[orderId];
        
        require(order.customer == msg.sender, "Not your order");
        require(order.status == OrderStatus.Ready, "Order not ready for completion");
        
        order.status = OrderStatus.Completed;
        emit OrderStatusUpdated(orderId, OrderStatus.Completed);
    }

    // ================== Staff functions ==================

    function updateOrderStatus(
        uint orderId, 
        OrderStatus status
    ) external onlyStaffOrAdmin nonReentrant validOrderId(orderId) {
        Order storage order = orders[orderId];
        
        require(order.status != OrderStatus.Cancelled, "Order is cancelled");
        require(order.status != OrderStatus.Completed, "Order already completed");
        
        // State transition validation
        if (status == OrderStatus.Confirmed) {
            require(order.status == OrderStatus.Placed, "Invalid status transition");
        } else if (status == OrderStatus.Preparing) {
            require(
                order.status == OrderStatus.Placed || 
                order.status == OrderStatus.Confirmed,
                "Invalid status transition"
            );
        } else if (status == OrderStatus.Ready) {
            require(
                order.status == OrderStatus.Preparing ||
                order.status == OrderStatus.Confirmed,
                "Invalid status transition"
            );
        } else {
            revert("Invalid status update");
        }
        
        // if (order.staffAssigned == address(0)) {
        //     order.staffAssigned = msg.sender;
        //     staffAssignedOrders[msg.sender].push(orderId);
        // }
        
        order.status = status;
        emit OrderStatusUpdated(orderId, status);
    }

    // ================== View functions ==================

    function getMyOrders() external view returns (Order[] memory) {
        uint[] storage ids = customerOrders[msg.sender];
        Order[] memory result = new Order[](ids.length);
        
        for (uint i = 0; i < ids.length; i++) {
            result[i] = orders[ids[i]];
        }
        return result;
    }

    // function getAssignedOrders() external view onlyStaffOrAdmin returns (Order[] memory) {
    //     uint[] storage ids = staffAssignedOrders[msg.sender];
    //     Order[] memory result = new Order[](ids.length);
        
    //     for (uint i = 0; i < ids.length; i++) {
    //         result[i] = orders[ids[i]];
    //     }
    //     return result;
    // }

    function getMenuItems() external view returns (MenuItem[] memory) {
        uint count = 0;
        
        for (uint i = 1; i < nextMenuId; i++) {
            if (menu[i].id != 0) count++;
        }
        MenuItem[] memory items = new MenuItem[](count);
        uint index = 0;
        
        for (uint i = 1; i < nextMenuId; i++) {
            if (menu[i].id != 0) {
                items[index] = menu[i];
                index++;
            }
        }
        return items;
    }

    function getOrderDetails(uint orderId) external view validOrderId(orderId) returns (
        Order memory order,
        MenuItem[] memory items,
        uint[] memory quantities
    ) {
        order = orders[orderId];
        items = new MenuItem[](order.itemIds.length);
        quantities = order.quantities;
        
        for (uint i = 0; i < order.itemIds.length; i++) {
            items[i] = menu[order.itemIds[i]];
        }
        
        return (order, items, quantities);
    }
}