// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IPermit2} from "./interface/IPermit2.sol";

/**
 * @title OrderBook
 * @dev A contract for managing orders
 */
contract OrderBook {
    // Mapping to store the order book
    mapping(uint256 => bytes32) public orderBook;

    // Struct to store information about an order
    struct Order {
        uint256 orderID;
        bool isMaker;
        uint256 optionAmount;
        uint256 permiumRatio;
        uint48 deadline;
        uint256 nonce;
        bytes signature;
        address optionContractAddress;
    }

    // Events
    event orderAdded(address owner, Order order);
    event orderUpdated(address owner, Order newOrder);
    event orderDeleted(uint orderID);

    /**
     * @dev Adds an order to the order book
     * @param order The order to be added
     */
    function addOrder(Order memory order) external {
        require(uint256(orderBook[order.orderID]) == 0, "ERROR: orderID already exists");
        orderBook[order.orderID] = _hash(msg.sender, order);

        emit orderAdded(msg.sender, order);
    }

    /**
     * @dev Updates an order in the order book
     * @param oldOrder The old order to be updated
     * @param newOrder The new order to replace the old order
     */
    function updateOrder(Order memory oldOrder, Order memory newOrder) external {
        require(orderBook[oldOrder.orderID] == _hash(msg.sender, oldOrder), "ERROR: order does not exist");
        orderBook[oldOrder.orderID] = _hash(msg.sender, newOrder);

        emit orderUpdated(msg.sender, newOrder);
    }

    /**
     * @dev Deletes an order from the order book
     * @param order The order to be deleted
     */
    function deleteOrder(Order memory order) external {
        require(orderBook[order.orderID] == _hash(msg.sender, order), "ERROR: order does not exist");
        orderBook[order.orderID] = bytes32(0);

        emit orderDeleted(order.orderID);
    }

    /**
     * @dev Hashes an order
     * @param owner The address of the owner of the order
     * @param order The order to be hashed
     * @return The hash of the order
     */
    function _hash(address owner, Order memory order) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                owner,
                order.orderID,
                order.isMaker,
                order.optionAmount,
                order.permiumRatio,
                order.deadline,
                order.nonce,
                order.signature,
                order.optionContractAddress
            )
        );
    }

}