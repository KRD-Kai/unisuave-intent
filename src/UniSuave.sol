// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "suave/Suave.sol";

contract UniSuave {
    struct Order {
        address creator;
        address sellToken;
        address buyToken;
        uint32 validTo;
        uint256 maxSellAmount;
        uint256 buyAmount;
    }

    struct OrderIntent {
        Order order;
        uint256 nonce;
        bytes signature;
    }

    struct OrderSolutionResult {
        address solver;
        uint64 score; // egp score
        Suave.BidId bidId;
    }

    event OrderCreated(
        Suave.BidId bidId,
        address indexed creator,
        address indexed sellToken,
        address indexed buyToken,
        uint32 validTo,
        uint256 minSellAmount,
        uint256 buyAmount
    );

    event blockNumberUpdated(uint64 blockNumber);

    mapping(uint64 blockNumber => OrderSolutionResult) public topRankedSolution;
    uint64 latestExternalBlock;

    function setBlockNumber(uint64 blockNumber) external payable {
        latestExternalBlock = blockNumber;
        emit blockNumberUpdated(blockNumber);
    }

    function updateExternalBlockNumber() public view returns (bytes memory) {
        uint64 blockNumber = Suave.getBlockNumber();
        return abi.encodeWithSelector(this.setBlockNumber.selector, blockNumber);
    }

    // Emites order that solvers listen to
    function emitOrder(Order memory order, Suave.BidId bidId) external payable {
        emit OrderCreated(
            bidId, order.creator, order.sellToken, order.buyToken, order.validTo, order.maxSellAmount, order.buyAmount
        );
    }

    function emptyCallback() external payable {}

    function newOrder() external payable returns (bytes memory) {
        require(Suave.isConfidential());

        bytes memory intentData = Suave.confidentialInputs();
        OrderIntent memory orderIntent = abi.decode(intentData, (OrderIntent));

        // Create bid for intent, only allow this contract to retrieve it
        // Important for concealling signature, until retrieving later
        address[] memory allowedList = new address[](1);
        allowedList[0] = address(this);
        Suave.Bid memory bid = Suave.newBid(10, allowedList, allowedList, "");

        // Save order intent with bid
        Suave.confidentialStore(bid.id, "orderIntent", abi.encode(orderIntent));

        return abi.encodeWithSelector(this.emitOrder.selector, orderIntent.order, bid.id);
    }

    // (Shouldn't just let any solver provide a builder url in the future)
    function submitSolution(string memory builderUrl, Suave.BidId orderBidId) external payable returns (bytes memory) {
        require(Suave.isConfidential());

        uint64 previousBlockNumber = latestExternalBlock;
        // Update block before evalutating sovler solution
        updateExternalBlockNumber();

        if (latestExternalBlock > previousBlockNumber) {
            // Settle top ranking solution for previous auction
            Suave.BidId topSolutionBidId = topRankedSolution[previousBlockNumber].bidId;
            bytes memory bundleData = Suave.fillMevShareBundle(topSolutionBidId);
            Suave.submitBundleJsonRPC(builderUrl, "mev_sendBundle", bundleData);
        }

        // Rank solution in current auction and save confidentially
        _rankSolution(orderBidId);
        return abi.encodeWithSelector(this.emptyCallback.selector);
    }

    function _rankSolution(Suave.BidId orderBidId) internal {
        bytes memory bundleData = Suave.confidentialInputs();
        uint64 egp = Suave.simulateBundle(bundleData);

        bytes memory intentData = Suave.confidentialRetrieve(orderBidId, "orderIntent");
        OrderIntent memory orderIntent = abi.decode(intentData, (OrderIntent));

        // Signature validation on order intent needs to be done with different future implementation

        OrderSolutionResult memory currentTopSolution = topRankedSolution[latestExternalBlock];

        // If score higher than previous update the topRankedSolution for this block
        if (egp > currentTopSolution.score) {
            //Store solution bundle confidentialy, submitted later with precompile when auction ends (new block on goerli)
            address[] memory allowedList = new address[](1);
            allowedList[0] = address(this);
            Suave.Bid memory bid = Suave.newBid(10, allowedList, allowedList, "");
            Suave.confidentialStore(bid.id, "mevshare:v0:ethBundles", bundleData);

            OrderSolutionResult memory result = OrderSolutionResult(msg.sender, egp, bid.id);
            topRankedSolution[latestExternalBlock] = result;
        }
        // Else, we don't care, as there's already a better solution (just for PoC)
    }
}
