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
airdrop-contracts$ forge install
```

2. Build the contracts:

```sh
airdrop-contracts$ forge build
```

2. Run the tests

```sh
airdrop-contracts$ forge test
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

1. Generate a `beneficiaries.json`. See `beneficiaries.example.json` for a working example.

```json
{
  "beneficiary": "0x18EdaEc676341D63d7087D0d999cF1f1a56d565A", // address that can claim + delegate tokens
  "amount": 10, // amount of tokens the beneficiary will vest (eth units)
  "startTime": 1689554843, // the starting timestamp in seconds of the vesting
  "cliffDuration": 300, // the duration of the cliff in seconds
  "duration": 600 // the duration of the unlock/vesting period
}
```

2. Copy the `.env.example`, and fill in with the appropriate values (only networks you are deploying to must be configured):

```sh
airdrop-contracts$ cp .env.example .env
```

The deployer `PRIVATE_KEY` should hold funds on all the networks you plan on deploying to.

3. Source the environment:

```sh
airdrop-contracts$ source .env
```

4. Run the deployment script with the `broadcast` and `verify` flags for the appropriate network:

```sh
airdrop-contracts$ forge script script/TimelockedDelegator.s.sol:TimelockedDelegatorDeploy --verify -vvv --rpc-url $GOERLI_RPC_URL --sender $DEPLOYER --broadcast
```

5. Verify the correct information is added into the [`timelocks.json`](./timelocks.json) file.
