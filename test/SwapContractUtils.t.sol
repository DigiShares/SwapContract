// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {SwapContract} from "../src/SwapContract.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {PermitSignatureHelper} from "./utils/PermitSignatureHelper.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";

contract SwapContractUtilsTest is Test, DeployPermit2, PermitSignatureHelper {
    SwapContract public swapContract;
    ERC20Mock openingToken;
    ERC20Mock closingToken;
    address permit2;

    bytes signature;
    address[] addresses;
    address invalidSpender = address(0x123);

    function setUp() public {
        permit2 = deployPermit2();
        swapContract = new SwapContract(address(permit2), 14 days);

        openingToken = new ERC20Mock();
        closingToken = new ERC20Mock();

        addresses.push(address(openingToken));
        addresses.push(address(closingToken));
    }

    function test_revert_singlePermit_InvalidSpender() public {
        // arrange
        IPermit2.PermitSingle memory permitSingle = PermitSignatureHelper
            .defaultERC20PermitAllowance(
                address(openingToken),
                uint160(1 ether),
                uint48(block.timestamp + 15 days),
                uint48(0),
                invalidSpender
            );
        // act assert
        vm.expectRevert(SwapContract.InvalidSpender.selector);
        swapContract.singlePermit(permitSingle, signature);
    }

    function test_revert_batchPermit_InvalidSpender() public {
        // arrange
        IPermit2.PermitBatch memory permitBatch = PermitSignatureHelper
            .defaultERC20PermitBatchAllowance(
                addresses,
                uint160(1 ether),
                uint48(block.timestamp + 15 days),
                uint48(0),
                invalidSpender
            );
        // act assert
        vm.expectRevert(SwapContract.InvalidSpender.selector);
        swapContract.batchPermit(permitBatch, signature);
    }

    function test_revert_updateOpeningToken_ZeroAddressForbidden() public {
        vm.expectRevert(SwapContract.ZeroAddressForbidden.selector);
        swapContract.updateOpeningToken(address(0), true);
    }

    function test_revert_updateOpeningToken_TokenAddressMatchForbidden()
        public
    {
        // arrange
        swapContract.updateClosingToken(address(openingToken), true);
        // act assert
        vm.expectRevert(SwapContract.TokenAddressMatchForbidden.selector);
        swapContract.updateOpeningToken(address(openingToken), true);
    }

    function test_revert_updateClosingToken_ZeroAddressForbidden() public {
        // arrange
        address zeroAddress = address(0);
        // act assert
        vm.expectRevert(SwapContract.ZeroAddressForbidden.selector);
        swapContract.updateClosingToken(zeroAddress, true);
    }

    function test_revert_updateClosingToken_TokenAddressMatchForbidden()
        public
    {
        // arrange
        swapContract.updateOpeningToken(address(closingToken), true);
        // act assert
        vm.expectRevert(SwapContract.TokenAddressMatchForbidden.selector);
        swapContract.updateClosingToken(address(closingToken), true);
    }

    function test_revert_updatePercentageFee_ZeroAddressForbidden() public {
        // arrange
        address zeroAddress = address(0);
        // act assert
        vm.expectRevert(SwapContract.ZeroAddressForbidden.selector);
        swapContract.updatePercentageFee(1, zeroAddress, 0);
    }

    function test_revert_addPercentageFee_ZeroAddressForbidden() public {
        // arrange
        address zeroAddress = address(0);
        // act assert
        vm.expectRevert(SwapContract.ZeroAddressForbidden.selector);
        swapContract.addPercentageFee(zeroAddress, 0);
    }
}
