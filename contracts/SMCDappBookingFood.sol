// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../types/Structs.sol";
import "../types/Constants.sol";
import "../interfaces/IRestaurantManager.sol";
import "../interfaces/IOrderManager.sol";
import "../interfaces/IMenuManager.sol";
import "../interfaces/IRatingManager.sol";

contract SMCDappBookingFood is
    ReentrancyGuard,
    Ownable,
    Structs,
    IRestaurantManager,
    IOrderManager,
    IMenuManager,
    IRatingManager
{
    using Address for address payable;

    // State variables
    uint128 private nextRestaurantId = 1;
    uint8 public serviceFeePercentage = 5;
    uint128 public nextOrderId;
    uint128 public nextMenuId;

    mapping(address => Role) public roles;
    mapping(address => uint128) public staffRestaurant;
    mapping(uint128 => address) public restaurantOwners;
    mapping(uint128 => mapping(uint128 => MenuItem)) public menuByRestaurant;
    mapping(uint128 => Order) public orders;
    mapping(address => uint128) public pendingWithdrawals;
    mapping(address => uint128[]) public customerOrders;
    mapping(address => uint128) public userPoints;
    mapping(uint128 => OrderDetail[]) public orderDetails;
    mapping(uint128 => mapping(uint128 => uint128)) public orderCountDetails;
    mapping(address => uint128[]) public ownerRestaurants;
    mapping(uint128 => uint128[]) public restaurantMenuIds;
    mapping(address => RatingForEmployee[]) public employeeRatings;
    mapping(uint128 => RatingForRestaurant[]) public restaurantRatings;

    constructor() Ownable(msg.sender) {
        roles[msg.sender] = Role.Admin;
    }

    // Modifiers
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

    modifier onlyStaffOrCustomer() {
        require(
            roles[msg.sender] == Role.Customer || roles[msg.sender] == Role.Staff,
            "Unauthorized: Staff or Customer only"
        );
        _;
    }

    // RestaurantManager functions
    function registerRestaurant() external override returns (uint128) {
        uint128 restaurantId = nextRestaurantId;
        restaurantOwners[restaurantId] = msg.sender;
        ownerRestaurants[msg.sender].push(restaurantId);
        emit RestaurantRegistered(restaurantId, msg.sender);
        nextRestaurantId++;
        return restaurantId;
    }

    function assignStaff(address staff, uint128 restaurantId)
        external
        override
        onlyRestaurantOwner(restaurantId)
    {
        require(staff != address(0), "Invalid address");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        roles[staff] = Role.Staff;
        staffRestaurant[staff] = restaurantId;
        emit StaffAssigned(staff, restaurantId);
    }

    function setServiceFeePercentage(uint8 percentage) external override onlyAdmin {
        require(percentage <= Constants.MAX_SERVICE_FEE, "Service fee too high");
        serviceFeePercentage = percentage;
        emit ServiceFeeUpdated(percentage);
    }

    // MenuManager functions
    function addMenuItem(
        uint128 restaurantId,
        string memory name,
        string memory imageUrl,
        string memory videoUrl,
        uint128 price,
        string memory description,
        string memory category
    ) external override onlyStaffOrAdminOrOwner(restaurantId) {
        require(bytes(name).length > 0 && price > 0, "Invalid data");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        menuByRestaurant[restaurantId][nextMenuId] = MenuItem({
            id: nextMenuId,
            restaurantId: restaurantId,
            name: name,
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            price: price,
            available: true,
            description: description,
            category: category,
            totalRating: 0,
            ratingCount: 0
        });
        restaurantMenuIds[restaurantId].push(nextMenuId);
        emit MenuItemAdded(nextMenuId, restaurantId, name);
        nextMenuId++;
    }

    function updateMenuItem(
        uint128 restaurantId,
        uint128 menuId,
        string memory name,
        string memory imageUrl,
        string memory videoUrl,
        uint128 price,
        bool available,
        string memory description,
        string memory category
    ) external override onlyStaffOrAdminOrOwner(restaurantId) validMenuItemId(restaurantId, menuId) {
        require(bytes(name).length > 0 && price > 0, "Invalid data");
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        item.name = name;
        item.imageUrl = imageUrl;
        item.videoUrl = videoUrl;
        item.price = price;
        item.available = available;
        item.description = description;
        item.category = category;
        emit MenuItemUpdated(menuId, restaurantId);
    }

    function removeMenuItem(uint128 restaurantId, uint128 menuId)
        external
        override
        onlyStaffOrAdminOrOwner(restaurantId)
        validMenuItemId(restaurantId, menuId)
    {
        delete menuByRestaurant[restaurantId][menuId];
        emit MenuItemRemoved(menuId, restaurantId);
    }

    function getMenuItems(uint128 restaurantId, uint128 start, uint128 limit)
        external
        view
        override
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

    function rateMenuItem(uint128 restaurantId, uint128 menuId, uint8 rating)
        external
        override
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
        override
        validMenuItemId(restaurantId, menuId)
        returns (uint128)
    {
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        if (item.ratingCount == 0) return 0;
        return item.totalRating / item.ratingCount;
    }

    // OrderManager functions
    function placeOrder(
        uint128 restaurantId,
        uint128[] memory itemIds,
        uint128[] memory quantities
    ) external payable override onlyAdminOrCustomer nonReentrant {
        require(itemIds.length > 0 && itemIds.length == quantities.length, "Invalid input");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");

        uint128 total = 0;
        OrderDetail[] memory details = new OrderDetail[](itemIds.length);
        for (uint256 i = 0; i < itemIds.length; i++) {
            MenuItem storage item = menuByRestaurant[restaurantId][itemIds[i]];
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

        for (uint256 i = 0; i < details.length; i++) {
            orderDetails[nextOrderId].push(details[i]);
        }

        customerOrders[msg.sender].push(nextOrderId);
        pendingWithdrawals[owner()] += serviceFee;

        emit OrderPlaced(nextOrderId, msg.sender, total);
        nextOrderId++;
    }

    function cancelOrder(uint128 orderId)
        external
        override
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
        override
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

    function updateOrderStatus(uint128 orderId, OrderStatus status)
        external
        override
        onlyStaffOrAdminOrOwner(orders[orderId].restaurantId)
        nonReentrant
        validOrderId(orderId)
    {
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

    function getMyOrders() external view override onlyAdminOrCustomer returns (Order[] memory) {
        uint128[] storage ids = customerOrders[msg.sender];
        Order[] memory result = new Order[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = orders[ids[i]];
        }
        return result;
    }

    function getOrderDetails(uint128 orderId)
        external
        view
        override
        validOrderId(orderId)
        returns (
            Order memory order,
            MenuItem[] memory items,
            uint128[] memory quantities
        )
    {
        order = orders[orderId];
        OrderDetail[] memory details = orderDetails[orderId];

        items = new MenuItem[](details.length);
        quantities = new uint128[](details.length);

        for (uint256 i = 0; i < details.length; i++) {
            items[i] = menuByRestaurant[order.restaurantId][details[i].menuId];
            quantities[i] = details[i].quantity;
        }

        return (order, items, quantities);
    }

    function getAllOrders(uint128 start, uint128 limit)
        external
        view
        override
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

    // RatingManager functions
    function rateEmployee(
        address employee,
        uint128 restaurantId,
        uint8 rating,
        string memory comment
    ) external override onlyStaffOrCustomer {
        require(rating >= 1 && rating <= 5, "Rating must be between 1 and 5");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        require(roles[employee] == Role.Staff && staffRestaurant[employee] == restaurantId, "Invalid employee");

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
        override
        onlyAdminOrCustomer
    {
        require(rating >= 1 && rating <= 5, "Rating must be between 1 and 5");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");

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

    function getEmployeeRatings(address employee)
        external
        view
        override
        returns (RatingForEmployee[] memory)
    {
        return employeeRatings[employee];
    }

    function getRestaurantRatings(uint128 restaurantId)
        external
        view
        override
        returns (RatingForRestaurant[] memory)
    {
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        return restaurantRatings[restaurantId];
    }
}