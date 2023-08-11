// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {HookTest} from "./utils/HookTest.sol";
import {Deployers} from "@uniswap/v4-core/test/foundry-tests/utils/Deployers.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/contracts/libraries/PoolId.sol";
import {MultiSigSwapHook} from "../src/MultiSigSwapHook.sol";

contract MultiSigSwapHookTest is HookTest, Deployers {
    using PoolIdLibrary for IPoolManager.PoolKey;

    MultiSigSwapHook multiSigSwapHook;
    IPoolManager.PoolKey poolKey;
    PoolId poolId;

    function setUp() public {
        HookTest.initHookTestEnv();

        address[] memory signers = new address[](2);
        signers[0] = address(this);
        signers[1] = address(0x1234);

        multiSigSwapHook = new MultiSigSwapHook(IPoolManager(manager), signers, 2);
        etchHook(address(multiSigSwapHook), address(multiSigSwapHook));

        poolKey = IPoolManager.PoolKey(
            Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(multiSigSwapHook)
        );
        poolId = poolKey.toId();
        manager.initialize(poolKey, SQRT_RATIO_1_1);
    }

    function testApproveSwap() public {
        bytes32 swapHash = keccak256(abi.encode(keccak256("mockSwapParams")));

        multiSigSwapHook.approveSwap(swapHash);
        (uint256 count, bool hasSigned) = multiSigSwapHook.getApprovalDetails(swapHash);

        assertEq(count, 1);
        assertTrue(hasSigned);
    }

    function testFailSwapWithInsufficientApprovals() public {
        bytes32 swapHash = keccak256(abi.encode(keccak256("mockSwapParams")));

        multiSigSwapHook.approveSwap(swapHash);

        // This should fail as it requires 2 approvals
        multiSigSwapHook.beforeSwap(address(0), poolKey, IPoolManager.SwapParams({ zeroForOne: true, amountSpecified: 1, sqrtPriceLimitX96: MIN_PRICE_LIMIT }));
    }

    function testUnauthorizedSignerApproval() public {
        bytes32 swapHash = keccak256(abi.encode(keccak256("mockSwapParams")));
        try multiSigSwapHook.approveSwap(swapHash) { assert(false, "Should have reverted"); } catch {}
    }


}
