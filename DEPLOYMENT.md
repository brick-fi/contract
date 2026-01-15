# BrickFi Smart Contract Deployment Guide

## Prerequisites

1. **Foundry installed**: https://book.getfoundry.sh/getting-started/installation
2. **Private key**: Set in `.env` file
3. **Test MNT**: Get from faucet https://faucet.sepolia.mantle.xyz/
4. **Existing USDC**: Use `0xf6c6D352545Eb7316fD3034232ff7eF635325D6F` on Mantle Sepolia

## Environment Setup

### 1. Configure `.env`

```bash
# Private key for deployment (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# Mantle Sepolia RPC
MANTLE_SEPOLIA_RPC=https://rpc.sepolia.mantle.xyz

# USDC Address on Mantle Sepolia (existing, do not change)
USDC_ADDRESS=0xf6c6D352545Eb7316fD3034232ff7eF635325D6F

# Mantlescan API key (optional, for verification)
MANTLESCAN_API_KEY=your_api_key_here
```

## Deployment Instructions

### Step 1: Build Contracts

```bash
forge build
```

### Step 2: Deploy PropertyFactory to Mantle Sepolia

**Command:**
```bash
forge script script/Deploy.s.sol:PropertyFactoryScript \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --broadcast \
  --private-key <YOUR_PRIVATE_KEY>
```

**What it does:**
- Deploys PropertyFactory contract
- Sets USDC as payment token
- Deploys deployer wallet as platform fee recipient

**Expected Output:**
```
PropertyFactory deployed to: 0x...
Payment Token (USDC): 0xf6c6D352545Eb7316fD3034232ff7eF635325D6F
Platform Fee Recipient: 0x...
```

### Step 3: Record Deployed Addresses

After deployment, save the factory address. Example:
```
PropertyFactory: 0x1619587D0d23dc67814C4C33A9639B6BDC163C18
USDC: 0xf6c6D352545Eb7316fD3034232ff7eF635325D6F
```

### Step 4: Update Frontend Environment

Update `.env.local` in frontend with new PropertyFactory address:

```bash
NEXT_PUBLIC_PROPERTY_FACTORY_ADDRESS=0x1619587D0d23dc67814C4C33A9639B6BDC163C18
NEXT_PUBLIC_DEMO_USDC_ADDRESS=0xf6c6D352545Eb7316fD3034232ff7eF635325D6F
```

## Contract Verification

### Verify PropertyFactory on Mantlescan

```bash
forge verify-contract <CONTRACT_ADDRESS> \
  src/PropertyFactory.sol:PropertyFactory \
  --chain 5003 \
  --watch
```

Or use the Mantlescan website:
https://sepolia.mantlescan.xyz/

## Testing Deployment

### 1. Check PropertyFactory is working

```bash
# Get all properties (should be empty initially)
cast call 0x1619587D0d23dc67814C4C33A9639B6BDC163C18 \
  "getAllPropertiesCount()(uint256)" \
  --rpc-url https://rpc.sepolia.mantle.xyz
```

### 2. Get Test USDC

```bash
# Option 1: Use faucet function
cast send 0xf6c6D352545Eb7316fD3034232ff7eF635325D6F \
  "faucet()" \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key <YOUR_PRIVATE_KEY> \
  --legacy

# Option 2: Mint custom amount (10,000 USDC with 6 decimals)
cast send 0xf6c6D352545Eb7316fD3034232ff7eF635325D6F \
  "mint(address,uint256)" \
  <YOUR_ADDRESS> \
  10000000000 \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key <YOUR_PRIVATE_KEY> \
  --legacy
```

### 3. Check USDC Balance

```bash
cast call 0xf6c6D352545Eb7316fD3034232ff7eF635325D6F \
  "balanceOf(address)" \
  <YOUR_ADDRESS> \
  --rpc-url https://rpc.sepolia.mantle.xyz
```

## Create Test Property

After deployment, create a test property via frontend or using cast:

```bash
# Approve USDC for PropertyFactory
cast send 0xf6c6D352545Eb7316fD3034232ff7eF635325D6F \
  "approve(address,uint256)" \
  0x1619587D0d23dc67814C4C33A9639B6BDC163C18 \
  999999999999 \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key <YOUR_PRIVATE_KEY> \
  --legacy

# Create property
cast send 0x1619587D0d23dc67814C4C33A9639B6BDC163C18 \
  "createProperty(string,string,(string,string,uint256,uint256,string,bool))" \
  "Test Property" \
  "TEST" \
  "('Test Property','Los Angeles',500000000000,3000000000,'ipfs://...',true)" \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key <YOUR_PRIVATE_KEY> \
  --legacy
```

## Useful Links

- **Mantle Sepolia Explorer**: https://sepolia.mantlescan.xyz/
- **Faucet**: https://faucet.sepolia.mantle.xyz/
- **RPC URL**: https://rpc.sepolia.mantle.xyz
- **Current Deployment**:
  - PropertyFactory: https://sepolia.mantlescan.xyz/address/0x1619587D0d23dc67814C4C33A9639B6BDC163C18
  - USDC: https://sepolia.mantlescan.xyz/address/0xf6c6D352545Eb7316fD3034232ff7eF635325D6F

## Troubleshooting

### Error: "Insufficient funds for gas"
- Get more test MNT from faucet: https://faucet.sepolia.mantle.xyz/
- Gas is cheap on Mantle (~0.9 MNT per deployment)

### Error: "USDC_ADDRESS not set in environment"
- Make sure `.env` file has `USDC_ADDRESS=0xf6c6D352545Eb7316fD3034232ff7eF635325D6F`
- Load env: `source .env`

### Error: "You seem to be using Foundry's default sender"
- This is a warning, deployment still succeeds
- Specify sender explicitly if needed: `--sender <ADDRESS>`

### Transaction fails with "Legacy" flag
- Always use `--legacy` for Mantle Sepolia
- EIP-1559 is not fully supported on Mantle yet
