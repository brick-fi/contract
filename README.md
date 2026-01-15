# BrickFi - RWA Property Tokenization

Smart contracts for tokenizing real estate rental income on Mantle Sepolia testnet.

## Overview

BrickFi enables fractional investment in real estate rental income through ERC-20 tokens that represent income rights (not ownership). Investors receive monthly revenue distributions automatically via smart contracts.

## Deployed Contracts (Mantle Sepolia)

- **USDC**: [`0xf6c6D352545Eb7316fD3034232ff7eF635325D6F`](https://sepolia.mantlescan.xyz/address/0xf6c6D352545Eb7316fD3034232ff7eF635325D6F)
- **PropertyFactory**: [`0xed844A85D89C95B17caAF5141F014a8069a662fa`](https://sepolia.mantlescan.xyz/address/0xed844A85D89C95B17caAF5141F014a8069a662fa)

## Network

- **Network**: Mantle Sepolia (Chain ID: 5003)
- **RPC**: https://rpc.sepolia.mantle.xyz
- **Explorer**: https://sepolia.mantlescan.xyz/
- **Faucet**: https://faucet.sepolia.mantle.xyz/

## Contracts

### PropertyFactory
Factory that deploys PropertyToken instances. Tracks all created properties and their owners.

**Main Functions:**
- `createProperty(name, symbol, propertyInfo)` - Create new property token
- `getAllProperties()` - Get all property addresses
- `getPropertiesByOwner(owner)` - Get properties by owner

### PropertyToken
ERC-20 token representing rental income rights from a specific property.

**Key Features:**
- Stablecoin-based (USDC) investment and distribution
- Role-based access control (ADMIN_ROLE, DISTRIBUTOR_ROLE)
- Pausable for emergency controls
- Proportional revenue distribution with claim mechanism

**User Functions:**
- `invest(amount)` - Invest USDC and receive property tokens ($50 per token)
- `claimRevenue(distributionId)` - Claim share of distributed revenue
- `getPendingRevenue(user, distributionId)` - Check pending revenue

**Admin Functions:**
- `distributeRevenue(amount, description)` - Distribute rental income
- `setMinInvestment(amount)` - Set minimum investment requirement
- `pause()` / `unpause()` - Emergency controls

## Quick Start

### Setup
```bash
forge install
cp .env.example .env
# Edit .env with your PRIVATE_KEY
```

### Build & Test
```bash
forge build
forge test
```

### Get Test USDC
```bash
# Method 1: Faucet (easiest, 1,000 USDC)
cast send 0xf6c6D352545Eb7316fD3034232ff7eF635325D6F "faucet()" \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY --legacy

# Method 2: Mint custom amount
cast send 0xf6c6D352545Eb7316fD3034232ff7eF635325D6F \
  "mint(address,uint256)" <YOUR_ADDRESS> 10000000000 \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY --legacy
```

## Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed deployment instructions.

## Key Specs

- **Token Price**: $50 per token (fixed)
- **Platform Fee**: 2% (deducted from investment)
- **USDC Decimals**: 6
- **PropertyToken Decimals**: 18
- **Solidity Version**: 0.8.23

## Investment Flow

### For Investors
1. Get test USDC from faucet
2. Approve USDC spending on PropertyToken
3. Call `invest(amount)` to receive property tokens
4. Claim revenue when distributions are made

### For Property Owners
1. Create property via `factory.createProperty()`
2. Distribute rental income via `distributeRevenue()`
3. Investors claim their proportional share

## Testing

```bash
# Run all tests
forge test

# With gas report
forge test --gas-report

# Specific test
forge test --match-test test_ClaimRevenue -vvv
```

## Documentation

- [DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment guide
- [Mantle Docs](https://docs.mantle.xyz/) - Network documentation
- [Foundry Book](https://book.getfoundry.sh/) - Foundry documentation
