// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import {SwapContract} from "../src/SwapContract.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {PermitSignatureHelper} from "./utils/PermitSignatureHelper.sol";
import {SwapContractBaseSetup} from "./utils/SwapContractBaseSetup.sol";

contract SwapContractCloseTest is SwapContractBaseSetup {
    IPermit2.PermitSingle permitSingleWhitelistedOpeningToken1;
    IPermit2.PermitSingle permitSingleWhitelistedClosingToken1;
    IPermit2.PermitSingle permitSingleWhitelistedClosingToken2;

    bytes aliceOpeningSwapToken1;
    bytes bobClosingSwap1Token1;
    bytes bobClosingSwap2Token1;

    bytes aliceSignatureToken1;
    bytes bobSignatureToken1;
    bytes bobSignatureToken2;

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

        permitSingleWhitelistedClosingToken2 = PermitSignatureHelper
            .defaultERC20PermitAllowance(
                address(whitelistedClosingToken2),
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
        bobSignatureToken2 = PermitSignatureHelper.getPermitSignature(
            permitSingleWhitelistedClosingToken2,
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

    function test_close_swap() public {
        vm.startPrank(bob);
        // arrange
        swapContract.singlePermit(
            permitSingleWhitelistedClosingToken1,
            bobSignatureToken1
        );
        // act
        swapContract.close(alice, "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55");
        vm.stopPrank();
        // assert
        assertEq(
            whitelistedOpeningToken1.balanceOf(bob),
            ALICE_BALANCE_TO_SPEND
        );
        assertEq(
            whitelistedClosingToken1.balanceOf(bob),
            BOB_STARTING_BALANCE - (BOB_BALANCE_TO_SPEND / 100) * 101
        );
        assertEq(
            whitelistedClosingToken1.balanceOf(alice),
            (BOB_BALANCE_TO_SPEND / 100) * 99
        );
        assertEq(
            whitelistedClosingToken1.balanceOf(percentageFeeReceiver1),
            (BOB_BALANCE_TO_SPEND / 100) * 2
        );
    }

    function test_revert_close_swap_InvalidSwap() public {
        vm.startPrank(bob);
        // act assert
        vm.expectRevert(SwapContract.InvalidSwap.selector);
        swapContract.close(alice, "invalid-swap-id");
        vm.stopPrank();
    }

    function test_revert_close_swap_SwapNotOpen() public {
        vm.startPrank(bob);
        // arrange
        swapContract.singlePermit(
            permitSingleWhitelistedClosingToken1,
            bobSignatureToken1
        );
        swapContract.close(alice, "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55");

        // act assert
        vm.expectRevert(SwapContract.SwapNotOpen.selector);
        swapContract.close(alice, "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55");
        vm.stopPrank();
    }

    function test_revert_close_swap_InvalidClosingWallet() public {
        vm.startPrank(alice);
        // act assert
        vm.expectRevert(SwapContract.InvalidClosingWallet.selector);
        swapContract.close(alice, "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55");
        vm.stopPrank();
    }

    function test_revert_close_swap_SwapExpired() public {
        vm.startPrank(bob);
        // arrange
        vm.warp(vm.getBlockTimestamp() + 16 days);
        // act assert
        vm.expectRevert(SwapContract.SwapExpired.selector);
        swapContract.close(alice, "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55");
        vm.stopPrank();
    }
}
