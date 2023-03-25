import FungibleToken from "FungibleToken"
import SwapFactory from "SwapFactory"
import SwapInterfaces from "SwapInterfaces"
import SwapConfig from "SwapConfig"

transaction(
    token0Key: String,
    token1Key: String,
    token0InDesired: UFix64,
    token1InDesired: UFix64,
    token0InMin: UFix64,
    token1InMin: UFix64,
    token0VaultPath: StoragePath,
    token1VaultPath: StoragePath,
) {
    prepare(lp: AuthAccount) {
        let pairAddr = SwapFactory.getPairAddress(token0Key: token0Key, token1Key: token1Key)
            ?? panic("AddLiquidity: nonexistent pair ".concat(token0Key).concat(" <-> ").concat(token1Key).concat(", create pair first"))
        let pairPublicRef = getAccount(pairAddr).getCapability<&{SwapInterfaces.PairPublic}>(SwapConfig.PairPublicPath).borrow()!
        /*
            pairInfo = [
                SwapPair.token0Key,
                SwapPair.token1Key,
                SwapPair.token0Vault.balance,
                SwapPair.token1Vault.balance,
                SwapPair.account.address,
                SwapPair.totalSupply
            ]
        */
        let pairInfo = pairPublicRef.getPairInfo()
        var token0In = 0.0
        var token1In = 0.0
        var token0Reserve = 0.0
        var token1Reserve = 0.0
        if token0Key == (pairInfo[0] as! String) {
            token0Reserve = (pairInfo[2] as! UFix64)
            token1Reserve = (pairInfo[3] as! UFix64)
        } else {
            token0Reserve = (pairInfo[3] as! UFix64)
            token1Reserve = (pairInfo[2] as! UFix64)
        }
        if token0Reserve == 0.0 && token1Reserve == 0.0 {
            token0In = token0InDesired
            token1In = token1InDesired
        } else {
            var amount1Optimal = SwapConfig.quote(amountA: token0InDesired, reserveA: token0Reserve, reserveB: token1Reserve)
            if (amount1Optimal <= token1InDesired) {
                assert(amount1Optimal >= token1InMin, message: "SLIPPAGE_OFFSET_TOO_LARGE expect min".concat(token1InMin.toString()).concat(" got ").concat(amount1Optimal.toString()))
                token0In = token0InDesired
                token1In = amount1Optimal
            } else {
                var amount0Optimal = SwapConfig.quote(amountA: token1InDesired, reserveA: token1Reserve, reserveB: token0Reserve)
                assert(amount0Optimal <= token0InDesired)
                assert(amount0Optimal >= token0InMin, message: "SLIPPAGE_OFFSET_TOO_LARGE expect min".concat(token0InMin.toString()).concat(" got ").concat(amount0Optimal.toString()))
                token0In = amount0Optimal
                token1In = token1InDesired
            }
        }
        
        let token0Vault <- lp.borrow<&FungibleToken.Vault>(from: token0VaultPath)!.withdraw(amount: token0In)
        let token1Vault <- lp.borrow<&FungibleToken.Vault>(from: token1VaultPath)!.withdraw(amount: token1In)
        /// SwapPair.addLiquidity()
        let lpTokenVault <- pairPublicRef.addLiquidity(
            tokenAVault: <- token0Vault,
            tokenBVault: <- token1Vault
        )
        
        let lpTokenCollectionStoragePath = SwapConfig.LpTokenCollectionStoragePath
        let lpTokenCollectionPublicPath = SwapConfig.LpTokenCollectionPublicPath
        var lpTokenCollectionRef = lp.borrow<&SwapFactory.LpTokenCollection>(from: lpTokenCollectionStoragePath)
        /// Initialize LpTokenCollection resource for lp if necessary.
        if lpTokenCollectionRef == nil {
            destroy <- lp.load<@AnyResource>(from: lpTokenCollectionStoragePath)
            lp.save(<-SwapFactory.createEmptyLpTokenCollection(), to: lpTokenCollectionStoragePath)
            lp.link<&{SwapInterfaces.LpTokenCollectionPublic}>(lpTokenCollectionPublicPath, target: lpTokenCollectionStoragePath)
            lpTokenCollectionRef = lp.borrow<&SwapFactory.LpTokenCollection>(from: lpTokenCollectionStoragePath)
        }
        lpTokenCollectionRef!.deposit(pairAddr: pairAddr, lpTokenVault: <- lpTokenVault)
    }
}