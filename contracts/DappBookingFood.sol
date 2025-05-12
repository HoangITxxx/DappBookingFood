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
        uint128 id;
        uint128 restaurantId;
        string name;
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

    uint128 private nextMenuId = 1;
    uint128 private nextOrderId = 1;
    uint128 private nextRestaurantId = 1; 
    uint8 public serviceFeePercentage = 5;
    uint8 public constant MAX_SERVICE_FEE = 20;

    mapping(address => Role) public roles;
    mapping(uint128 => mapping(uint128 => MenuItem)) public menuByRestaurant;
    mapping(uint128 => Order) public orders;
    mapping(address => uint128) public pendingWithdrawals;
    mapping(address => uint128[]) public customerOrders;
    mapping(address => uint128) public userPoints;
    mapping(uint128 => mapping(uint128 => uint128)) public orderDetails;
    // Added mappings for restaurant ownership and staff
    mapping(address => uint128[]) public ownerRestaurants;
    mapping(uint128 => address) public restaurantOwners; 
    mapping(address => uint128) public staffRestaurant; 

    // Events
    event MenuItemAdded(uint128 id, uint128 restaurantId, string name);
    event MenuItemUpdated(uint128 id, uint128 restaurantId);
    event MenuItemRemoved(uint128 id, uint128 restaurantId);
    event OrderPlaced(uint128 id, address customer, uint128 totalPrice);
    event OrderStatusUpdated(uint128 id, OrderStatus status);
    event OrderCancelled(uint128 id, address customer);
    event RefundProcessed(address customer, uint128 totalPrice);
    event PaymentReleased(address recipient, uint128 amount);
    event RoleAssigned(address user, Role role);
    event ServiceFeeUpdated(uint8 newPercentage);
    event MenuItemRated(uint128 menuId, uint8 rating);
    event OrderCompleted(uint128 orderId, address customer);
    event RestaurantRegistered(uint128 restaurantId, address owner);
    event StaffAssigned(address staff, uint128 restaurantId); 

    modifier onlyAdmin() {
        require(roles[msg.sender] == Role.Admin, "Unauthorized: Admin only");
        _;
    }

    modifier onlyStaffOrAdminOrOwner(uint128 restaurantId) {
        require(
            roles[msg.sender] == Role.Staff && staffRestaurant[msg.sender] == restaurantId ||
            roles[msg.sender] == Role.Admin ||
            restaurantOwners[restaurantId] == msg.sender,
            "Unauthorized: Staff, Admin, or Owner only"
        );
        _;
    }

    modifier onlyAdminOrCustomer() {
        require(
            roles[msg.sender] == Role.Admin || roles[msg.sender] == Role.Customer,
            "Only admin or customer"
        );
        _;
    }

    modifier onlyCustomer() {
        require(roles[msg.sender] == Role.Customer, "Unauthorized: Customer only");
        _;
    }

    modifier validOrderId(uint128 orderId) {
        require(orderId > 0 && orderId < nextOrderId, "Invalid order ID");
        _;
    }

    modifier validMenuItemId(uint128 restaurantId, uint128 menuId) {
        require(menuId > 0 && menuId < nextMenuId, "Invalid menu item ID");
        require(menuByRestaurant[restaurantId][menuId].id != 0, "Menu item does not exist");
        _;
    }

    modifier onlyRestaurantOwner(uint128 restaurantId) {
        require(restaurantOwners[restaurantId] == msg.sender, "Not restaurant owner");
        _;
    }

    constructor() Ownable(msg.sender) {
        roles[msg.sender] = Role.Admin;
    }

    // ================== Restaurant management ==================

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

    // ================== Admin functions ==================

    function assignRole(address user, Role role) external onlyAdmin {
        require(user != address(0), "Invalid address");
        roles[user] = role;
        // Clear staffRestaurant if role is not Staff
        if (role != Role.Staff) {
            delete staffRestaurant[user];
        }
        emit RoleAssigned(user, role);
    }

    function removeMenuItem(uint128 restaurantId, uint128 menuId) 
        external 
        onlyStaffOrAdminOrOwner(restaurantId) 
        validMenuItemId(restaurantId, menuId) 
    {
        delete menuByRestaurant[restaurantId][menuId];
        emit MenuItemRemoved(menuId, restaurantId);
    }

    function setServiceFeePercentage(uint8 percentage) external onlyAdmin {
        require(percentage <= MAX_SERVICE_FEE, "Service fee too high");
        serviceFeePercentage = percentage;
        emit ServiceFeeUpdated(percentage);
    }

    function withdrawServiceFees() external onlyAdmin nonReentrant {
        uint128 balance = pendingWithdrawals[owner()];
        require(balance > 0, "No funds available");
        
        pendingWithdrawals[owner()] = 0;
        payable(owner()).sendValue(balance);
        
        emit PaymentReleased(owner(), balance);
    }

    // ================== Customer functions ==================

    function placeOrder(
        uint128 restaurantId,
        uint128[] memory itemIds,
        uint128[] memory quantities
    ) external payable onlyAdminOrCustomer nonReentrant {
        require(itemIds.length > 0 && itemIds.length == quantities.length, "Invalid input");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        
        uint128 total = 0;
        for (uint i = 0; i < itemIds.length; i++) {
            MenuItem storage item = menuByRestaurant[restaurantId][itemIds[i]];
            require(item.available, "Item unavailable");
            require(item.restaurantId == restaurantId, "Item does not belong to restaurant");
            total += item.price * quantities[i];
            orderDetails[nextOrderId][itemIds[i]] = quantities[i];
        }

        uint128 serviceFee = (total * serviceFeePercentage) / 100;
        uint128 totalAmount = total + serviceFee;
        require(msg.value >= totalAmount, "Insufficient payment");

        if (msg.value > totalAmount) {
            payable(msg.sender).sendValue(msg.value - totalAmount);
        }

        orders[nextOrderId] = Order({
            id: nextOrderId,
            customer: msg.sender,
            restaurantId: restaurantId,
            itemIds: itemIds,
            quantities: quantities,
            totalPrice: total,
            status: OrderStatus.Placed,
            timestamp: uint128(block.timestamp)
        });

        customerOrders[msg.sender].push(nextOrderId);
        pendingWithdrawals[owner()] += serviceFee;

        emit OrderPlaced(nextOrderId, msg.sender, total);
        nextOrderId++;
    }

    function rateMenuItem(uint128 restaurantId, uint128 menuId, uint8 rating) 
        external 
        validMenuItemId(restaurantId, menuId) 
    {
        require(rating >= 1 && rating <= 5, "Invalid rating");
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        item.totalRating += rating;
        item.ratingCount += 1;
        emit MenuItemRated(menuId, rating);
    }

    function getAverageRating(uint128 restaurantId, uint128 menuId) 
        public 
        view 
        validMenuItemId(restaurantId, menuId) 
        returns (uint128) 
    {
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        if (item.ratingCount == 0) return 0;
        return item.totalRating / item.ratingCount;
    }

    // ================== Paginated View Functions ==================

    function getMenuItems(uint128 restaurantId, uint128 start, uint128 limit) 
        external 
        view 
        returns (MenuItem[] memory) 
    {
        uint128 count = 0;
        for (uint128 i = start + 1; i <= nextMenuId && i <= start + limit; i++) {
            if (menuByRestaurant[restaurantId][i].id != 0) count++;
        }

        MenuItem[] memory items = new MenuItem[](count);
        uint128 index = 0;
        for (uint128 i = start + 1; i <= nextMenuId && i <= start + limit; i++) {
            if (menuByRestaurant[restaurantId][i].id != 0) {
                items[index] = menuByRestaurant[restaurantId][i];
                index++;
            }
        }
        return items;
    }

    function getAllOrders(uint128 start, uint128 limit) 
        external 
        view 
        onlyAdmin 
        returns (Order[] memory) 
    {
        uint128 count = nextOrderId - 1 > start ? nextOrderId - 1 - start : 0;
        if (count > limit) count = limit;

        Order[] memory result = new Order[](count);
        for (uint128 i = 0; i < count; i++) {
            result[i] = orders[start + i + 1];
        }
        return result;
    }

    // ================== Other Functions ==================

    function addMenuItem(
        uint128 restaurantId,
        string memory name,
        uint128 price,
        string memory description,
        string memory category
    ) external onlyStaffOrAdminOrOwner(restaurantId) {
        require(bytes(name).length > 0 && price > 0, "Invalid data");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        menuByRestaurant[restaurantId][nextMenuId] = MenuItem({
            id: nextMenuId,
            restaurantId: restaurantId,
            name: name,
            price: price,
            available: true,
            description: description,
            category: category,
            totalRating: 0,
            ratingCount: 0
        });
        emit MenuItemAdded(nextMenuId, restaurantId, name);
        nextMenuId++;
    }

    function updateMenuItem(
        uint128 restaurantId,
        uint128 menuId, 
        string memory name, 
        uint128 price, 
        bool available,
        string memory description,
        string memory category
    ) external onlyStaffOrAdminOrOwner(restaurantId) validMenuItemId(restaurantId, menuId) {
        require(bytes(name).length > 0 && price > 0, "Invalid data");
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        item.name = name;
        item.price = price;
        item.available = available;
        item.description = description;
        item.category = category;
        emit MenuItemUpdated(menuId, restaurantId);
    }

    function cancelOrder(uint128 orderId) 
        external 
        onlyCustomer 
        nonReentrant 
        validOrderId(orderId) 
    {
        Order storage order = orders[orderId];
        require(order.customer == msg.sender, "Not your order");
        require(
            order.status == OrderStatus.Placed || 
            order.status == OrderStatus.Confirmed,
            "Cannot cancel at this stage"
        );
        
        order.status = OrderStatus.Cancelled;
        payable(msg.sender).sendValue(order.totalPrice);
        
        emit OrderCancelled(orderId, msg.sender);
        emit RefundProcessed(msg.sender, order.totalPrice);
    }

    function completeOrder(uint128 orderId) 
        external 
        onlyAdminOrCustomer 
        nonReentrant 
        validOrderId(orderId) 
    {
        Order storage order = orders[orderId];
        require(order.customer == msg.sender, "Not your order");
        require(order.status == OrderStatus.Ready, "Order not ready");
        
        order.status = OrderStatus.Completed;
        userPoints[msg.sender] += 10;
        emit OrderCompleted(orderId, msg.sender);
        emit OrderStatusUpdated(orderId, OrderStatus.Completed);
    }

    function updateOrderStatus(
        uint128 orderId, 
        OrderStatus status
    ) external onlyStaffOrAdminOrOwner(orders[orderId].restaurantId) nonReentrant validOrderId(orderId) {
        Order storage order = orders[orderId];
        require(order.status != OrderStatus.Cancelled, "Order is cancelled");
        require(order.status != OrderStatus.Completed, "Order already completed");
        
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
        
        order.status = status;
        emit OrderStatusUpdated(orderId, status);
    }

    function getMyOrders() external view returns (Order[] memory) {
        uint128[] storage ids = customerOrders[msg.sender];
        Order[] memory result = new Order[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            result[i] = orders[ids[i]];
        }
        return result;
    }

    function getOrderDetails(uint128 orderId) 
        external 
        view 
        validOrderId(orderId) 
        returns (
            Order memory order,
            MenuItem[] memory items,
            uint128[] memory quantities
        ) 
    {
        order = orders[orderId];
        items = new MenuItem[](order.itemIds.length);
        quantities = order.quantities;
        
        for (uint i = 0; i < order.itemIds.length; i++) {
            items[i] = menuByRestaurant[order.restaurantId][order.itemIds[i]];
        }
        
        return (order, items, quantities);
    }

    function previewTotalAmount(uint128 restaurantId, uint128[] memory itemIds, uint128[] memory quantities) 
        external 
        view 
        returns (uint128 totalAmount) 
    {
        require(itemIds.length == quantities.length, "Length mismatch");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        uint128 total = 0;

        for (uint i = 0; i < itemIds.length; i++) {
            MenuItem memory item = menuByRestaurant[restaurantId][itemIds[i]];
            require(item.available, "Item unavailable");
            require(item.restaurantId == restaurantId, "Item does not belong to restaurant");
            total += item.price * quantities[i];
        }

        uint128 serviceFee = (total * serviceFeePercentage) / 100;
        return total + serviceFee;
    }
}