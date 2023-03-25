# 👋 Welcome to Flow Flash Loans!

Flash Loans provide a very easy way to gain access to capital for a single transaction. This extra access to capital can be used for arbitrage opportunities, liqudations, etc. Currently, there is no easy way to get Flash Loans in Flow. We have come up with an interface and specification that can be used by DEXs already present on Flow to provide secure Flash Loans to their users, which will end up with them earning extra fees above the swap fees. 

We also present an example contract that can be used by developers in Flow ecosystem to easily get Flash Loans for their applications. 

For this hackathon, we have demonstrated how **IncrementFi** can extend their `SwapPair.cdc` contracts to support Flash Loans. 

This approach can easily be extended to provide flash Swaps as well.

## 🔨 Getting started

### SwapInterface.cdc
First, we need to specify an interface for receiving Flash Loans. We have defined it in the `SwapInterfaces.cdc` contract - 
```cadence
pub resource interface FlashLoanReceiver {
        pub fun onFlashLoan(flashLoanVault: @FungibleToken.Vault, tokenKey:String, fees:UFix64): @FungibleToken.Vault
    }

```

Here, `flashLoanVault` is the vault received from a DEX.

 `tokenKey` represents the token which was requested to borrow. 

 `fees` is the amount of `tokenKey` token that the DEX expects as fees when the vault is returned. In the same transaction, the flash loan user should return a vault of token `tokenKey` with an amount equal to `flashLoanVault.balance + fees`. 

 If the user is not able to return the principal amount + fees in this function call, the transaction will revert and all state changes will be discarded. This ensures that the funds are received by the DEX, and there is no reason to worry about the funds lent out for flash loans. 


### SwapPair.cdc

This is the main contract with the specifications for giving out Flash Loans. We need 2 function for implementing this - 
```cadence
pub fun getFlashLoanFees(amount:UFix64) :UFix64 {
        return amount *self.flashLoanFeesPercentage/10000.0;
    }
```
This function specifies how much fees is expected from the user for this amount of flash loan. It can be generalized to even return different fees for different tokens. 

Here is the main `flashLoan` function - 
```
pub fun flashLoan(flashLoanReceiver:Address, tokenKey:String, amount:UFix64) {

        pre {
            tokenKey==self.token0Key || tokenKey==self.token1Key:
                SwapError.ErrorEncode(
                    msg: "SwapPair: invalid token for flash loan",
                    err: SwapError.ErrorCode.INVALID_PARAMETERS
                )
            self.lock == false: SwapError.ErrorEncode(msg: "SwapPair: Reentrant", err: SwapError.ErrorCode.REENTRANT)
        }
        post {
            self.lock == false: "SwapPair: unlock"
        }
        // we need to lock during flash loan to avoid any swap via reentrancy
        self.lock = true
        var flashLoanVault:@FungibleToken.Vault? <- nil;

        // Extract the required amount in flashLoanVault
        if (tokenKey==self.token1Key) {
            assert(amount<= self.token1Vault.balance!, message:
                SwapError.ErrorEncode(
                    msg: "SwapPair: INSUFFICIENT_AMOUNT",
                    err: SwapError.ErrorCode.INVALID_PARAMETERS
                )
            )

            flashLoanVault <-! self.token1Vault.withdraw(amount: amount)
        }

        if (tokenKey==self.token0Key) {
            assert(amount<= self.token0Vault.balance!, message:
                SwapError.ErrorEncode(
                    msg: "SwapPair: INSUFFICIENT_AMOUNT",
                    err: SwapError.ErrorCode.INVALID_PARAMETERS
                )
            )
            flashLoanVault <-! self.token0Vault.withdraw(amount: amount)
        }

        // Call the resource's onFlashLoan function to provide flash Laon
        let publicAccount = getAccount(flashLoanReceiver);
        let flashLoanReceiverResource  = publicAccount.getCapability(/public/flashLoanReceiver).borrow<&{SwapInterfaces.FlashLoanReceiver}>();

        let fees = self.getFlashLoanFees(amount:amount);
        // perform flash loan
        let returnedVault <- flashLoanReceiverResource!.onFlashLoan(flashLoanVault:<-flashLoanVault!, tokenKey:tokenKey, fees:fees);
        
        // check if returned vault is of correct type and amount
        assert(returnedVault.isInstance(self.token0VaultType) || returnedVault.isInstance(self.token1VaultType), message:
            SwapError.ErrorEncode(
                msg: "SwapPair: Wrong token vault",
                err: SwapError.ErrorCode.INVALID_PARAMETERS
            )
        )

        assert(returnedVault.balance>= amount+fees, message:
            SwapError.ErrorEncode(
                msg: "SwapPair: INSUFFICIENT_AMOUNT",
                err: SwapError.ErrorCode.INVALID_PARAMETERS
            )
        )

        // If everything succeed, emit an event with details
        emit FlashLoanCompleted(
            flashLoanReceiver:flashLoanReceiver, 
            tokenKey:tokenKey, 
            sentAmount:amount, 
            receivedAmount:returnedVault.balance
        )

        if (returnedVault.isInstance(self.token0VaultType)) {
            self.token0Vault.deposit(from:<-returnedVault!);
        }
        else if (returnedVault.isInstance(self.token1VaultType)) {
            self.token1Vault.deposit(from:<-returnedVault!);
        } else {
            destroy returnedVault;
            panic("Not correct type vault returned")
        }


        self.lock = false

    }
```

We are performing necessary checks for balances and vault types. Also, we need to enable lock before providing the flash loan to avoid any swaps as reentrancy. 

### Arbitrage Contract

the last piece is the Arbitrage Contract, which specifies the interface for getting flash loan - 
```cadence
import FungibleToken from "FungibleToken"
import SwapInterfaces from "SwapInterfaces"

pub contract Arbitrage {

    pub event ReceivedFlashLoan(tokenKey:String, amount:UFix64);
    
    pub resource FlashLoanReceiver:SwapInterfaces.FlashLoanReceiver {
        pub fun onFlashLoan(flashLoanVault:@FungibleToken.Vault, tokenKey:String, fees:UFix64):@FungibleToken.Vault {

            emit ReceivedFlashLoan(tokenKey:tokenKey, amount:flashLoanVault.balance);
            // Add arbitrage, liquidation, collateral swap logic here


            // End of user's logic. send the final vault, with balance equal to inital vault balance plus fees. Rest can be stored
            // in user's account as profit
            return <-flashLoanVault
        }
    }

    init() {
        destroy <-self.account.load<@AnyResource>(from: /storage/flashLoanReceiver);
        self.account.save(<-create FlashLoanReceiver(), to: /storage/flashLoanReceiver);
        self.account.link<&{SwapInterfaces.FlashLoanReceiver}>(/public/flashLoanReceiver, target: /storage/flashLoanReceiver);              

    }
} 
```

In this way, DEXs can easily provide flash loans, can users can take advantage of this new functionality to build further amazing composable DEFI products! 


***Note 1***: As this is more of a dev tool than a end user's product, we have not created a frontend. Instead, we have written tests to show that our implementation works. Go to cadence/tests/, run `npm i` and then `npm test` to check out the tests. 

***Note 2***: We wanted to do this by just calling a function of a contract, but were not able to figure out how to call functions of a dynamic imported contract. Therefore we used public resource capability to achieve this. Having the ability to call a contract function will simplify the process. 