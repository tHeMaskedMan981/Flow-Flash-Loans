import FungibleToken from "FungibleToken"
import SwapFactory from "SwapFactory"
import SwapInterfaces from "SwapInterfaces"
import SwapConfig from "SwapConfig"

transaction(
    lpTokenAmount: UFix64,
    token0Key: String,
    token1Key: String,
    token0VaultPath: StoragePath,
    token1VaultPath: StoragePath
) {
    prepare(lp: AuthAccount) {
        let pairAddr = SwapFactory.getPairAddress(token0Key: token0Key, token1Key: token1Key)
            ?? panic("RemoveLiquidity: nonexistent pair ".concat(token0Key).concat(" <-> ").concat(token1Key).concat(", create pair first"))
        let lpTokenCollectionRef = lp.borrow<&SwapFactory.LpTokenCollection>(from: SwapConfig.LpTokenCollectionStoragePath)
            ?? panic("RemoveLiquidity: cannot borrow reference to LpTokenCollection")

        let lpTokenRemove <- lpTokenCollectionRef.withdraw(pairAddr: pairAddr, amount: lpTokenAmount)
        let tokens <- getAccount(pairAddr).getCapability<&{SwapInterfaces.PairPublic}>(SwapConfig.PairPublicPath).borrow()!.removeLiquidity(lpTokenVault: <-lpTokenRemove)
        let token0Vault <- tokens[0].withdraw(amount: tokens[0].balance)
        let token1Vault <- tokens[1].withdraw(amount: tokens[1].balance)
        destroy tokens

        let lpToken0Vault = lp.borrow<&FungibleToken.Vault>(from: token0VaultPath)
            ?? panic("RemoveLiquidity: cannot borrow reference to token0Vault from lp account")
        let lpToken1Vault = lp.borrow<&FungibleToken.Vault>(from: token1VaultPath)
            ?? panic("RemoveLiquidity: cannot borrow reference to token1Vault from lp account")
        if token0Vault.isInstance(lpToken0Vault.getType()) {
            lpToken0Vault.deposit(from: <-token0Vault)
            lpToken1Vault.deposit(from: <-token1Vault)
        } else {
            lpToken0Vault.deposit(from: <-token1Vault)
            lpToken1Vault.deposit(from: <-token0Vault)
        }
    }
}