# Mantle Sepolia Testnet - Foundry Project

Foundry-based smart contract development environment configured for Mantle Sepolia testnet.

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Network Information

- **Network**: Mantle Sepolia Testnet
- **Chain ID**: 5003
- **RPC URL**: https://rpc.sepolia.mantle.xyz
- **Explorer**: https://sepolia.mantlescan.xyz/
- **Faucet**: https://faucet.sepolia.mantle.xyz/
- **Bridge**: https://app.mantle.xyz/bridge?network=sepolia
- **Wrapped MNT**: 0x19f5557E23e9914A18239990f6C70D68FDF0deD5

## Setup

1. Install dependencies:
```shell
forge install
```

2. Copy `.env.example` to `.env` and configure:
```shell
cp .env.example .env
```

3. Edit `.env` with your private key:
```
PRIVATE_KEY=your_private_key_without_0x_prefix
MANTLESCAN_API_KEY=your_api_key_optional
```

## Usage

### Build

```shell
forge build
```

### Test

```shell
forge test
```

Run tests with gas report:
```shell
forge test --gas-report
```

### Format

```shell
forge fmt
```

### Gas Snapshots

```shell
forge snapshot
```

### Deploy

Deploy to Mantle Sepolia:
```shell
source .env
forge script script/Counter.s.sol:CounterScript --rpc-url mantle_sepolia --broadcast --verify --legacy
```

**Note**: Use `--legacy` flag for transactions on Mantle (EIP-1559 not fully supported)

### Verify Contract

If verification fails during deployment, verify manually:
```shell
forge verify-contract <CONTRACT_ADDRESS> src/Counter.sol:Counter --chain 5003 --watch
```

### Cast

Call view function:
```shell
cast call <CONTRACT_ADDRESS> "number()" --rpc-url mantle_sepolia
```

Send transaction:
```shell
cast send <CONTRACT_ADDRESS> "increment()" --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

Check balance:
```shell
cast balance <YOUR_ADDRESS> --rpc-url mantle_sepolia
```

### Help

```shell
forge --help
anvil --help
cast --help
```

## Documentation

https://book.getfoundry.sh/

## Notes

- Recommended Solidity version: 0.8.23 or below
- Get testnet MNT from faucet before deploying
- Always use `--legacy` flag when sending transactions to Mantle
