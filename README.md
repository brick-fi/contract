# BrickFi - RWA Property Tokenization

Foundry-based smart contract for tokenizing real estate rental income on Mantle Sepolia testnet.

## Project Overview

BrickFi allows fractional investment in real estate rental income through tokenization. It uses a factory pattern to create property tokens that represent rental income rights (NOT ownership), enabling automated revenue distribution via stablecoins.

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

## Deployed Contracts

### Mantle Sepolia Testnet

- **DemoUSDC**: [`0xf6c6D352545Eb7316fD3034232ff7eF635325D6F`](https://sepolia.mantlescan.xyz/address/0xf6c6D352545Eb7316fD3034232ff7eF635325D6F)
- **PropertyFactory**: [`0xF569Ae2b5099C0E66Fe0edf9a9135BC69052D937`](https://sepolia.mantlescan.xyz/address/0xF569Ae2b5099C0E66Fe0edf9a9135BC69052D937)

### Get Test USDC

You can get test USDC on Mantle Sepolia testnet using one of these methods:

**Method 1: Use the Faucet Function (Easiest)**
```shell
cast send 0xf6c6D352545Eb7316fD3034232ff7eF635325D6F "faucet()" --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```
This will mint 1,000 USDC (6 decimals) to your wallet.

**Method 2: Mint Custom Amount**
```shell
# Mint 10,000 USDC (6 decimals = 10000 * 1e6)
cast send 0xf6c6D352545Eb7316fD3034232ff7eF635325D6F "mint(address,uint256)" <YOUR_ADDRESS> 10000000000 --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

**Check Your Balance:**
```shell
cast call 0xf6c6D352545Eb7316fD3034232ff7eF635325D6F "balanceOf(address)" <YOUR_ADDRESS> --rpc-url mantle_sepolia
```

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

## Smart Contract Architecture

### Contracts

```
/contract/src/
├── MockUSDC.sol          # Mock stablecoin for testing (ERC-20)
├── PropertyToken.sol     # Property rental income token (ERC-20)
└── PropertyFactory.sol   # Factory for creating PropertyTokens
```

### PropertyFactory

Factory contract that deploys and manages PropertyToken instances.

**Key Features:**
- Deploys new PropertyToken contracts
- Tracks all created properties
- Registry by owner
- Validation of PropertyToken addresses

**Functions:**
- `createProperty(name, symbol, propertyInfo)`: Create new property token
- `getAllProperties()`: Get all property addresses
- `getPropertiesByOwner(owner)`: Get properties by owner
- `isValidPropertyToken(address)`: Validate property token

### PropertyToken

ERC-20 token representing rental income rights from a specific property.

**Key Features:**
- **Payment Token**: Uses ERC-20 stablecoin (e.g., USDC) instead of native ETH
- **KYC Gate**: Terms acceptance requirement for compliance
- **Investment**: Accept stablecoin payments and distribute property tokens
- **Revenue Distribution**: Admin-triggered distribution with proportional claim mechanism
- **Transfer Restrictions**: KYC-gated transfers to ensure compliance
- **Pausable**: Emergency pause functionality for admin
- **Access Control**: Role-based permissions (ADMIN_ROLE, DISTRIBUTOR_ROLE)

**Architecture:**
```
PropertyToken.sol
├── Payment Token (IERC20 - USDC/stablecoin)
├── Property Metadata (name, location, value, expected income)
├── KYC Gate (acceptTerms)
├── Investment (invest with stablecoin)
├── Distribution (distributeRevenue, claimRevenue in stablecoin)
├── Transfer Restrictions (_update override)
└── Admin Functions (pause, unpause, updateMetadata)
```

**User Functions:**
- `acceptTerms()`: Accept terms and conditions for compliance
- `invest(amount)`: Invest stablecoin and receive property tokens
- `claimRevenue(distributionId)`: Claim share of distributed revenue
- `getPendingRevenue(user, distributionId)`: Check pending revenue

**Admin Functions:**
- `distributeRevenue(amount, description)`: Trigger revenue distribution
- `pause()` / `unpause()`: Emergency controls
- `updatePropertyMetadata(metadataURI)`: Update property 3D/2D visuals
- `setPropertyActive(bool)`: Enable/disable property investment
- `withdrawPaymentToken()`: Withdraw payment tokens from contract

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

Run specific test:
```shell
forge test --match-test test_ClaimRevenue -vvv
```

### Format

```shell
forge fmt
```

### Gas Snapshots

```shell
forge snapshot
```

## Deployment

### Deploy to Mantle Sepolia

Deploy MockUSDC and PropertyFactory:

```shell
source .env
forge script script/Deploy.s.sol --rpc-url mantle_sepolia --broadcast --verify --legacy
```

**Note**: Use `--legacy` flag for transactions on Mantle (EIP-1559 not fully supported)

**Deployed Contracts:**
1. MockUSDC (payment token)
2. PropertyFactory (property token factory)

### Create New Property Token

After deploying the factory, create property tokens via frontend or cast:

```shell
# Using cast (example)
cast send <FACTORY_ADDRESS> "createProperty(string,string,(uint256,string,string,uint256,uint256,string,bool))" \
  "BrickFi Property #1" \
  "BRKFI-P1" \
  "(1,'Sunset Apartments','Los Angeles',500000000000,3200000000,'ipfs://...',true)" \
  --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

### Verify Contract

If verification fails during deployment, verify manually:
```shell
forge verify-contract <CONTRACT_ADDRESS> src/PropertyFactory.sol:PropertyFactory --chain 5003 --watch
```

## Interaction Examples

### With MockUSDC

**Mint Test USDC:**
```shell
# Mint 10,000 USDC (6 decimals)
cast send <USDC_ADDRESS> "mint(address,uint256)" <YOUR_ADDRESS> 10000000000 --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

**Check USDC Balance:**
```shell
cast call <USDC_ADDRESS> "balanceOf(address)" <YOUR_ADDRESS> --rpc-url mantle_sepolia
```

### With PropertyToken

**Accept Terms:**
```shell
cast send <PROPERTY_TOKEN_ADDRESS> "acceptTerms()" --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

**Approve USDC:**
```shell
# Approve 100 USDC (6 decimals = 100000000)
cast send <USDC_ADDRESS> "approve(address,uint256)" <PROPERTY_TOKEN_ADDRESS> 100000000 --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

**Invest in Property:**
```shell
# Invest 100 USDC (6 decimals)
cast send <PROPERTY_TOKEN_ADDRESS> "invest(uint256)" 100000000 --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

**Check Token Balance:**
```shell
cast call <PROPERTY_TOKEN_ADDRESS> "balanceOf(address)" <YOUR_ADDRESS> --rpc-url mantle_sepolia
```

**Distribute Revenue (Admin Only):**
```shell
# 1. Approve USDC first
cast send <USDC_ADDRESS> "approve(address,uint256)" <PROPERTY_TOKEN_ADDRESS> 1000000000 --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy

# 2. Distribute 1000 USDC as revenue
cast send <PROPERTY_TOKEN_ADDRESS> "distributeRevenue(uint256,string)" 1000000000 "January 2026 rental income" --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

**Claim Revenue:**
```shell
# Claim from distribution ID 0
cast send <PROPERTY_TOKEN_ADDRESS> "claimRevenue(uint256)" 0 --rpc-url mantle_sepolia --private-key $PRIVATE_KEY --legacy
```

**Check Pending Revenue:**
```shell
cast call <PROPERTY_TOKEN_ADDRESS> "getPendingRevenue(address,uint256)" <YOUR_ADDRESS> 0 --rpc-url mantle_sepolia
```

### With PropertyFactory

**Get All Properties:**
```shell
cast call <FACTORY_ADDRESS> "getAllProperties()(address[])" --rpc-url mantle_sepolia
```

**Get Properties by Owner:**
```shell
cast call <FACTORY_ADDRESS> "getPropertiesByOwner(address)(address[])" <OWNER_ADDRESS> --rpc-url mantle_sepolia
```

**Get Property Count:**
```shell
cast call <FACTORY_ADDRESS> "getAllPropertiesCount()(uint256)" --rpc-url mantle_sepolia
```

## User Flow

### For Property Owners (Sellers)
1. **Create Property Token**: Call `factory.createProperty()` with property details
2. **Distribute Revenue**: Send monthly rental income via `distributeRevenue()`
3. **Manage Property**: Update metadata, pause/unpause as needed

### For Investors
1. **Mint Test USDC**: Get test USDC from MockUSDC contract
2. **Accept Terms**: Call `acceptTerms()` for compliance
3. **Approve USDC**: Approve PropertyToken to spend USDC
4. **Invest**: Call `invest(amount)` with desired USDC amount
5. **Receive Tokens**: Get property tokens proportional to investment
6. **Claim Revenue**: Call `claimRevenue()` when distributions are made
7. **Verify on Explorer**: Check all transactions on Mantle Sepolia Explorer

## Key Changes from ETH to Stablecoin

**Previous (ETH-based):**
- Investment: `invest() payable` with `msg.value`
- Distribution: `distributeRevenue() payable` with `msg.value`
- Claim: `transfer()` ETH directly

**Current (Stablecoin-based):**
- Investment: `invest(uint256 amount)` with ERC-20 `transferFrom`
- Distribution: `distributeRevenue(uint256 amount, string description)` with ERC-20 `transferFrom`
- Claim: ERC-20 `transfer` to user
- **Requires**: Approve → Transfer pattern for all payments

**Benefits:**
- Stable value (no ETH price volatility)
- Standard stablecoin decimals (6 decimals for USDC/USDT)
- Better for real estate pricing ($50 per token)
- Familiar Web2 user experience

## Testing

**Run all tests:**
```shell
forge test
```

**Test coverage:**
- PropertyToken: 23 tests (KYC, investment, distribution, transfers, admin)
- PropertyFactory: 13 tests (creation, registry, integration)
- Total: 36 tests - all passing

**Test with verbosity:**
```shell
forge test -vvv
```

## Notes

- Solidity version: 0.8.23
- Get testnet MNT from faucet: https://faucet.sepolia.mantle.xyz/
- Always use `--legacy` flag when sending transactions to Mantle
- Token represents rental income rights (NOT ownership) from real estate
- Payment token uses 6 decimals (standard for USDC/USDT)
- Property tokens use 18 decimals (ERC-20 standard)
- Fixed token price: $50 per token (50 * 1e6 in payment token units)
