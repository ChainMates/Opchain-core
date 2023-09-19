//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract OrderBook {
    mapping(uint256 => bytes32) public orderBook;

    struct Order {
        uint256 orderID;
        bool isMaker;
        uint256 optionAmount;
        uint256 permiumRatio;
        uint64 deadline;
        uint256 nonce;
        bytes signature;
        address optionContractAddress;
    }

    event orderAdded(address owner, Order order);
    event orderUpdated(address owner, Order newOrder);
    event orderDeleted(address owner, Order deletedOrder);

    function addOrder(Order memory order) external {
        require(
            uint256(orderBook[order.orderID]) == 0,
            "ERROR : orderID already exist"
        );
        orderBook[order.orderID] = _hash(msg.sender, order);

        emit orderAdded(msg.sender, order);
    }

    function updateOrder(
        Order memory oldOrder,
        Order memory newOrder
    ) external {
        require(
            orderBook[oldOrder.orderID] == _hash(msg.sender, oldOrder),
            "ERROR : order does not exist"
        );
        orderBook[oldOrder.orderID] = _hash(msg.sender, newOrder);

        emit orderUpdated(msg.sender, newOrder);
    }

    function deleteOrder(Order memory order) external {
        require(
            orderBook[order.orderID] == _hash(msg.sender, order),
            "ERROR : order does not exist"
        );
        orderBook[order.orderID] = bytes32(0);

        emit orderDeleted(msg.sender, order);
    }

    function _hash(
        address owner,
        Order memory order
    ) public pure returns (bytes32) {
        return
            keccak256(
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
