// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import {MultiSigSwapHook} from "../src/MultiSigSwapHook.sol";
import {PoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {MultiSigSwapHookImplementation} from "../test/implementation/MultiSigSwapHookImplementation.sol";

contract MultiSigSwapHookScript is Script {

    function setUp() public {}

    function run() public {
        vm.broadcast();
        PoolManager manager = new PoolManager(500000);

        uint160 targetFlags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | 0x1);

        vm.broadcast();
        MultiSigSwapHookImplementation impl = new MultiSigSwapHookImplementation(manager, MultiSigSwapHook(address(targetFlags)));
        etchHook(address(impl), address(targetFlags));

        vm.startBroadcast();
        // Helpers for interacting with the pool
        // Further interactions can be implemented here if required
        vm.stopBroadcast();
    }

    function mineSalt(uint160 targetFlags, bytes memory creationCode)
    internal
    view
    returns (address hook, uint256 salt)
    {
        for (salt; salt < 100; salt++) {
            hook = _getAddress(salt, creationCode);
            if (uint160(hook) & targetFlags == targetFlags) {
                break;
            }
        }
    }

    function _getAddress(uint256 salt, bytes memory creationCode) internal view returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(creationCode)))))
        );
    }

    function etchHook(address _implementation, address _hook) internal {
        (, bytes32[] memory writes) = vm.accesses(_implementation);

        string[] memory command = new string[](5);
        command[0] = "cast";
        command[1] = "rpc";
        command[2] = "anvil_setCode";
        command[3] = vm.toString(_hook);
        command[4] = vm.toString(_implementation.code);
        vm.ffi(command);

        unchecked {
            for (uint256 i = 0; i < writes.length; i++) {
                bytes32 slot = writes[i];
                vm.store(_hook, slot, vm.load(_implementation, slot));
            }
        }
    }
}
