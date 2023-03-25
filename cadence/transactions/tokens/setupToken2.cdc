import FungibleToken from "FungibleToken"
import BasicToken2 from "BasicToken2"

transaction {

    prepare(signer: AuthAccount) {

        if signer.borrow<&BasicToken2.Vault>(from: BasicToken2.TokenStoragePath) == nil {
            signer.save(<-BasicToken2.createEmptyVault(), to: BasicToken2.TokenStoragePath)

            signer.link<&BasicToken2.Vault{FungibleToken.Receiver}>(
                BasicToken2.TokenPublicReceiverPath,
                target: BasicToken2.TokenStoragePath
            )

            signer.link<&BasicToken2.Vault{FungibleToken.Balance}>(
                BasicToken2.TokenPublicReceiverPath,
                target: BasicToken2.TokenPublicBalancePath
            )
        }
    }
}
