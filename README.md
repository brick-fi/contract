# BrickFi - RWA Property Tokenization

Foundry-based smart contract for tokenizing real estate rental income on Mantle Sepolia testnet.

## Project Overview

BrickFi PropertyToken is an ERC-20 based token that represents rental income rights (NOT ownership) from real estate properties. This allows fractional investment in real estate cashflow with automated revenue distribution.

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

## PropertyToken Contract

### Features

- **ERC-20 Standard**: Fully compliant ERC-20 token for rental income rights
- **KYC Gate**: Terms acceptance requirement for compliance
- **Investment Minting**: Automatic token minting based on investment amount (1 ETH = 1000 tokens)
- **Revenue Distribution**: Admin-triggered distribution with proportional claim mechanism
- **Transfer Restrictions**: KYC-gated transfers to ensure compliance
- **Pausable**: Emergency pause functionality for admin
- **Access Control**: Role-based permissions (ADMIN_ROLE, DISTRIBUTOR_ROLE)

### Contract Architecture

```
PropertyToken.sol
├── Property Metadata (name, location, value, expected income)
├── KYC Gate (acceptTerms)
├── Investment (invest)
├── Distribution (distributeRevenue, claimRevenue)
├── Transfer Restrictions (_update override)
└── Admin Functions (pause, unpause, updateMetadata)
```

### Key Functions

**User Functions:**
- `acceptTerms()`: Accept terms and conditions for compliance
- `invest()`: Invest ETH and receive property tokens
- `claimRevenue(distributionId)`: Claim share of distributed revenue
- `getPendingRevenue(user, distributionId)`: Check pending revenue

**Admin Functions:**
- `distributeRevenue(amount, description)`: Trigger revenue distribution
- `pause()` / `unpause()`: Emergency controls
- `updatePropertyMetadata(metadataURI)`: Update property 3D/2D visuals
- `setPropertyActive(bool)`: Enable/disable property investment

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

### Deploy PropertyToken

Deploy to Mantle Sepolia:
```shell
source .env
forge script script/PropertyToken.s.sol:PropertyTokenScript --rpc-url mantle_sepolia --broadcast --verify --legacy
```

**Note**: Use `--legacy` flag for transactions on Mantle (EIP-1559 not fully supported)

### Verify Contract

If verification fails during deployment, verify manually:
```shell
forge verify-contract <CONTRACT_ADDRESS> src/PropertyToken.sol:PropertyToken --chain 5003 --watch
```

### Interact with PropertyToken

**Accept Terms:**
```shell
cast send <CONTRACT_ADDRESS> "acceptTerms()" --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

**Invest in Property:**
```shell
# Invest 0.1 ETH
cast send <CONTRACT_ADDRESS> "invest()" --value 0.1ether --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

**Check Token Balance:**
```shell
cast call <CONTRACT_ADDRESS> "balanceOf(address)" <YOUR_ADDRESS> --rpc-url mantle_sepolia
```

**Distribute Revenue (Admin Only):**
```shell
# Distribute 0.05 ETH as revenue
cast send <CONTRACT_ADDRESS> "distributeRevenue(uint256,string)" 50000000000000000 "January 2026 rental income" --value 0.05ether --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

**Claim Revenue:**
```shell
# Claim from distribution ID 0
cast send <CONTRACT_ADDRESS> "claimRevenue(uint256)" 0 --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

**Check Pending Revenue:**
```shell
cast call <CONTRACT_ADDRESS> "getPendingRevenue(address,uint256)" <YOUR_ADDRESS> 0 --rpc-url mantle_sepolia
```

**Check Account Balance:**
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

## Testing

Run all tests:
```shell
forge test
```

Run tests with verbosity:
```shell
forge test -vvv
```

Run specific test:
```shell
forge test --match-test test_ClaimRevenue -vvv
```

Generate gas report:
```shell
forge test --gas-report
```

## User Flow

1. **Deploy Contract**: Deploy PropertyToken with property metadata
2. **Accept Terms**: Investors accept terms for compliance
3. **Invest**: Investors send ETH and receive tokens
4. **Distribute Revenue**: Admin distributes monthly rental income
5. **Claim Revenue**: Investors claim their share proportionally
6. **Verify on Explorer**: Check all transactions on Mantle Sepolia Explorer

## Notes

- Solidity version: 0.8.23
- Get testnet MNT from faucet: https://faucet.sepolia.mantle.xyz/
- Always use `--legacy` flag when sending transactions to Mantle
- Token represents rental income rights from real estate properties
