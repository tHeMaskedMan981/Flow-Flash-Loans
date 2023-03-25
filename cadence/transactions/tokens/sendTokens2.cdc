import FungibleToken from "FungibleToken"
import BasicToken2 from "BasicToken2"

transaction(amount: UFix64, to: Address) {

    let sentVault: @FungibleToken.Vault

    prepare(signer: AuthAccount) {
        let vaultRef = signer.borrow<&BasicToken2.Vault>(from: BasicToken2.TokenStoragePath)
			?? panic("Could not borrow reference to the owner's Vault!")
        self.sentVault <- vaultRef.withdraw(amount: amount)
    }

    execute {

        let recipient = getAccount(to)
        let receiverRef = recipient.getCapability(BasicToken2.TokenPublicReceiverPath).borrow<&{FungibleToken.Receiver}>()
			?? panic("Could not borrow receiver reference to the recipient's Vault")
        receiverRef.deposit(from: <-self.sentVault)
    }
}
