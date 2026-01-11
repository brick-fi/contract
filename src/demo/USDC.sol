// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title demo USDC
 * @notice stablecoin for testing and demo purposes
 * @dev Anyone can mint tokens for testing
 */
contract DemoUSDC is ERC20, Ownable {
    constructor() ERC20("USDC", "USDC") Ownable(msg.sender) {
        // Mint initial supply to deployer for distribution
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    /**
     * @notice Mint tokens to any address (for testing only)
     * @param to Address to receive tokens
     * @param amount Amount to mint (in token units with decimals)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from caller
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Get 1000 USDC for testing (faucet)
     */
    function faucet() external {
        _mint(msg.sender, 1000 * 10 ** decimals());
    }
}
