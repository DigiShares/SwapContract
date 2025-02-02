# SwapContract

**The swap contract facilitates peer to peer trading of ERC20 based tokens between two wallet addresses.**
It utilizes the [PERMIT2](https://github.com/Uniswap/permit2) to make token approvals easier for the users.
The contract also uses [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) namely IERC20, SafeERC20, Multicall and Ownable.

## Functionality

The main functionality consists 3 functions:

- **open**: Opens the swap and deposits ERC20 tokens to the swap contract (can be called by any wallet).
- **close**: Closes an already open swap and sends the Opening tokens to the Closing wallet, closing tokens to the opening wallet and fee recipients (can be called only by the Closing wallet).
- **expire**: Expires the swap if the swap was not closed on time based on expiry. Sends the opening tokens back to the Opening wallet (can be called by any wallet).

There is also a number of utility functions:

#### available for all wallets

- **getSwapData**: Retrieval of the swap data for a given wallet and swapId
- **singlePermit**: Approval of a token using permit2
- **batchPermit**: Approval of multiple tokens using permit2

#### only owner of the swapContract

- **updateOpeningToken**: Whitelisting/Blacklisting of Opening tokens
- **updateClosingToken**: Whitelisting/Blacklisting of Closing tokens
- **updatePercentageFee**: Updating of a specific PercentageFee
- **addPercentageFee**: Adding a PercentageFee
- **removePercentageFee**: Removing a PercentageFee
- **updateSwapExpiry**: Updating the swapExpiry threshold

**The contract inherits openzeppelin Multicall:**
- This aims to improve user friendliness by being able to bundle multiple function calls into one transactions 
- This way users can **Open**, **Close** and **Expire** multiple swaps all at once in one transaction
- The usual scenario will be a bundle of function calls including the permitSingle/permitBatch + open/close/expire of swaps


## Deployment and Setup

- The smart contract needs to be deployed with the PERMIT2 address and swapExpiry (overall expiry is calculated block.timestamp + swapExpiry).
- After deployment openingTokens and closingTokens will need to be added to their respective mappings for swapping to be functional. Opening tokens represent mostly ERC20 based security token. Closing tokens represent mostly stablecoins. Optionally also percentageFees array can be populated with recipients and percentage in the form of the PercentageFee struct.

## Flow

### Open

- Opening wallet initiates the swap by first calling the **singlePermit/batchPermit** functions where the approval of token spending of the OpeningToken is set. Once approved the wallet provides necessary data for calling the **open** function. Opening tokens will get transferred from the OpeningWallet to the SwapContract. This swap is then in the **OPEN** state until either the Closing wallet **closes** the swap or the swap **expires**.

### Close

- Closing wallet closes the swap by first calling the **singlePermit/batchPermit** functions where the approval of token spending of the ClosingToken is set. Once approved the wallet provides necessary data for calling the **close** function, it needs to happen before the **expiry** of the swap state reaches the current time. This action finalizes the swap and sets it to the **CLOSED** state. The Opening tokens get transferred to the Closing wallet. Before the Closing tokens get transfered to the Opening wallet a fee is deducted and sent to the Fee Recipient (if the fee recipient is set).

### Expire

- If the Closing wallet does not finalize the swap before the swap expiry time is reached, the swap cannot be closed anymore. If this scenario occurs the Opening Wallet can withdraw their tokens by calling the **expire** function. Opening tokens will get transferred back to the Opening wallet and the swap state is set to **EXPIRED**

## Fee distribution and calculation

- The fee distribution happens during the closing of the swap. The fees are paid out only in Closing tokens. The fee is distributed based on the percentageFees array. The array is populated with the PercentageFee struct which consist of the recipient and percentage. If the array is empty there are no fees distributed. To achieve more granularity the percentage value is written up to four-digits eg. 24 == 2.4%, 100 == 10% and 1000 === 100%.

- The fee duty is **equally split** between the Opening Wallet and Closing wallet. This enables the Opening wallet to only have Opening tokens in their wallet and no need of Closing tokens, since the fee gets deducted from the amount of Closing tokens they receive.

### **Example:**

- There is only one fee recipient and the fee is 2%. Meaning that Opening wallet needs to pay 1% fee and Closing wallet needs to pay 1% fee.
1. Swap is opened where Closing token amount is 100.
2. Swap gets closed
3. Closing wallet transfers 101 Closing tokens (100 + 1%)
4. fee recipient receives 2 Closing tokens (2% of 100)
5. Opening wallet receives 99 Closing tokens (100 - 1%)
