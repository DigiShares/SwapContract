// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import {SwapContract} from "../src/SwapContract.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {PermitSignatureHelper} from "./utils/PermitSignatureHelper.sol";
import {SwapContractBaseSetup} from "./utils/SwapContractBaseSetup.sol";

contract SwapContractOpenTest is SwapContractBaseSetup {
    bytes aliceOpeningSwap1Token1;
    bytes aliceOpeningSwap2Token1;
    bytes aliceOpeningSwap3Token1;

    bytes aliceOpeningSwap1Token2;

    function setUp() public override {
        SwapContractBaseSetup.setUp();

        aliceOpeningSwap1Token1 = abi.encodeWithSignature(
            "open(string,address,address,uint256,address,uint256)",
            "9bf2fd5d-6ad2-49ac-844d-a9b3a8b54c55",
            bob,
            address(whitelistedOpeningToken1),
            ALICE_BALANCE_TO_SPEND,
            address(whitelistedClosingToken1),
            BOB_BALANCE_TO_SPEND
        );
        aliceOpeningSwap2Token1 = abi.encodeWithSignature(
            "open(string,address,address,uint256,address,uint256)",
            "54175926-8a2d-466f-a4bf-fdbb7a7f1737",
            bob,
            address(whitelistedOpeningToken1),
            ALICE_BALANCE_TO_SPEND,
            address(whitelistedClosingToken1),
            BOB_BALANCE_TO_SPEND
        );

        aliceOpeningSwap3Token1 = abi.encodeWithSignature(
            "open(string,address,address,uint256,address,uint256)",
            "d8e524ab-14b0-4273-9153-91437f528381",
            bob,
            address(whitelistedOpeningToken1),
            ALICE_BALANCE_TO_SPEND,
            address(whitelistedClosingToken1),
            BOB_BALANCE_TO_SPEND
        );

        aliceOpeningSwap1Token2 = abi.encodeWithSignature(
            "open(string,address,address,uint256,address,uint256)",
            "1f197b40-6476-4a9f-89de-5f813e13984b",
            bob,
            address(whitelistedOpeningToken2),
            ALICE_BALANCE_TO_SPEND,
            address(whitelistedClosingToken1),
            BOB_BALANCE_TO_SPEND
        );
    }

    function test_open_swap_multicall_singlePermit() public {
        vm.startPrank(alice);
        // arrange
        bytes[] memory dataAlice = new bytes[](4);
        IPermit2.PermitSingle
            memory permitSingleWhitelistedOpeningToken1 = PermitSignatureHelper
                .defaultERC20PermitAllowance(
                    address(whitelistedOpeningToken1),
                    uint160(3 * ALICE_BALANCE_TO_SPEND),
                    uint48(block.timestamp + 5),
                    uint48(0),
                    address(swapContract)
                );

        bytes memory aliceSignatureToken1 = PermitSignatureHelper
            .getPermitSignature(
                permitSingleWhitelistedOpeningToken1,
                ALICE_PRIVATE_KEY,
                PERMIT2_DOMAIN_SEPARATOR
            );

        dataAlice[0] = abi.encodeWithSignature(
            "singlePermit(((address,uint160,uint48,uint48),address,uint256),bytes)",
            permitSingleWhitelistedOpeningToken1,
            aliceSignatureToken1
        );
        dataAlice[1] = aliceOpeningSwap1Token1;
        dataAlice[2] = aliceOpeningSwap2Token1;
        dataAlice[3] = aliceOpeningSwap3Token1;
        // act
        swapContract.multicall(dataAlice);
        vm.stopPrank();

        // assert
        assertEq(
            whitelistedOpeningToken1.balanceOf(alice),
            ALICE_STARTING_BALANCE -
                (ALICE_BALANCE_TO_SPEND * (dataAlice.length - 1))
        );
        assertEq(
            whitelistedOpeningToken1.balanceOf(address(swapContract)),
            ALICE_BALANCE_TO_SPEND * (dataAlice.length - 1)
        );
    }

    function test_open_swap_multicall_batchPermit() public {
        vm.startPrank(alice);
        // arrange
        bytes[] memory dataAlice = new bytes[](3);
        IPermit2.PermitBatch
            memory permitBatch = defaultERC20PermitBatchAllowance(
                openingTokenAddresses,
                uint160(1 ether),
                uint48(block.timestamp + 5),
                uint48(0),
                address(swapContract)
            );

        bytes memory signatureBatch = getPermitBatchSignature(
            permitBatch,
            ALICE_PRIVATE_KEY,
            PERMIT2_DOMAIN_SEPARATOR
        );

        dataAlice[0] = abi.encodeWithSignature(
            "batchPermit(((address,uint160,uint48,uint48)[],address,uint256),bytes)",
            permitBatch,
            signatureBatch
        );
        dataAlice[1] = aliceOpeningSwap1Token1;
        dataAlice[2] = aliceOpeningSwap1Token2;
        // act
        swapContract.multicall(dataAlice);
        vm.stopPrank();
        // assert
        assertEq(
            whitelistedOpeningToken1.balanceOf(alice),
            ALICE_STARTING_BALANCE - ALICE_BALANCE_TO_SPEND
        );
        assertEq(
            whitelistedOpeningToken2.balanceOf(alice),
            ALICE_STARTING_BALANCE - ALICE_BALANCE_TO_SPEND
        );
        assertEq(
            whitelistedOpeningToken1.balanceOf(address(swapContract)),
            ALICE_BALANCE_TO_SPEND
        );
        assertEq(
            whitelistedOpeningToken2.balanceOf(address(swapContract)),
            ALICE_BALANCE_TO_SPEND
        );
    }
}
