// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {PropertyToken} from "../src/PropertyToken.sol";
import {DemoUSDC} from "../src/demo/USDC.sol";

contract PropertyTokenTest is Test {
    PropertyToken public token;
    DemoUSDC public usdc;
    address public admin;
    address public investor1;
    address public investor2;
    address public feeRecipient;

    PropertyToken.PropertyInfo public property;

    function setUp() public {
        admin = address(this);
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        feeRecipient = makeAddr("feeRecipient");

        // Deploy Demo USDC
        usdc = new DemoUSDC();

        // Setup property metadata
        property = PropertyToken.PropertyInfo({
            name: "Test Property",
            location: "Test Location",
            totalValue: 100000 * 1e6, // $100,000 property value in USDC (6 decimals)
            expectedMonthlyIncome: 1000 * 1e6,
            metadataURI: "ipfs://test",
            isActive: true
        });

        // Deploy token (admin is the owner, feeRecipient is the fee recipient)
        token = new PropertyToken("Test Property Token", "TPT", property, admin, address(usdc), feeRecipient);

        // Mint USDC to test accounts
        usdc.mint(investor1, 100000 * 1e6); // 100,000 USDC
        usdc.mint(investor2, 100000 * 1e6);
        usdc.mint(admin, 100000 * 1e6);
    }

    // ===== Investment Tests =====
    function test_Invest() public {
        vm.startPrank(investor1);

        uint256 totalAmount = 102 * 1e6; // 102 USDC (100 USDC investment + 2% fee)
        // With 2% platform fee: 102 * 2 / 102 = 2 USDC fee
        // amountAfterFee = 102 - 2 = 100 USDC for investment
        // tokens = (100 * 1e6 * 1e18) / (50 * 1e6) = 2 * 1e18 tokens
        uint256 platformFee = (totalAmount * token.PLATFORM_FEE_PERCENTAGE()) / (100 + token.PLATFORM_FEE_PERCENTAGE());
        uint256 amountAfterFee = totalAmount - platformFee;
        uint256 expectedTokens = (amountAfterFee * 1e18) / token.TOKEN_PRICE();

        usdc.approve(address(token), totalAmount);
        token.invest(totalAmount);

        assertEq(token.balanceOf(investor1), expectedTokens);
        vm.stopPrank();
    }

    function test_CannotInvestZero() public {
        vm.startPrank(investor1);

        vm.expectRevert("Investment below minimum");
        token.invest(0);
        vm.stopPrank();
    }

    function test_CannotInvestWithoutApproval() public {
        vm.startPrank(investor1);
        vm.expectRevert();
        token.invest(51 * 1e6); // 51 to send 50 after fee
        vm.stopPrank();
    }

    function test_CannotInvestWhenPaused() public {
        vm.prank(admin);
        token.pause();

        vm.startPrank(investor1);
        usdc.approve(address(token), 51 * 1e6);
        vm.expectRevert();
        token.invest(51 * 1e6);
        vm.stopPrank();
    }

    // ===== Distribution Tests =====
    function test_DistributeRevenue() public {
        // Setup: investor1 invests (1 token = 50 USDC worth)
        vm.startPrank(investor1);
        usdc.approve(address(token), 51 * 1e6);
        token.invest(51 * 1e6);
        vm.stopPrank();

        // Admin expects to distribute 100 USDC for all tokens (maxSupply = 2000)
        // But only 1 token sold out of 2000
        // So actualAmount = 100 * (1 / 2000) = 0.05 USDC
        // Admin only pays 0.05 USDC, not 100 USDC
        uint256 expectedAmount = 100 * 1e6; // 100 USDC (expected for all tokens)
        uint256 soldTokens = token.getSoldTokens(); // 1 token
        uint256 maxSupply = token.maxSupply(); // 2000 tokens
        uint256 actualAmount = (expectedAmount * soldTokens) / maxSupply; // 50,000 USDC (0.05)

        uint256 adminBalanceBefore = usdc.balanceOf(admin);
        vm.startPrank(admin);
        usdc.approve(address(token), actualAmount);
        token.distributeRevenue(expectedAmount, "January revenue");
        vm.stopPrank();

        // Verify distribution was created
        assertEq(token.getDistributionCount(), 1);
        // Verify admin only paid actual amount, not expected amount
        assertEq(adminBalanceBefore - usdc.balanceOf(admin), actualAmount);
    }

    function test_ClaimRevenue() public {
        // Setup: Two investors (2 tokens sold)
        vm.startPrank(investor1);
        usdc.approve(address(token), 51 * 1e6);
        token.invest(51 * 1e6); // 1 token
        vm.stopPrank();

        vm.startPrank(investor2);
        usdc.approve(address(token), 51 * 1e6);
        token.invest(51 * 1e6); // 1 token
        vm.stopPrank();

        // Distribute revenue: expected 10,000 USDC for all tokens
        // Sold: 2 tokens out of 2000 maxSupply = 0.1%
        // Actual amount admin transfers: 10,000 * (2/2000) = 10 USDC
        uint256 expectedAmount = 10000 * 1e6; // 10,000 USDC expected for all tokens
        uint256 soldTokens = token.getSoldTokens(); // 2 tokens
        uint256 maxSupply = token.maxSupply(); // 2000 tokens
        uint256 actualAmount = (expectedAmount * soldTokens) / maxSupply; // 10 USDC

        vm.startPrank(admin);
        usdc.approve(address(token), actualAmount);
        token.distributeRevenue(expectedAmount, "Test revenue");
        vm.stopPrank();

        // Investor1 claims (1 out of 2 sold tokens)
        uint256 balanceBefore = usdc.balanceOf(investor1);
        vm.prank(investor1);
        token.claimRevenue(0);

        // Distribution is calculated as: (actualAmount * userTokens) / soldTokens
        // = (10 * 1) / 2 = 5 USDC per investor
        uint256 investor1Tokens = token.balanceOf(investor1);
        uint256 expectedShare = (actualAmount * investor1Tokens) / soldTokens;
        assertEq(usdc.balanceOf(investor1) - balanceBefore, expectedShare);
    }

    function test_CannotClaimTwice() public {
        // Setup
        vm.startPrank(investor1);
        usdc.approve(address(token), 51 * 1e6);
        token.invest(51 * 1e6);
        vm.stopPrank();

        // Distribute
        vm.startPrank(admin);
        usdc.approve(address(token), 100 * 1e6);
        token.distributeRevenue(100 * 1e6, "Test");
        vm.stopPrank();

        // First claim
        vm.prank(investor1);
        token.claimRevenue(0);

        // Second claim should fail
        vm.prank(investor1);
        vm.expectRevert("Already claimed");
        token.claimRevenue(0);
    }

    function test_GetPendingRevenue() public {
        // Setup
        vm.startPrank(investor1);
        usdc.approve(address(token), 51 * 1e6);
        token.invest(51 * 1e6); // 1 token
        vm.stopPrank();

        // Distribute: expected 10,000 USDC for all tokens
        // Sold: 1 token out of 2000 = 0.05%
        // Actual amount admin transfers: 10,000 * (1/2000) = 5 USDC
        uint256 expectedAmount = 10000 * 1e6;
        uint256 soldTokens = token.getSoldTokens(); // 1
        uint256 maxSupply = token.maxSupply(); // 2000
        uint256 actualAmount = (expectedAmount * soldTokens) / maxSupply; // 5 USDC

        vm.startPrank(admin);
        usdc.approve(address(token), actualAmount);
        token.distributeRevenue(expectedAmount, "Test");
        vm.stopPrank();

        // Pending should be: (actualAmount * userTokens) / soldTokens
        // = (5 * 1) / 1 = 5 USDC (investor1 has all sold tokens)
        uint256 investor1Tokens = token.balanceOf(investor1);
        uint256 expectedPending = (actualAmount * investor1Tokens) / soldTokens;
        uint256 pending = token.getPendingRevenue(investor1, 0);
        assertEq(pending, expectedPending);
    }

    // ===== Transfer Tests =====
    function test_CanTransfer() public {
        // Setup investor1 with tokens
        vm.startPrank(investor1);
        usdc.approve(address(token), 51 * 1e6);
        token.invest(51 * 1e6);
        vm.stopPrank();

        // Transfer
        uint256 transferAmount = 100;
        vm.prank(investor1);
        token.transfer(investor2, transferAmount);

        assertEq(token.balanceOf(investor2), transferAmount);
    }

    // ===== Admin Functions =====
    function test_Pause() public {
        vm.prank(admin);
        token.pause();

        // Cannot invest when paused
        vm.startPrank(investor1);
        usdc.approve(address(token), 51 * 1e6);
        vm.expectRevert();
        token.invest(51 * 1e6);
        vm.stopPrank();
    }

    function test_Unpause() public {
        vm.prank(admin);
        token.pause();
        vm.prank(admin);
        token.unpause();

        // Can invest after unpause
        vm.startPrank(investor1);
        usdc.approve(address(token), 51 * 1e6);
        token.invest(51 * 1e6);
        vm.stopPrank();

        assertTrue(token.balanceOf(investor1) > 0);
    }

    function test_UpdateMetadata() public {
        string memory newURI = "ipfs://new-uri";
        vm.prank(admin);
        token.updatePropertyMetadata(newURI);

        (,,,, string memory metadataURI,) = token.property();
        assertEq(metadataURI, newURI);
    }

    function test_SetPropertyActive() public {
        vm.prank(admin);
        token.setPropertyActive(false);

        (,,,,, bool isActive) = token.property();
        assertFalse(isActive);
    }

    function test_WithdrawPaymentToken() public {
        // Investor invests 102 USDC (100 after fee)
        vm.startPrank(investor1);
        usdc.approve(address(token), 102 * 1e6);
        token.invest(102 * 1e6);
        vm.stopPrank();

        // Admin withdraws (should get 100 USDC after fee)
        uint256 totalAmount = 102 * 1e6;
        uint256 platformFee = (totalAmount * token.PLATFORM_FEE_PERCENTAGE()) / (100 + token.PLATFORM_FEE_PERCENTAGE());
        uint256 expectedAmount = totalAmount - platformFee;
        uint256 adminBalanceBefore = usdc.balanceOf(admin);
        vm.prank(admin);
        token.withdrawPaymentToken();

        assertEq(usdc.balanceOf(admin) - adminBalanceBefore, expectedAmount);
    }

    // ===== Token Supply Tests =====
    function test_PreMintedSupply() public view {
        // Contract should have all tokens pre-minted
        // maxSupply = (totalValue * 1e18) / TOKEN_PRICE = (100,000 * 1e6 * 1e18) / (50 * 1e6) = 2,000 * 1e18 tokens
        uint256 expectedMaxSupply = (property.totalValue * 1e18) / token.TOKEN_PRICE();
        assertEq(token.maxSupply(), expectedMaxSupply);
        assertEq(token.totalSupply(), expectedMaxSupply);
        assertEq(token.balanceOf(address(token)), expectedMaxSupply);
    }

    function test_GetAvailableTokens() public {
        // Initially all tokens available
        assertEq(token.getAvailableTokens(), token.maxSupply());

        // After investment, available tokens decrease
        vm.startPrank(investor1);
        usdc.approve(address(token), 102 * 1e6);
        token.invest(102 * 1e6);
        vm.stopPrank();

        // With 2% platform fee: 102 * 2 / 102 = 2 USDC fee
        // amountAfterFee = 100 USDC
        uint256 totalAmount = 102 * 1e6;
        uint256 platformFee = (totalAmount * token.PLATFORM_FEE_PERCENTAGE()) / (100 + token.PLATFORM_FEE_PERCENTAGE());
        uint256 amountAfterFee = totalAmount - platformFee;
        uint256 expectedAvailable = token.maxSupply() - ((amountAfterFee * 1e18) / token.TOKEN_PRICE());
        assertEq(token.getAvailableTokens(), expectedAvailable);
    }

    function test_GetSoldTokens() public {
        // Initially no tokens sold
        assertEq(token.getSoldTokens(), 0);

        // After investment, sold tokens increase
        vm.startPrank(investor1);
        usdc.approve(address(token), 102 * 1e6);
        token.invest(102 * 1e6);
        vm.stopPrank();

        // With 2% platform fee: 102 * 2 / 102 = 2 USDC fee
        // amountAfterFee = 100 USDC
        uint256 totalAmount = 102 * 1e6;
        uint256 platformFee = (totalAmount * token.PLATFORM_FEE_PERCENTAGE()) / (100 + token.PLATFORM_FEE_PERCENTAGE());
        uint256 amountAfterFee = totalAmount - platformFee;
        uint256 expectedSold = (amountAfterFee * 1e18) / token.TOKEN_PRICE();
        assertEq(token.getSoldTokens(), expectedSold);
    }

    function test_CannotInvestWhenSoldOut() public {
        // Calculate amount needed to buy all tokens
        // If we want to get maxSupply tokens after 2% fee:
        // (totalAmount * 2 / 102) = fee, (totalAmount - fee) * 1e18 / TOKEN_PRICE = maxSupply
        // totalAmount = (maxSupply * TOKEN_PRICE / 1e18) * 102 / 100
        uint256 totalCostAfterFee = (token.maxSupply() * token.TOKEN_PRICE()) / 1e18;
        uint256 totalCost = (totalCostAfterFee * 102) / 100;

        usdc.mint(investor1, totalCost);

        // Buy all tokens
        vm.startPrank(investor1);
        usdc.approve(address(token), totalCost);
        token.invest(totalCost);
        vm.stopPrank();

        // Verify all tokens are sold
        assertEq(token.getAvailableTokens(), 0);
        assertEq(token.getSoldTokens(), token.maxSupply());

        // Second investor cannot buy
        vm.startPrank(investor2);
        usdc.approve(address(token), 51 * 1e6);
        vm.expectRevert("Not enough tokens available");
        token.invest(51 * 1e6);
        vm.stopPrank();
    }

    function test_NoShareDilution() public {
        // Calculate amounts to buy specific percentages
        uint256 halfSupply = token.maxSupply() / 2;
        uint256 quarterSupply = token.maxSupply() / 4;

        uint256 invest1AfterFee = (halfSupply * token.TOKEN_PRICE()) / 1e18;
        uint256 invest2AfterFee = (quarterSupply * token.TOKEN_PRICE()) / 1e18;

        // Add 2% platform fee: totalAmount = afterFee * 102 / 100
        uint256 invest1Amount = (invest1AfterFee * 102) / 100;
        uint256 invest2Amount = (invest2AfterFee * 102) / 100;

        usdc.mint(investor1, invest1Amount);
        usdc.mint(investor2, invest2Amount);

        // Investor1 buys 50% of tokens
        vm.startPrank(investor1);
        usdc.approve(address(token), invest1Amount);
        token.invest(invest1Amount);
        vm.stopPrank();

        uint256 investor1Balance = token.balanceOf(investor1);
        uint256 investor1Percentage = (investor1Balance * 100) / token.totalSupply();

        // Investor2 buys 25% of tokens
        vm.startPrank(investor2);
        usdc.approve(address(token), invest2Amount);
        token.invest(invest2Amount);
        vm.stopPrank();

        // Investor1's balance should remain the same (no dilution)
        assertEq(token.balanceOf(investor1), investor1Balance);

        // Investor1's percentage should remain 50% (within soldTokens)
        assertEq(investor1Percentage, 50);
    }
}
