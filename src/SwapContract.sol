//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

contract SwapContract is Multicall, Ownable2Step {
    using SafeERC20 for IERC20;

    enum Status {
        OPEN,
        CLOSED,
        EXPIRED
    }

    struct Swap {
        address openingToken;
        uint256 openingTokenAmount;
        address closingWallet;
        address closingToken;
        uint256 closingTokenAmount;
        uint256 expiry;
        Status status;
    }

    struct PercentageFee {
        address recipient;
        uint8 percentage;
    }

    IPermit2 public immutable permit2;
    PercentageFee[] public percentageFees;
    uint32 public swapExpiry;

    mapping(address openingWallet => mapping(string swapId => Swap swap))
        private swaps;
    mapping(address => bool) public openingTokens;
    mapping(address => bool) public closingTokens;

    event Opened(
        string indexed swapId,
        address indexed openingWallet,
        address indexed openingToken,
        uint256 openingTokenAmount
    );
    event Closed(
        string indexed swapId,
        address indexed closingWallet,
        address indexed closingToken,
        uint256 closingTokenAmount
    );
    event Expired(
        string indexed swapId,
        address indexed openingWallet,
        address indexed openingToken,
        uint256 openingTokenAmount
    );

    event SinglePermit(address indexed signer, address indexed spender);
    event BatchPermit(address indexed signer, address indexed spender);
    event OpeningTokenUpdated(address indexed token, bool indexed status);
    event ClosingTokenUpdated(address indexed token, bool indexed status);
    event PercentageFeeAdded(
        address indexed recipient,
        uint8 indexed percentage
    );
    event PercentageFeeRemoved(
        address indexed recipient,
        uint8 indexed percentage
    );
    event PercentageFeeUpdated(
        address indexed recipient,
        uint8 indexed percentage
    );
    event SwapExpiryUpdated(uint32 indexed swapExpiry);

    error ZeroAddressForbidden();
    error ZeroAmountForbidden();
    error TokenAddressMatchForbidden();
    error SwapNotOpen();
    error SwapNotExpired();
    error SwapAlreadyOpen();
    error SwapExpired();
    error InvalidClosingWallet();
    error InvalidSpender();
    error InvalidToken();
    error InvalidSwap();
    error InvalidFee();
    error FeeExceededAmount();

    modifier isValidSpender(address spender) {
        if (spender != address(this)) revert InvalidSpender();
        _;
    }

    modifier isValidAddress(address _address) {
        if (_address == address(0)) revert ZeroAddressForbidden();
        _;
    }

    /**
     * @dev Constructor for the SwapContract.
     * @param _permit2 The address of the Permit2 contract.
     * @param _swapExpiry The expiry time for the swap in seconds.
     */
    constructor(
        address _permit2,
        uint32 _swapExpiry
    ) Ownable(msg.sender) isValidAddress(_permit2) {
        permit2 = IPermit2(_permit2);
        swapExpiry = _swapExpiry;
    }

    /**
     * @notice Opens a new swap and deposits ERC20 tokens.
     * @dev emits an `Opened` event upon successful opening of the swap.
     * @dev reverts with `SwapAlreadyOpen` if the swap number is already used,
     * @dev reverts with `InvalidToken` if the tokens are invalid,
     * @dev reverts with `ZeroAddressForbidden` if the closing wallet address is zero,
     * @dev reverts with `ZeroAmountForbidden` if the token amounts are zero.
     * @dev reverts with `InvalidClosingWallet` if the closing wallet is the same as the opening wallet.
     * @param _swapId The unique identifier for the swap.
     * @param _closingWallet The address of the wallet that will close the swap.
     * @param _openingToken The address of the token being offered in the swap.
     * @param _openingTokenAmount The amount of the opening token being offered.
     * @param _closingToken The address of the token being requested in the swap.
     * @param _closingTokenAmount The amount of the closing token being requested.
     * @return bool Returns true if the swap is successfully opened.
     */
    function open(
        string memory _swapId,
        address _closingWallet,
        address _openingToken,
        uint256 _openingTokenAmount,
        address _closingToken,
        uint256 _closingTokenAmount
    ) external isValidAddress(_closingWallet) returns (bool) {
        if (swaps[msg.sender][_swapId].expiry != 0) revert SwapAlreadyOpen();
        if (!openingTokens[_openingToken] || !closingTokens[_closingToken])
            revert InvalidToken();
        if (_openingTokenAmount == 0 || _closingTokenAmount == 0)
            revert ZeroAmountForbidden();
        if (msg.sender == _closingWallet) revert InvalidClosingWallet();

        swaps[msg.sender][_swapId] = Swap({
            closingWallet: _closingWallet,
            openingToken: _openingToken,
            openingTokenAmount: _openingTokenAmount,
            closingToken: _closingToken,
            closingTokenAmount: _closingTokenAmount,
            expiry: block.timestamp + swapExpiry,
            status: Status.OPEN
        });

        emit Opened(_swapId, msg.sender, _openingToken, _openingTokenAmount);

        permit2.transferFrom(
            msg.sender,
            address(this),
            SafeCast.toUint160(_openingTokenAmount),
            _openingToken
        );

        return true;
    }

    /**
     * @notice Closes an already open swap, calculates fees and sends openingTokens to closingWallet,
     * closingTokens to openingWallet and fee recipients.
     * @dev emits a `Closed` event when the swap is successfully closed.
     * @dev reverts with `InvalidSwap` If the swap does not exist.
     * @dev reverts with `SwapNotOpen` If the swap is not in an OPEN state.
     * @dev reverts with `IncorrectClosingWallet` If the caller is not the designated closing wallet.
     * @dev reverts with `SwapExpired` If the swap has expired.
     * @dev reverts with `InvalidFee` If the fee is zero.
     * @dev reverts with `FeeExceededAmount` If the total fee amount exceeds the closing token amount.
     * @param _openingWallet The address of the wallet that opened the swap.
     * @param _swapId The unique identifier of the swap.
     * @return bool Returns true if the swap was successfully closed.
     */
    function close(
        address _openingWallet,
        string memory _swapId
    ) external returns (bool) {
        Swap memory swap = swaps[_openingWallet][_swapId];

        if (swap.expiry == 0) revert InvalidSwap();
        if (swap.status != Status.OPEN) revert SwapNotOpen();
        if (msg.sender != swap.closingWallet) revert InvalidClosingWallet();
        if (block.timestamp > swap.expiry) revert SwapExpired();

        swaps[_openingWallet][_swapId].status = Status.CLOSED;

        uint256 totalFee;

        for (uint256 i; i < percentageFees.length; ++i) {
            uint256 fee = (swap.closingTokenAmount *
                percentageFees[i].percentage) / 1000;
            if (fee == 0) revert InvalidFee();
            totalFee += fee / 2;
            permit2.transferFrom(
                msg.sender,
                percentageFees[i].recipient,
                uint160(fee),
                swap.closingToken
            );
        }

        if (totalFee > swap.closingTokenAmount) revert FeeExceededAmount();

        emit Closed(
            _swapId,
            msg.sender,
            swap.closingToken,
            swap.closingTokenAmount
        );

        permit2.transferFrom(
            msg.sender,
            _openingWallet,
            SafeCast.toUint160(swap.closingTokenAmount - totalFee),
            swap.closingToken
        );

        IERC20(swap.openingToken).safeTransfer(
            msg.sender,
            swap.openingTokenAmount
        );

        return true;
    }

    /**
     * @notice Expires a swap if it is open and past its expiry time.
     * @dev emits an `Expired` event when the swap is successfully expired.
     * @dev reverts with `InvalidSwap` If the swap does not exist or has already expired.
     * @dev reverts with `SwapNotOpen` If the swap is not in an OPEN status.
     * @dev reverts with `SwapNotExpired` If the current block timestamp is less than or equal to the swap's expiry time.
     * @param _openingWallet The address of the wallet that opened the swap.
     * @param _swapId The unique identifier of the swap.
     * @return bool Returns true if the swap was successfully expired.
     */
    function expire(
        address _openingWallet,
        string memory _swapId
    ) external returns (bool) {
        Swap memory swap = swaps[_openingWallet][_swapId];

        if (swap.expiry == 0) revert InvalidSwap();
        if (swap.status != Status.OPEN) revert SwapNotOpen();
        if (block.timestamp <= swap.expiry) revert SwapNotExpired();

        swaps[_openingWallet][_swapId].status = Status.EXPIRED;

        emit Expired(
            _swapId,
            msg.sender,
            swap.openingToken,
            swap.openingTokenAmount
        );

        IERC20(swap.openingToken).safeTransfer(
            _openingWallet,
            swap.openingTokenAmount
        );

        return true;
    }

    /**
     * @notice Retrieves the swap data for a given wallet and swapId.
     * @param _openingWallet The address of the wallet that initiated the swap.
     * @param _swapId The unique identifier of the swap.
     * @return Swap The swap data associated with the given wallet and swap number.
     */
    function getSwapData(
        address _openingWallet,
        string memory _swapId
    ) external view returns (Swap memory) {
        return swaps[_openingWallet][_swapId];
    }

    /**
     * @notice Executes a single permit operation.
     * @dev emits a `SinglePermit` event when the single permit operation is successfully executed
     * @dev This function calls the permit method on the permit2 contract with the provided parameters.
     * @param _permitSingle The permit data containing details such as the spender and the amount.
     * @param _signature The signature authorizing the permit.
     * @return bool Returns true if the permit operation is successful.
     */
    function singlePermit(
        IPermit2.PermitSingle calldata _permitSingle,
        bytes calldata _signature
    ) external isValidSpender(_permitSingle.spender) returns (bool) {
        emit SinglePermit(msg.sender, _permitSingle.spender);
        permit2.permit(msg.sender, _permitSingle, _signature);
        return true;
    }

    /**
     * @notice Executes a batch permit operation.
     * @dev emits a `BatchPermit` event when the batch permit operation is successfully executed
     * @dev This function allows the caller to batch multiple permit operations in a single transaction.
     * @param _permitBatch The batch of permits to be executed.
     * @param _signature The signature authorizing the batch permit.
     * @return bool Returns true if the batch permit operation is successful.
     */
    function batchPermit(
        IPermit2.PermitBatch calldata _permitBatch,
        bytes calldata _signature
    ) external isValidSpender(_permitBatch.spender) returns (bool) {
        emit BatchPermit(msg.sender, _permitBatch.spender);
        permit2.permit(msg.sender, _permitBatch, _signature);
        return true;
    }

    /**
     * @notice Updates the status of an opening token.
     * @dev emits an `OpeningTokenUpdated` event when the opening token status is successfully updated.
     * @dev This function can only be called by the contract owner.
     * @dev reverts with `ZeroAddressForbidden` if the provided token address is the zero address.
     * @dev reverts with `TokenAddressMatchForbidden` if the provided token address is already listed as a closing token.
     * @param _token The address of the token to update.
     * @param _status The new status of the token (true for active, false for inactive).
     */
    function updateOpeningToken(
        address _token,
        bool _status
    ) external isValidAddress(_token) onlyOwner {
        if (closingTokens[_token]) revert TokenAddressMatchForbidden();
        openingTokens[_token] = _status;
        emit OpeningTokenUpdated(_token, _status);
    }

    /**
     * @notice Updates the status of a closing token.
     * @dev emits a `ClosingTokenUpdated` event when the closing token status is successfully updated.
     * @dev This function can only be called by the owner of the contract.
     * @dev reverts with `ZeroAddressForbidden` if the provided token address is the zero address.
     * @dev reverts with `TokenAddressMatchForbidden` if the provided token address is already listed as an opening token.
     * @param _token The address of the token to update.
     * @param _status The new status of the token (true for active, false for inactive).
     */
    function updateClosingToken(
        address _token,
        bool _status
    ) external isValidAddress(_token) onlyOwner {
        if (openingTokens[_token]) revert TokenAddressMatchForbidden();
        closingTokens[_token] = _status;
        emit ClosingTokenUpdated(_token, _status);
    }

    /**
     * @notice Updates the percentage fee for a given index.
     * @dev emits a `PercentageFeeUpdated` event when the fee is successfully updated.
     * @dev This function can only be called by the owner of the contract.
     * @dev reverts with `ZeroAddressForbidden` if the provided recipient address is zero.
     * @dev reverts with `InvalidFee` if the provided percentage is above the treshold.
     * @param _index The index of the percentage fee to update.
     * @param _recipient The address of the recipient for the percentage fee.
     * @param _percentage The new percentage fee to set, eg. 24 == 2.4%, maximum 255 == 25.5%.
     */
    function updatePercentageFee(
        uint256 _index,
        address _recipient,
        uint8 _percentage
    ) external isValidAddress(_recipient) onlyOwner {
        percentageFees[_index] = PercentageFee(_recipient, _percentage);
        emit PercentageFeeUpdated(_recipient, _percentage);
    }

    /**
     * @notice Adds a new percentage fee to the list of percentage fees.
     @ dev emits a `PercentageFeeAdded` event when the fee is successfully added.
     * @dev This function can only be called by the owner of the contract.
     * @dev reverts with `ZeroAddressForbidden` if the provided recipient address is zero.
     * @dev reverts with `InvalidFee` if the provided percentage is above the treshold.
     * @param _recipient The address that will receive the percentage fee.
     * @param _percentage The percentage of the fee to be added, eg. 24 == 2.4%, maximum 255 == 25.5%.
     */
    function addPercentageFee(
        address _recipient,
        uint8 _percentage
    ) external isValidAddress(_recipient) onlyOwner {
        percentageFees.push(PercentageFee(_recipient, _percentage));
        emit PercentageFeeAdded(_recipient, _percentage);
    }

    /**
     * @notice Removes a percentage fee from the list of percentage fees.
     * @dev emits a `PercentageFeeRemoved` event when the fee is successfully removed.
     * @dev This function can only be called by the owner of the contract.
     * It replaces the fee at the specified index with the last fee in the list
     * and then removes the last fee, effectively deleting the fee at the specified index.
     * @param _index The index of the percentage fee to be removed.
     */
    function removePercentageFee(uint256 _index) external onlyOwner {
        percentageFees[_index] = percentageFees[percentageFees.length - 1];
        percentageFees.pop();
        emit PercentageFeeRemoved(
            percentageFees[_index].recipient,
            percentageFees[_index].percentage
        );
    }

    /**
     * @notice Updates the swap expiry time.
     * @dev emits a `SwapExpiryUpdated` event when the swap expiry time is successfully updated.
     * @dev This function can only be called by the owner of the contract.
     * @param _swapExpiry The new expiry time for the swap.
     */
    function updateSwapExpiry(uint32 _swapExpiry) external onlyOwner {
        swapExpiry = _swapExpiry;
        emit SwapExpiryUpdated(_swapExpiry);
    }
}
