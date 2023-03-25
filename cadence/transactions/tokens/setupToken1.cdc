import FungibleToken from "FungibleToken"
import BasicToken1 from "BasicToken1"

transaction {

    prepare(signer: AuthAccount) {

        if signer.borrow<&BasicToken1.Vault>(from: BasicToken1.TokenStoragePath) == nil {
            signer.save(<-BasicToken1.createEmptyVault(), to: BasicToken1.TokenStoragePath)

            signer.link<&BasicToken1.Vault{FungibleToken.Receiver}>(
                BasicToken1.TokenPublicReceiverPath,
                target: BasicToken1.TokenStoragePath
            )

            signer.link<&BasicToken1.Vault{FungibleToken.Balance}>(
                BasicToken1.TokenPublicReceiverPath,
                target: BasicToken1.TokenPublicBalancePath
            )
        }
    }
}
