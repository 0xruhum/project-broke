# <h1 align="center"> Project Broke </h1>

Broke is a contract that allows buying NFTs from a seller by paying off the
price over a set period of time instead of upfront using Superfluid streams.

To ensure economic incentive for the buyer to not tinker with the flow
in the middle of the agreement or do any other stupid shit they have to send
a deposit when starting an agreement. If the agreement is successful the buyer
is able to withdraw their deposit from the contract. Else, the seller is rewarded
the deposit.

The basic scenario is:

1. Seller aproves `Broke` to retrieve the token from their wallet.
2. Seller creates an agreement using `Broke` and receives the ID of the agreement.
3. Seller shares the ID with potential buyers.
4. Buyer accepts agreement by paying the deposit set by the seller. The contract locks
the seller's token and sets a 1 hour time limit for the buyer to start streaming the funds.
5. Buyer creates a Superfluid stream to the `Broke` contract. `Broke` contract uses the 
Superfluid hooks to start a stream with the same parameters to the Seller.
6. After the token was paid off buyer ends Superfluid stream. `Broke` coontract uses the hooks to
also stop the stream to the seller.
7. Buyer withdraws NFT and deposit from the contract.

## API

The project consists of a single contract named `Broke`.
It is used to create and accept agreements as well as retrieve tokens/funds.

### Create an Agreement 

When a user wants to sell their NFT token through the Broke contract, they
have to first grant the contract permission to transfer the token from their wallet.
After that, they call the `createAgreement()` function with the following parameters:

| Type | Description |
| ---- | ----------- |
| address | address of the contract the NFT was orginally minted from |
| uint256 | the ID of the NFT you want to sell |
| address | address of the Superfluid Token you accept as payment. See https://docs.superfluid.finance/superfluid/networks/networks |
| uint96 | the total price you want to sell the token for in wei |
| uint96 | the length of the agreement in seconds, e.g. 86400 = 1 day |
| uint256 | the deposit in wei you expect from the buyer |

The price divided by the length determines the flow rate of the Superfluid
stream the buyer has to start to accept the agreement.

### Accept an Agreement

To accept the agreement you call the `acceptAgreement(uint)` function where you pass
the agreement ID and send the deposit.

After that, the contract will lock up the seller's token and set an one hour time limit
for you to start streaming the funds to the `Broke` contract.

If you don't do it within the timelimt, the seller is able to get back their token
and is rewarded your deposit.

#### Starting the Agreement

To start the agreement you have to start a Superfluid stream to the `Broke` contract.
The stream has to have the flowrate specified in the agreement. You also have to pass the agreement
ID in the userData section of the stream context. The contract will react to you creating
the stream through a hook and start a stream with the same values to the seller.

After that, the agreement officially started.

Broke expects all the values to be in WEI while Superfluid seems to use Ether.
Here's an example on how to figure out the correct flow rate:

```
# specified by seller
price = 1000 WEI
length = 300 # 5 minutes
flowrate = 1000 / 1e18 / 300 # per second

# When creating the flow on Superfluid dashboard, you have to multiple the flowrate
# above with unit you select on Superfluid, e.g. hour, day, month
# if you select hour for example it's:
superfluid = flowrate * 60**2
```

After the stream was started you're supposed to not modify it 
until the endDate is reached. Else, the seller is able to end the agreement
take their token as well as your deposit.

### Retrieving the Token

Call `retrieveToken(uint agreementID)` to withdraw the NFT from the contract.

Seller and buyer have different scenarios in which they are elible to withdraw.

If they withdrawed the NFT, they are also eligble to withdraw the deposit associated
with the agreement. Simply call `withdraw()` for that.

#### Buyer

As a buyer you're eligble to retrieve the token if the following condition is true:

```
block.timestamp > blockAtWhichAgreementWasAccepted.timestamp + agreement.length
```

#### Seller

As a seller you're only able to withdraw the token after an agreement was created
if one of the following scenarios occur:

- buyer runs out of funds in the middle of the agreement
- buyer ends the stream early
- buyer modifies the flowrate while the agreement is still active

## Dev 

To get started run the following commands:

```
make
make install
```

To build the contracts run:

```
make build
```

The test suite needs to access the ropsten network. For that, we have to specify
RPC url. We use alchemy for which you have to provide an API key in the env file.

The tests, also need an account with SuperDAI. In the testsuite that account is named `alice`.
Alice's address: 0xEFc56627233b02eA95bAE7e19F648d7DcD5Bb132.

If for whatever reason the address of Alice changes, simply log the address in the tests
and send the DAI to that address :).

After that run:

```
make test
```

## Deploying

Contracts can be deployed via the `make deploy` command. Addresses are automatically
written in a name-address json file stored under `out/addresses.json`.

We recommend testing your deployments and provide an example under [`scripts/test-deploy.sh`](./scripts/test-deploy.sh)
which will launch a local testnet, deploy the contracts, and do some sanity checks.

Environment variables under the `.env` file are automatically loaded (see [`.env.example`](./.env.example)).
Be careful of the [precedence in which env vars are read](https://github.com/dapphub/dapptools/tree/2cf441052489625f8635bc69eb4842f0124f08e4/src/dapp#precedence).

We assume `ETH_FROM` is an address you own and is part of your keystore.
If not, use `ethsign import` to import your private key.

See the [`Makefile`](./Makefile#25) for more context on how this works under the hood

We use Alchemy as a remote node provider for the Mainnet & Rinkeby network deployments.
You must have set your API key as the `ALCHEMY_API_KEY` enviroment variable in order to
deploy to these networks

### Mainnet

```
ETH_FROM=0x3538b6eF447f244268BCb2A0E1796fEE7c45002D make deploy-mainnet
```

### Rinkeby

```
ETH_FROM=0x3538b6eF447f244268BCb2A0E1796fEE7c45002D make deploy-rinkeby
```

### Custom Network

```
ETH_RPC_URL=<your network> make deploy
```

### Local Testnet

```
# on one terminal
dapp testnet
# get the printed account address from the testnet, and set it as ETH_FROM. Then:
make deploy
```

### Verifying

Set the Etherscan API key env variable and run
`make network_name=<mainnet|ropsten|...> contract_address=<address> verify`

## Installing the toolkit

If you do not have DappTools already installed, you'll need to run the below
commands

### Install Nix

```sh
# User must be in sudoers
curl -L https://nixos.org/nix/install | sh

# Run this or login again to use Nix
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

### Install DappTools

```sh
curl https://dapp.tools/install | sh
```

## DappTools Resources

* [DappTools](https://dapp.tools)
    * [Hevm Docs](https://github.com/dapphub/dapptools/blob/master/src/hevm/README.md)
    * [Dapp Docs](https://github.com/dapphub/dapptools/tree/master/src/dapp/README.md)
    * [Seth Docs](https://github.com/dapphub/dapptools/tree/master/src/seth/README.md)
* [DappTools Overview](https://www.youtube.com/watch?v=lPinWgaNceM)
* [Awesome-DappTools](https://github.com/rajivpo/awesome-dapptools)
