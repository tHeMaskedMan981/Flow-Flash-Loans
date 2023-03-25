import FungibleToken from "FungibleToken"
import SwapFactory from "SwapFactory"
import SwapInterfaces from "SwapInterfaces"
import SwapConfig from "SwapConfig"

transaction(
    token0Key: String,
    token1Key: String,
    flashLoanTokenKey:String,
    flashLoanReceiver:Address,
    amount:UFix64
) {
    prepare(signer: AuthAccount) {
        let pairAddr = SwapFactory.getPairAddress(token0Key: token0Key, token1Key: token1Key)
            ?? panic("AddLiquidity: nonexistent pair ".concat(token0Key).concat(" <-> ").concat(token1Key).concat(", create pair first"))
        let pairPublicRef = getAccount(pairAddr).getCapability<&{SwapInterfaces.PairPublic}>(SwapConfig.PairPublicPath).borrow()!

        pairPublicRef.flashLoan(
            flashLoanReceiver:flashLoanReceiver,
            tokenKey: flashLoanTokenKey,
            amount: amount
        )
    }
}