// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./RestaurantManager.sol";
import "./MenuManager.sol";

contract OrderManager is ReentrancyGuard {
    using Address for address payable;

    RestaurantManager public restaurantManager;
    MenuManager public menuManager;

    enum OrderStatus { Placed, Confirmed, Preparing, Ready, Cancelled, Completed }

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

    uint128 private nextOrderId = 1;
    mapping(uint128 => Order) public orders;
    mapping(address => uint128[]) public customerOrders;
    mapping(address => uint128) public userPoints;
    mapping(uint128 => OrderDetail[]) public orderDetails;
    mapping(uint128 => mapping(uint128 => uint128)) public orderCountDetails;
    mapping(address => RatingForEmployee[]) public employeeRatings;
    mapping(uint128 => RatingForRestaurant[]) public restaurantRatings;

    event OrderPlaced(uint128 id, address customer, uint128 totalPrice);
    event OrderStatusUpdated(uint128 id, OrderStatus status);
    event OrderCancelled(uint128 id, address customer);
    event RefundProcessed(address customer, uint128 amount);
    event OrderCompleted(uint128 orderId, address customer);
    event EmployeeRated(address indexed employee, address indexed customer, uint128 restaurantId, uint8 rating, string comment);
    event RestaurantRated(uint128 indexed restaurantId, address indexed customer, uint8 rating, string comment);

    modifier onlyAdmin() {
        require(restaurantManager.roles(msg.sender) == RestaurantManager.Role.Admin, "Unauthorized: Admin only");
        _;
    }

    modifier onlyStaffOrAdminOrOwner(uint128 restaurantId) {
        require(
            restaurantManager.roles(msg.sender) == RestaurantManager.Role.Staff &&
            restaurantManager.staffRestaurant(msg.sender) == restaurantId ||
            restaurantManager.roles(msg.sender) == RestaurantManager.Role.Admin ||
            restaurantManager.restaurantOwners(restaurantId) == msg.sender,
            "Unauthorized: Staff, Admin, or Owner only"
        );
        _;
    }

    modifier onlyAdminOrCustomer() {
        require(
            restaurantManager.roles(msg.sender) == RestaurantManager.Role.Admin ||
            restaurantManager.roles(msg.sender) == RestaurantManager.Role.Customer,
            "Only admin or customer"
        );
        _;
    }

    modifier onlyCustomer() {
        require(restaurantManager.roles(msg.sender) == RestaurantManager.Role.Customer, "Unauthorized: Customer only");
        _;
    }

    modifier onlyStaffOrCustomer() {
        require(
            restaurantManager.roles(msg.sender) == RestaurantManager.Role.Customer ||
            restaurantManager.roles(msg.sender) == RestaurantManager.Role.Staff,
            "Unauthorized: Staff or Customer only"
        );
        _;
    }

    modifier validOrderId(uint128 orderId) {
        require(orderId > 0 && orderId < nextOrderId, "Invalid order ID");
        _;
    }

    constructor(address _restaurantManager, address _menuManager) {
        restaurantManager = RestaurantManager(_restaurantManager);
        menuManager = MenuManager(_menuManager);
    }

    function placeOrder(
        uint128 restaurantId,
        uint128[] memory itemIds,
        uint128[] memory quantities
    ) external payable onlyAdminOrCustomer nonReentrant {
        require(itemIds.length > 0 && itemIds.length == quantities.length, "Invalid input");
        require(restaurantManager.restaurantOwners(restaurantId) != address(0), "Restaurant does not exist");
        
        uint128 total = 0;
        OrderDetail[] memory details = new OrderDetail[](itemIds.length);
        for (uint i = 0; i < itemIds.length; i++) {
            MenuManager.MenuItem memory item = menuManager.getMenuItem(restaurantId, itemIds[i]);
            require(item.available, "Item unavailable");
            require(item.restaurantId == restaurantId, "Item does not belong to restaurant");
            total += item.price * quantities[i];
            orderCountDetails[nextOrderId][itemIds[i]] = quantities[i];
            details[i] = OrderDetail({
                menuId: itemIds[i],
                quantity: quantities[i],
                price: item.price,
                name: item.name
            });
        }

        uint128 serviceFee = (total * restaurantManager.serviceFeePercentage()) / 100;
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

        for (uint i = 0; i < details.length; i++) {
            orderDetails[nextOrderId].push(details[i]);
        }

        customerOrders[msg.sender].push(nextOrderId);
        restaurantManager.addPendingWithdrawal(restaurantManager.owner(), serviceFee);

        emit OrderPlaced(nextOrderId, msg.sender, total);
        nextOrderId++;
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

    function rateEmployee(address employee, uint128 restaurantId, uint8 rating, string memory comment) 
        external 
        onlyStaffOrCustomer 
    {
        require(rating >= 1 && rating <= 5, "Rating must be between 1 and 5");
        require(restaurantManager.restaurantOwners(restaurantId) != address(0), "Restaurant does not exist");
        require(
            restaurantManager.roles(employee) == RestaurantManager.Role.Staff &&
            restaurantManager.staffRestaurant(employee) == restaurantId,
            "Invalid employee"
        );
        
        RatingForEmployee memory newRating = RatingForEmployee({
            customer: msg.sender,
            employee: employee,
            restaurantId: restaurantId,
            rating: rating,
            comment: comment,
            timestamp: uint128(block.timestamp)
        });
        
        employeeRatings[employee].push(newRating);
        emit EmployeeRated(employee, msg.sender, restaurantId, rating, comment);
    }

    function rateRestaurant(uint128 restaurantId, uint8 rating, string memory comment) 
        external 
        onlyAdminOrCustomer 
    {
        require(rating >= 1 && rating <= 5, "Rating must be between 1 and 5");
        require(restaurantManager.restaurantOwners(restaurantId) != address(0), "Restaurant does not exist");
        
        RatingForRestaurant memory newRating = RatingForRestaurant({
            customer: msg.sender,
            restaurantId: restaurantId,
            rating: rating,
            comment: comment,
            timestamp: uint128(block.timestamp)
        });
        
        restaurantRatings[restaurantId].push(newRating);
        emit RestaurantRated(restaurantId, msg.sender, rating, comment);
    }

    function getOrderDetails(uint128 orderId) 
        external 
        view 
        validOrderId(orderId) 
        returns (
            Order memory order,
            MenuManager.MenuItem[] memory items,
            uint128[] memory quantities
        ) 
    {
        order = orders[orderId];
        OrderDetail[] memory details = orderDetails[orderId];
        
        items = new MenuManager.MenuItem[](details.length);
        quantities = new uint128[](details.length);
        
        for (uint i = 0; i < details.length; i++) {
            items[i] = menuManager.getMenuItem(order.restaurantId, details[i].menuId);
            quantities[i] = details[i].quantity;
        }
        
        return (order, items, quantities);
    }

    function getorderCountDetails(uint128 orderId) 
        external 
        view 
        validOrderId(orderId) 
        returns (
            Order memory order,
            uint128[] memory quantities
        ) 
    {
        order = orders[orderId];
        quantities = new uint128[](order.itemIds.length);
        for (uint i = 0; i < order.itemIds.length; i++) {
            quantities[i] = orderCountDetails[orderId][order.itemIds[i]];
        }
        
        return (order, quantities);
    }

    function getMyOrders() external onlyAdminOrCustomer view returns (Order[] memory) {
        uint128[] storage ids = customerOrders[msg.sender];
        Order[] memory result = new Order[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            result[i] = orders[ids[i]];
        }
        return result;
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

    function previewTotalAmount(uint128 restaurantId, uint128[] memory itemIds, uint128[] memory quantities) 
        external 
        view 
        returns (uint128 totalAmount) 
    {
        require(itemIds.length == quantities.length, "Length mismatch");
        require(restaurantManager.restaurantOwners(restaurantId) != address(0), "Restaurant does not exist");
        uint128 total = 0;

        for (uint i = 0; i < itemIds.length; i++) {
            MenuManager.MenuItem memory item = menuManager.getMenuItem(restaurantId, itemIds[i]);
            require(item.available, "Item unavailable");
            require(item.restaurantId == restaurantId, "Item does not belong to restaurant");
            total += item.price * quantities[i];
        }

        uint128 serviceFee = (total * restaurantManager.serviceFeePercentage()) / 100;
        return total + serviceFee;
    }

    function getEmployeeRatings(address employee) 
        external 
        view 
        returns (RatingForEmployee[] memory) 
    {
        return employeeRatings[employee];
    }

    function getRestaurantRatings(uint128 restaurantId) 
        external 
        view 
        returns (RatingForRestaurant[] memory) 
    {
        require(restaurantManager.restaurantOwners(restaurantId) != address(0), "Restaurant does not exist");
        return restaurantRatings[restaurantId];
    }
}