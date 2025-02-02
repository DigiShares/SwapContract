// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import {SwapContract} from "../src/SwapContract.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {PermitSignatureHelper} from "./utils/PermitSignatureHelper.sol";
import {SwapContractBaseSetup} from "./utils/SwapContractBaseSetup.sol";

contract SwapContractExpireTest is SwapContractBaseSetup {
    IPermit2.PermitSingle permitSingleWhitelistedOpeningToken1;
    IPermit2.PermitSingle permitSingleWhitelistedClosingToken1;

    bytes aliceOpeningSwapToken1;
    bytes bobClosingSwap1Token1;

    bytes aliceSignatureToken1;
    bytes bobSignatureToken1;

    function setUp() public override {
        SwapContractBaseSetup.setUp();

        permitSingleWhitelistedOpeningToken1 = PermitSignatureHelper
            .defaultERC20PermitAllowance(
                address(whitelistedOpeningToken1),
                uint160(3 * ALICE_BALANCE_TO_SPEND),
                uint48(block.timestamp + 15 days),
                uint48(0),
                address(swapContract)
            );

        permitSingleWhitelistedClosingToken1 = PermitSignatureHelper
            .defaultERC20PermitAllowance(
                address(whitelistedClosingToken1),
                uint160(3 * BOB_BALANCE_TO_SPEND),
                uint48(block.timestamp + 15 days),
                uint48(0),
                address(swapContract)
            );

        aliceSignatureToken1 = PermitSignatureHelper.getPermitSignature(
            permitSingleWhitelistedOpeningToken1,
            ALICE_PRIVATE_KEY,
            PERMIT2_DOMAIN_SEPARATOR
        );

        bobSignatureToken1 = PermitSignatureHelper.getPermitSignature(
            permitSingleWhitelistedClosingToken1,
            BOB_PRIVATE_KEY,
            PERMIT2_DOMAIN_SEPARATOR
        );

        vm.startPrank(alice);

        swapContract.singlePermit(
            permitSingleWhitelistedOpeningToken1,
            aliceSignatureToken1
        );
        swapContract.open(
            "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55",
            bob,
            address(whitelistedOpeningToken1),
            ALICE_BALANCE_TO_SPEND,
            address(whitelistedClosingToken1),
            BOB_BALANCE_TO_SPEND
        );
        vm.stopPrank();
    }

    function test_expire_swap() public {
        vm.startPrank(alice);
        // arrange
        vm.warp(vm.getBlockTimestamp() + 16 days);
        // act
        swapContract.expire(alice, "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55");
        vm.stopPrank();

        // assert
        assertEq(whitelistedOpeningToken1.balanceOf(address(swapContract)), 0);
        assertEq(
            whitelistedOpeningToken1.balanceOf(alice),
            ALICE_STARTING_BALANCE
        );
    }

    function test_revert_expire_swap_InvalidSwap() public {
        vm.startPrank(alice);

        // act assert
        vm.expectRevert(SwapContract.InvalidSwap.selector);
        swapContract.expire(alice, "invalid-swap-id");
        vm.stopPrank();
    }

    function test_revert_expire_swap_SwapNotOpen() public {
        vm.startPrank(bob);
        // arrange
        swapContract.singlePermit(
            permitSingleWhitelistedClosingToken1,
            bobSignatureToken1
        );
        swapContract.close(alice, "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55");
        vm.stopPrank();

        vm.startPrank(alice);
        // act assert
        vm.expectRevert(SwapContract.SwapNotOpen.selector);
        swapContract.expire(alice, "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55");

        vm.stopPrank();
    }

    function test_revert_expire_swap_SwapNotExpired() public {
        vm.startPrank(alice);
        // act assert
        vm.expectRevert(SwapContract.SwapNotExpired.selector);
        swapContract.expire(alice, "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55");
        vm.stopPrank();
    }
}
