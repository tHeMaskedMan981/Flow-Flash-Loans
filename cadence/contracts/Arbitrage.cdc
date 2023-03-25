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