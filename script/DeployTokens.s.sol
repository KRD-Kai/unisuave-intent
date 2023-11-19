// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {TestERC20} from "./utils/TestERC20.sol";
import {Constants} from "./Constants.sol";

contract DeployTokens is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        uint256 amount = 2 ** 128;
        TestERC20 tokenA = new TestERC20("WrappedETH", "testWETH", amount);
        TestERC20 tokenB = new TestERC20("USDC", "testUSDC", amount);

        tokenA.approve(Constants.POOL_MANAGER, amount);
        tokenB.approve(Constants.POOL_MANAGER, amount);

        vm.stopBroadcast();
    }
}
