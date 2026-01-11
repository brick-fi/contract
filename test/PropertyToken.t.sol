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
    address public platformFee;

    PropertyToken.PropertyInfo public property;

    function setUp() public {
        admin = address(this);
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        platformFee = makeAddr("platformFee");

        // Deploy Demo USDC
        usdc = new DemoUSDC();

        // Setup property metadata
        property = PropertyToken.PropertyInfo({
            propertyId: 1,
            name: "Test Property",
            location: "Test Location",
            totalValue: 100000 * 1e6, // $100,000 property value in USDC (6 decimals)
            expectedMonthlyIncome: 1000 * 1e6,
            metadataURI: "ipfs://test",
            isActive: true
        });

        // Deploy token (admin is the owner, platformFee is the fee recipient)
        token = new PropertyToken("Test Property Token", "TPT", property, admin, address(usdc), platformFee);

        // Mint USDC to test accounts
        usdc.mint(investor1, 100000 * 1e6); // 100,000 USDC
        usdc.mint(investor2, 100000 * 1e6);
        usdc.mint(admin, 100000 * 1e6);
    }

    // ===== KYC Tests =====
    function test_AcceptTerms() public {
        vm.prank(investor1);
        token.acceptTerms();

        assertTrue(token.hasAcceptedTerms(investor1));
    }

    function test_CannotAcceptTermsTwice() public {
        vm.startPrank(investor1);
        token.acceptTerms();

        vm.expectRevert("Already accepted");
        token.acceptTerms();
        vm.stopPrank();
    }

    // ===== Investment Tests =====
    function test_InvestWithKYC() public {
        vm.startPrank(investor1);
        token.acceptTerms();

        uint256 investAmount = 100 * 1e6; // 100 USDC
        // With 2% platform fee: 100 * 0.98 = 98 USDC after fee
        // tokens = (98 * 1e6 * 1e18) / (50 * 1e6) = 1.96 * 1e18 tokens
        uint256 platformFee = (investAmount * token.PLATFORM_FEE_PERCENTAGE()) / 100;
        uint256 amountAfterFee = investAmount - platformFee;
        uint256 expectedTokens = (amountAfterFee * 1e18) / token.TOKEN_PRICE();

        usdc.approve(address(token), investAmount);
        token.invest(investAmount);

        assertEq(token.balanceOf(investor1), expectedTokens);
        vm.stopPrank();
    }

    function test_CannotInvestWithoutKYC() public {
        vm.startPrank(investor1);
        uint256 investAmount = 50 * 1e6;
        usdc.approve(address(token), investAmount);

        vm.expectRevert("Must accept terms first");
        token.invest(investAmount);
        vm.stopPrank();
    }

    function test_CannotInvestZero() public {
        vm.startPrank(investor1);
        token.acceptTerms();

        vm.expectRevert("Investment must be at least $50");
        token.invest(0);
        vm.stopPrank();
    }

    function test_CannotInvestWithoutApproval() public {
        vm.startPrank(investor1);
        token.acceptTerms();

        vm.expectRevert();
        token.invest(50 * 1e6);
        vm.stopPrank();
    }

    function test_CannotInvestWhenPaused() public {
        vm.prank(admin);
        token.pause();

        vm.startPrank(investor1);
        token.acceptTerms();
        usdc.approve(address(token), 50 * 1e6);

        vm.expectRevert();
        token.invest(50 * 1e6);
        vm.stopPrank();
    }

    // ===== Distribution Tests =====
    function test_DistributeRevenue() public {
        // Setup: investor1 invests
        vm.startPrank(investor1);
        token.acceptTerms();
        usdc.approve(address(token), 50 * 1e6);
        token.invest(50 * 1e6);
        vm.stopPrank();

        // Admin distributes revenue
        uint256 revenueAmount = 100 * 1e6; // 100 USDC
        vm.startPrank(admin);
        usdc.approve(address(token), revenueAmount);
        token.distributeRevenue(revenueAmount, "January revenue");
        vm.stopPrank();

        assertEq(token.getDistributionCount(), 1);
    }

    function test_ClaimRevenue() public {
        // Setup: Two investors
        vm.startPrank(investor1);
        token.acceptTerms();
        usdc.approve(address(token), 50 * 1e6);
        token.invest(50 * 1e6);
        vm.stopPrank();

        vm.startPrank(investor2);
        token.acceptTerms();
        usdc.approve(address(token), 50 * 1e6);
        token.invest(50 * 1e6);
        vm.stopPrank();

        // Distribute revenue
        uint256 revenueAmount = 200 * 1e6; // 200 USDC
        vm.startPrank(admin);
        usdc.approve(address(token), revenueAmount);
        token.distributeRevenue(revenueAmount, "Test revenue");
        vm.stopPrank();

        // Investor1 claims
        uint256 balanceBefore = usdc.balanceOf(investor1);
        vm.prank(investor1);
        token.claimRevenue(0);

        // Should receive half (100 USDC) since both investors have equal tokens
        assertEq(usdc.balanceOf(investor1) - balanceBefore, 100 * 1e6);
    }

    function test_CannotClaimTwice() public {
        // Setup
        vm.startPrank(investor1);
        token.acceptTerms();
        usdc.approve(address(token), 50 * 1e6);
        token.invest(50 * 1e6);
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
        token.acceptTerms();
        usdc.approve(address(token), 50 * 1e6);
        token.invest(50 * 1e6);
        vm.stopPrank();

        // Distribute
        uint256 revenueAmount = 1000 * 1e6; // 1000 USDC
        vm.startPrank(admin);
        usdc.approve(address(token), revenueAmount);
        token.distributeRevenue(revenueAmount, "Test");
        vm.stopPrank();

        // Check pending
        uint256 pending = token.getPendingRevenue(investor1, 0);
        assertEq(pending, revenueAmount); // investor1 has 100% of tokens
    }

    // ===== Transfer Restrictions =====
    function test_CannotTransferWithoutKYC() public {
        // Setup investor1 with tokens
        vm.startPrank(investor1);
        token.acceptTerms();
        usdc.approve(address(token), 50 * 1e6);
        token.invest(50 * 1e6);
        vm.stopPrank();

        // Try to transfer to investor2 (no KYC)
        vm.prank(investor1);
        vm.expectRevert("Recipient must accept terms");
        token.transfer(investor2, 100);
    }

    function test_CanTransferWithKYC() public {
        // Setup both investors with KYC
        vm.startPrank(investor1);
        token.acceptTerms();
        usdc.approve(address(token), 50 * 1e6);
        token.invest(50 * 1e6);
        vm.stopPrank();

        vm.prank(investor2);
        token.acceptTerms();

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
        token.acceptTerms();
        usdc.approve(address(token), 50 * 1e6);
        vm.expectRevert();
        token.invest(50 * 1e6);
        vm.stopPrank();
    }

    function test_Unpause() public {
        vm.prank(admin);
        token.pause();
        vm.prank(admin);
        token.unpause();

        // Can invest after unpause
        vm.startPrank(investor1);
        token.acceptTerms();
        usdc.approve(address(token), 50 * 1e6);
        token.invest(50 * 1e6);
        vm.stopPrank();

        assertTrue(token.balanceOf(investor1) > 0);
    }

    function test_UpdateMetadata() public {
        string memory newURI = "ipfs://new-uri";
        vm.prank(admin);
        token.updatePropertyMetadata(newURI);

        (,,,,, string memory metadataURI,) = token.property();
        assertEq(metadataURI, newURI);
    }

    function test_SetPropertyActive() public {
        vm.prank(admin);
        token.setPropertyActive(false);

        (,,,,,, bool isActive) = token.property();
        assertFalse(isActive);
    }

    function test_WithdrawPaymentToken() public {
        // Investor invests
        vm.startPrank(investor1);
        token.acceptTerms();
        usdc.approve(address(token), 100 * 1e6);
        token.invest(100 * 1e6);
        vm.stopPrank();

        // Admin withdraws (only gets after-fee amount: 98 USDC)
        uint256 platformFee = (100 * 1e6 * token.PLATFORM_FEE_PERCENTAGE()) / 100;
        uint256 expectedAmount = 100 * 1e6 - platformFee;
        uint256 adminBalanceBefore = usdc.balanceOf(admin);
        vm.prank(admin);
        token.withdrawPaymentToken();

        assertEq(usdc.balanceOf(admin) - adminBalanceBefore, expectedAmount);
    }

    // ===== Token Supply Tests =====
    function test_PreMintedSupply() public {
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
        token.acceptTerms();
        usdc.approve(address(token), 100 * 1e6);
        token.invest(100 * 1e6);
        vm.stopPrank();

        // With 2% platform fee: 100 * 0.98 = 98 USDC after fee
        uint256 platformFee = (100 * 1e6 * token.PLATFORM_FEE_PERCENTAGE()) / 100;
        uint256 amountAfterFee = 100 * 1e6 - platformFee;
        uint256 expectedAvailable = token.maxSupply() - ((amountAfterFee * 1e18) / token.TOKEN_PRICE());
        assertEq(token.getAvailableTokens(), expectedAvailable);
    }

    function test_GetSoldTokens() public {
        // Initially no tokens sold
        assertEq(token.getSoldTokens(), 0);

        // After investment, sold tokens increase
        vm.startPrank(investor1);
        token.acceptTerms();
        usdc.approve(address(token), 100 * 1e6);
        token.invest(100 * 1e6);
        vm.stopPrank();

        // With 2% platform fee: 100 * 0.98 = 98 USDC after fee
        uint256 platformFee = (100 * 1e6 * token.PLATFORM_FEE_PERCENTAGE()) / 100;
        uint256 amountAfterFee = 100 * 1e6 - platformFee;
        uint256 expectedSold = (amountAfterFee * 1e18) / token.TOKEN_PRICE();
        assertEq(token.getSoldTokens(), expectedSold);
    }

    function test_CannotInvestWhenSoldOut() public {
        // maxSupply = 2,000 * 1e18 tokens
        // To get maxSupply tokens after 2% fee: (investAmount * 0.98 * 1e18) / TOKEN_PRICE = maxSupply
        // investAmount = (maxSupply * TOKEN_PRICE) / (0.98 * 1e18)
        // investAmount = (maxSupply * TOKEN_PRICE * 100) / (98 * 1e18)
        uint256 totalCostAfterFee = (token.maxSupply() * token.TOKEN_PRICE()) / 1e18;
        uint256 totalCost = (totalCostAfterFee * 100) / 98;

        usdc.mint(investor1, totalCost);

        // Buy all tokens
        vm.startPrank(investor1);
        token.acceptTerms();
        usdc.approve(address(token), totalCost);
        token.invest(totalCost);
        vm.stopPrank();

        // Verify all tokens are sold
        assertEq(token.getAvailableTokens(), 0);
        assertEq(token.getSoldTokens(), token.maxSupply());

        // Second investor cannot buy
        vm.startPrank(investor2);
        token.acceptTerms();
        usdc.approve(address(token), 50 * 1e6);
        vm.expectRevert("Not enough tokens available");
        token.invest(50 * 1e6);
        vm.stopPrank();
    }

    function test_NoShareDilution() public {
        // maxSupply = 2,000 * 1e18 tokens
        // To buy 50% (1,000 * 1e18 tokens) after 2% fee: investAmount = (1000 * 1e18 * TOKEN_PRICE * 100) / (98 * 1e18)
        uint256 halfSupply = token.maxSupply() / 2;
        uint256 quarterSupply = token.maxSupply() / 4;

        uint256 invest1AfterFee = (halfSupply * token.TOKEN_PRICE()) / 1e18;
        uint256 invest2AfterFee = (quarterSupply * token.TOKEN_PRICE()) / 1e18;

        // Add 2% platform fee
        uint256 invest1Amount = (invest1AfterFee * 100) / 98;
        uint256 invest2Amount = (invest2AfterFee * 100) / 98;

        usdc.mint(investor1, invest1Amount);
        usdc.mint(investor2, invest2Amount);

        // Investor1 buys 50% of tokens
        vm.startPrank(investor1);
        token.acceptTerms();
        usdc.approve(address(token), invest1Amount);
        token.invest(invest1Amount);
        vm.stopPrank();

        uint256 investor1Balance = token.balanceOf(investor1);
        uint256 investor1Percentage = (investor1Balance * 100) / token.totalSupply();

        // Investor2 buys 25% of tokens
        vm.startPrank(investor2);
        token.acceptTerms();
        usdc.approve(address(token), invest2Amount);
        token.invest(invest2Amount);
        vm.stopPrank();

        // Investor1's balance should remain the same (no dilution)
        assertEq(token.balanceOf(investor1), investor1Balance);

        // Investor1's percentage should remain 50% (within soldTokens)
        assertEq(investor1Percentage, 50);
    }
}
