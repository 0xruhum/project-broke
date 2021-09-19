I initially thought about splitting the whole thing up into two contracts.

One is the actual agreement which only the seller or buyer can access.
They can see all the agreement details and retrieve the NFT using it.

The second contract is used to initialize agreements. Now, from a security standpoint
that should be a good idea. The contract has to hold the NFT of the seller.
Having each agreement only hold a single one should decrease the risk of a hacker
grabbing all the NFTs at once. From effiecency standpoint it sucks tho.

The better solution, IMO, is to have everything in a single contract.
Instead of having an `Agreement` contract, have an `Agreement` struct. Inside
that struct, store the immutable addresses of both the seller and buyer. Only allow
those two addresses to retrieve any token.

Should make the overall size smaller and allow for more efficient code.
