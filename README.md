# airdrop-contracts

Holds the contracts to support the Connext airdrop.

## Contracts

### Timelocks

These contracts support self-custody of locked or vesting tokens. They are derived from the [Fei Protocol](https://github.com/fei-protocol) implementation, with slight modifications to accomodate the [potential future removal of `selfdestruct`](https://eips.ethereum.org/EIPS/eip-4758) and naming clarity.

The contracts support the following features:

- Clawback of funds by an admin
- Linear token vesting by the second
- Delegation of the full-balance of
- Subdelegation of locked tokens
- 2-phase updating of the beneficiary address

## Development

### Prerequisites

This repository requires:

1. [`forge`](https://book.getfoundry.sh/getting-started/installation)

### Local Development

1. Install the dependencies:

```sh
airdrop-contracts$ yarn install
```

2. Build the contracts:

```sh
airdrop-contracts$ yarn build
```

2. Run the tests

```sh
airdrop-contracts$ yarn test
```

## Deployments

### Supported Networks

By default, the environment is configured to support the following chains:

_Testnets_

- goerli
- optimism-goerli
- arbitrum-goerli
- mumbai

_Mainnets_

- mainnet
- bnb
- optimism
- arbitrum
- gnosis
- polygon

To add a new network, submit a PR with the following:

1. An update to the `.env.example` to reflect the RPC and verification API key.
2. An update to `RpcLookup.sol` to reflect the RPC <> chain mapping.
3. An update to `foundry.toml` to have the correct network values in the `[rpc_endpoints]` and `[etherscan]` sections.

### Timelocks

The script [`TimelockedDelegator.s.sol`](./script/TimelockedDelegator.s.sol) governs the deployments of the timelock contracts. This ingests beneficiary information via a `json` file, deployes the contracts via `CREATE2`, writes the deployed records to `timelocks.json`, and verifies the contracts.

To deploy the timelocks:

1. Generate a `beneficiaries.csv`. See `beneficiaries.example.csv` for a working example. The headers should be:

- `beneficiary`: Address that can claim funds
- `amount`: Amount to lock (wei units)
- `startTime`: The starting timestamp in seconds of the vesting
- `cliffDuration`: The duration of the cliff in seconds
- `duration`: The duration of the unlock/vesting period in seconds

**NOTE:** On testnets, store the beneficiaries in `beneficiaries-testnet.csv`

2. Copy the `.env.example`, and fill in with the appropriate values (only networks you are deploying to must be configured):

```sh
airdrop-contracts$ cp .env.example .env
```

The deployer `PRIVATE_KEY` should hold funds on all the networks you plan on deploying to.

3. Source the environment:

```sh
airdrop-contracts$ source .env
```

4. Run the deployment script for the appropriate network:

```sh
airdrop-contracts$ ETHERSCAN_API_KEY="<ETHERSCAN_API_KEY>" yarn hardhat deploy --network "<NETWORK>"
```

**NOTE:** To deploy the factory, but only generate the transactions needed to deploy and fund the transactions, add the following in your `.env`:

```sh
SUBMIT=false
```

This will write all of the transactions to a SAFE transaction-builder compliant `json` file, which can be uploaded to deploy timelocks directly from the SAFE application. These transactions will be written to a timestamped `transaction.json` file.

5. Verify the correct information is exported to `deployments`. If using a SAFE to deploy, only the factory should be saved.
