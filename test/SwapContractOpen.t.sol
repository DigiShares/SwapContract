// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import {SwapContract} from "../src/SwapContract.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {PermitSignatureHelper} from "./utils/PermitSignatureHelper.sol";
import {SwapContractBaseSetup} from "./utils/SwapContractBaseSetup.sol";

contract SwapContractOpenTest is SwapContractBaseSetup {
    IPermit2.PermitSingle permitSingleWhitelistedOpeningToken1;
    IPermit2.PermitSingle permitSingleBlacklistedOpeningToken;
    IPermit2.PermitSingle permitSingleWhitelistedClosingToken3;

    bytes aliceSignatureToken1;
    bytes aliceSignatureBlacklistedToken;
    bytes aliceSignatureClosingToken3;

    function setUp() public override {
        SwapContractBaseSetup.setUp();

        permitSingleWhitelistedOpeningToken1 = PermitSignatureHelper
            .defaultERC20PermitAllowance(
                address(whitelistedOpeningToken1),
                uint160(3 * ALICE_BALANCE_TO_SPEND),
                uint48(block.timestamp + 5),
                uint48(0),
                address(swapContract)
            );

        permitSingleBlacklistedOpeningToken = PermitSignatureHelper
            .defaultERC20PermitAllowance(
                address(blacklistedOpeningToken),
                uint160(3 * ALICE_BALANCE_TO_SPEND),
                uint48(block.timestamp + 5),
                uint48(0),
                address(swapContract)
            );

        permitSingleWhitelistedClosingToken3 = PermitSignatureHelper
            .defaultERC20PermitAllowance(
                address(whitelistedClosingToken3),
                uint160(ALICE_BALANCE_TO_SPEND),
                uint48(block.timestamp + 5),
                uint48(0),
                address(swapContract)
            );

        aliceSignatureToken1 = PermitSignatureHelper.getPermitSignature(
            permitSingleWhitelistedOpeningToken1,
            ALICE_PRIVATE_KEY,
            PERMIT2_DOMAIN_SEPARATOR
        );
        aliceSignatureBlacklistedToken = PermitSignatureHelper
            .getPermitSignature(
                permitSingleBlacklistedOpeningToken,
                ALICE_PRIVATE_KEY,
                PERMIT2_DOMAIN_SEPARATOR
            );

        aliceSignatureClosingToken3 = PermitSignatureHelper.getPermitSignature(
            permitSingleWhitelistedClosingToken3,
            ALICE_PRIVATE_KEY,
            PERMIT2_DOMAIN_SEPARATOR
        );
    }

    function test_open_swap() public {
        vm.startPrank(alice);

        // arrange
        swapContract.singlePermit(
            permitSingleWhitelistedOpeningToken1,
            aliceSignatureToken1
        );

        // act
        swapContract.open(
            "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55",
            bob,
            address(whitelistedOpeningToken1),
            ALICE_BALANCE_TO_SPEND,
            address(whitelistedClosingToken1),
            BOB_BALANCE_TO_SPEND
        );
        vm.stopPrank();

        // assert
        assertEq(
            whitelistedOpeningToken1.balanceOf(alice),
            ALICE_STARTING_BALANCE - ALICE_BALANCE_TO_SPEND
        );
        assertEq(
            whitelistedOpeningToken1.balanceOf(address(swapContract)),
            ALICE_BALANCE_TO_SPEND
        );
    }

    function test_revert_open_swap_SwapAlreadyOpen() public {
        vm.startPrank(alice);
        // arrange
        swapContract.singlePermit(
            permitSingleWhitelistedOpeningToken1,
            aliceSignatureToken1
        );

        // act
        swapContract.open(
            "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55",
            bob,
            address(whitelistedOpeningToken1),
            ALICE_BALANCE_TO_SPEND,
            address(whitelistedClosingToken1),
            BOB_BALANCE_TO_SPEND
        );

        // act assert
        vm.expectRevert(SwapContract.SwapAlreadyOpen.selector);
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

    function test_revert_open_swap_invalidToken_OpeningToken() public {
        vm.startPrank(alice);
        // arrange
        swapContract.singlePermit(
            permitSingleBlacklistedOpeningToken,
            aliceSignatureBlacklistedToken
        );

        // act assert
        vm.expectRevert(SwapContract.InvalidToken.selector);
        swapContract.open(
            "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55",
            bob,
            address(blacklistedOpeningToken),
            ALICE_BALANCE_TO_SPEND,
            address(whitelistedClosingToken1),
            BOB_BALANCE_TO_SPEND
        );
        vm.stopPrank();
    }

    function test_revert_open_swap_invalidToken_ClosingToken() public {
        vm.startPrank(alice);
        // arrange
        swapContract.singlePermit(
            permitSingleWhitelistedOpeningToken1,
            aliceSignatureToken1
        );

        // act assert
        vm.expectRevert(SwapContract.InvalidToken.selector);
        swapContract.open(
            "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55",
            bob,
            address(whitelistedOpeningToken1),
            ALICE_BALANCE_TO_SPEND,
            address(blacklistedClosingToken),
            BOB_BALANCE_TO_SPEND
        );
        vm.stopPrank();
    }

    function test_revert_open_swap_InvalidToken_sameToken_OpeningToken()
        public
    {
        vm.startPrank(alice);
        // arrange
        swapContract.singlePermit(
            permitSingleWhitelistedOpeningToken1,
            aliceSignatureToken1
        );

        // act assert
        vm.expectRevert(SwapContract.InvalidToken.selector);
        swapContract.open(
            "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55",
            bob,
            address(whitelistedOpeningToken1),
            ALICE_BALANCE_TO_SPEND,
            address(whitelistedOpeningToken1),
            BOB_BALANCE_TO_SPEND
        );
        vm.stopPrank();
    }

    function test_revert_open_swap_InvalidToken_sameToken_ClosingToken()
        public
    {
        vm.startPrank(alice);
        // arrange
        swapContract.singlePermit(
            permitSingleWhitelistedClosingToken3,
            aliceSignatureClosingToken3
        );

        // act assert
        vm.expectRevert(SwapContract.InvalidToken.selector);
        swapContract.open(
            "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55",
            bob,
            address(whitelistedClosingToken3),
            ALICE_BALANCE_TO_SPEND,
            address(whitelistedClosingToken3),
            BOB_BALANCE_TO_SPEND
        );
        vm.stopPrank();
    }

    function test_revert_open_swap_ZeroAddressForbidden() public {
        vm.startPrank(alice);
        // arrange
        swapContract.singlePermit(
            permitSingleWhitelistedOpeningToken1,
            aliceSignatureToken1
        );

        // act assert
        vm.expectRevert(SwapContract.ZeroAddressForbidden.selector);
        swapContract.open(
            "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55",
            address(0),
            address(whitelistedOpeningToken1),
            ALICE_BALANCE_TO_SPEND,
            address(whitelistedClosingToken1),
            BOB_BALANCE_TO_SPEND
        );
        vm.stopPrank();
    }

    function test_revert_open_swap_ZeroAmountForbidden() public {
        vm.startPrank(alice);
        // arrange
        swapContract.singlePermit(
            permitSingleWhitelistedOpeningToken1,
            aliceSignatureToken1
        );

        // act assert
        vm.expectRevert(SwapContract.ZeroAmountForbidden.selector);
        swapContract.open(
            "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55",
            bob,
            address(whitelistedOpeningToken1),
            0,
            address(whitelistedClosingToken1),
            BOB_BALANCE_TO_SPEND
        );
        vm.stopPrank();
    }
}
