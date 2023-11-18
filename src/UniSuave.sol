// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "suave/Suave.sol";

contract UniSuave {
    struct Order {
        address creator;
        address sellToken;
        address buyToken;
        uint32 validTo;
        uint256 minSellAmount;
        uint256 buyAmount;
    }

    struct OrderIntent {
        Order order;
        uint256 nonce;
        bytes signature;
    }

    event OrderCreated(
        address indexed creator,
        address indexed sellToken,
        address indexed buyToken,
        uint32 validTo,
        uint256 minSellAmount,
        uint256 buyAmount
    );

    function emitOrder(Order memory order) external payable {
        emit OrderCreated(
            order.creator, order.sellToken, order.buyToken, order.validTo, order.minSellAmount, order.buyAmount
        );
    }

    function createOrder() public view returns (bytes memory) {
        require(Suave.isConfidential());

        bytes memory intentData = Suave.confidentialInputs();
        OrderIntent memory orderIntent = abi.decode(intentData, (OrderIntent));

        // Create bid only allow this contract to retrieve it
        address[] memory allowedList = new address[](1);
        allowedList[0] = address(this);
        Suave.Bid memory bid = Suave.newBid(10, allowedList, allowedList, "");

        // Save order intent with bid
        Suave.confidentialStore(bid.id, "orderIntent", abi.encode(orderIntent));

        return abi.encodeWithSelector(this.emitOrder.selector, orderIntent.order);
    }
}
