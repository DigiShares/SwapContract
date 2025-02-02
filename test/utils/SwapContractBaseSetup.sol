// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {SwapContract} from "../../src/SwapContract.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {PermitSignatureHelper} from "./PermitSignatureHelper.sol";

contract SwapContractBaseSetup is Test, DeployPermit2, PermitSignatureHelper {
    // SwapContract variables
    SwapContract public swapContract;

    // Permit2 variables
    address permit2;
    address[] public openingTokenAddresses;
    bytes32 PERMIT2_DOMAIN_SEPARATOR;

    // Opening ERC20 tokens
    ERC20Mock whitelistedOpeningToken1;
    ERC20Mock whitelistedOpeningToken2;
    ERC20Mock whitelistedOpeningToken3;
    ERC20Mock blacklistedOpeningToken;

    // Closing ERC20 tokens
    ERC20Mock whitelistedClosingToken1;
    ERC20Mock whitelistedClosingToken2;
    ERC20Mock whitelistedClosingToken3;
    ERC20Mock blacklistedClosingToken;

    // Wallet addresses
    uint256 ALICE_PRIVATE_KEY = 0x1131231231234342de;
    address alice = vm.addr(ALICE_PRIVATE_KEY);
    uint256 ALICE_STARTING_BALANCE = 100 ether;
    uint256 ALICE_BALANCE_TO_SPEND = 1 ether;

    uint256 BOB_PRIVATE_KEY = 0x1213312432432432443;
    address bob = vm.addr(BOB_PRIVATE_KEY);
    uint256 BOB_STARTING_BALANCE = 100 ether;
    uint256 BOB_BALANCE_TO_SPEND = 1 ether;

    // receiver addresses
    address percentageFeeReceiver1 = vm.addr(0x123);

    function setUp() public virtual {
        // Deploy Permit2
        permit2 = deployPermit2();
        PERMIT2_DOMAIN_SEPARATOR = IPermit2(permit2).DOMAIN_SEPARATOR();

        // Deploy ERC20 tokens
        whitelistedOpeningToken1 = new ERC20Mock();
        whitelistedOpeningToken2 = new ERC20Mock();
        whitelistedOpeningToken3 = new ERC20Mock();
        blacklistedOpeningToken = new ERC20Mock();

        whitelistedClosingToken1 = new ERC20Mock();
        whitelistedClosingToken2 = new ERC20Mock();
        whitelistedClosingToken3 = new ERC20Mock();
        blacklistedClosingToken = new ERC20Mock();

        // Setup Permit2 variables
        openingTokenAddresses.push(address(whitelistedOpeningToken1));
        openingTokenAddresses.push(address(whitelistedOpeningToken2));

        // Deploy SwapContract
        swapContract = new SwapContract(permit2, 14 days);

        // Setup SwapContract state
        swapContract.updateOpeningToken(
            address(whitelistedOpeningToken1),
            true
        );
        swapContract.updateOpeningToken(
            address(whitelistedOpeningToken2),
            true
        );

        swapContract.updateOpeningToken(
            address(whitelistedOpeningToken3),
            true
        );

        swapContract.updateClosingToken(
            address(whitelistedClosingToken1),
            true
        );
        swapContract.updateClosingToken(
            address(whitelistedClosingToken2),
            true
        );

        swapContract.updateClosingToken(
            address(whitelistedClosingToken3),
            true
        );
        swapContract.addPercentageFee(percentageFeeReceiver1, 20);

        // Setup wallet balances

        deal(alice, ALICE_STARTING_BALANCE);
        deal(address(whitelistedOpeningToken1), alice, ALICE_STARTING_BALANCE);
        deal(address(whitelistedOpeningToken2), alice, ALICE_STARTING_BALANCE);
        deal(address(blacklistedOpeningToken), alice, ALICE_STARTING_BALANCE);
        deal(address(whitelistedClosingToken3), alice, ALICE_STARTING_BALANCE);

        deal(bob, BOB_STARTING_BALANCE);
        deal(address(whitelistedClosingToken1), bob, BOB_STARTING_BALANCE);
        deal(address(whitelistedClosingToken2), bob, BOB_STARTING_BALANCE);
        deal(address(blacklistedClosingToken), bob, BOB_STARTING_BALANCE);
        deal(address(whitelistedOpeningToken3), bob, BOB_STARTING_BALANCE);

        // Setup Permit2 approvals

        vm.startPrank(alice);
        whitelistedOpeningToken1.approve(permit2, type(uint256).max);
        whitelistedOpeningToken2.approve(permit2, type(uint256).max);
        blacklistedOpeningToken.approve(permit2, type(uint256).max);
        whitelistedClosingToken3.approve(permit2, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        whitelistedClosingToken1.approve(permit2, type(uint256).max);
        whitelistedClosingToken2.approve(permit2, type(uint256).max);
        blacklistedClosingToken.approve(permit2, type(uint256).max);
        whitelistedOpeningToken3.approve(permit2, type(uint256).max);
        vm.stopPrank();
    }
}
