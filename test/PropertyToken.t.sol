// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {PropertyToken} from "../src/PropertyToken.sol";

contract PropertyTokenTest is Test {
    PropertyToken public token;
    address public admin;
    address public investor1;
    address public investor2;

    PropertyToken.PropertyInfo public property;

    function setUp() public {
        admin = address(this);
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");

        // Setup property metadata
        property = PropertyToken.PropertyInfo({
            propertyId: 1,
            name: "Test Property",
            location: "Test Location",
            totalValue: 100000 * 1e18, // $100,000 property value
            expectedMonthlyIncome: 1000 * 1e18,
            maxSupply: 100000 * 1e18, // 100,000 tokens max supply
            metadataURI: "ipfs://test",
            isActive: true
        });

        // Deploy token
        token = new PropertyToken("Test Property Token", "TPT", property);

        // Fund test accounts
        vm.deal(investor1, 100 ether);
        vm.deal(investor2, 100 ether);
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

        uint256 investAmount = 1 ether;
        // With totalValue = 100,000 ETH and maxSupply = 100,000 tokens:
        // pricePerToken = 1 ETH, so 1 ETH investment = 1 token
        uint256 expectedTokens = investAmount / token.pricePerToken();

        token.invest{value: investAmount}();

        assertEq(token.balanceOf(investor1), expectedTokens);
        vm.stopPrank();
    }

    function test_CannotInvestWithoutKYC() public {
        vm.prank(investor1);
        vm.expectRevert("Must accept terms first");
        token.invest{value: 1 ether}();
    }

    function test_CannotInvestZero() public {
        vm.startPrank(investor1);
        token.acceptTerms();

        vm.expectRevert("Investment amount must be > 0");
        token.invest{value: 0}();
        vm.stopPrank();
    }

    function test_CannotInvestWhenPaused() public {
        vm.startPrank(admin);
        token.pause();
        vm.stopPrank();

        vm.startPrank(investor1);
        token.acceptTerms();

        vm.expectRevert();
        token.invest{value: 1 ether}();
        vm.stopPrank();
    }

    // ===== Distribution Tests =====
    function test_DistributeRevenue() public {
        // Setup: investor1 invests
        vm.startPrank(investor1);
        token.acceptTerms();
        token.invest{value: 1 ether}();
        vm.stopPrank();

        // Admin distributes revenue
        uint256 revenueAmount = 0.1 ether;
        vm.prank(admin);
        token.distributeRevenue{value: revenueAmount}(revenueAmount, "January revenue");

        assertEq(token.getDistributionCount(), 1);
    }

    function test_ClaimRevenue() public {
        // Setup: Two investors
        vm.prank(investor1);
        token.acceptTerms();
        vm.prank(investor1);
        token.invest{value: 1 ether}();

        vm.prank(investor2);
        token.acceptTerms();
        vm.prank(investor2);
        token.invest{value: 1 ether}();

        // Distribute revenue
        uint256 revenueAmount = 0.2 ether;
        vm.prank(admin);
        token.distributeRevenue{value: revenueAmount}(revenueAmount, "Test revenue");

        // Investor1 claims
        uint256 balanceBefore = investor1.balance;
        vm.prank(investor1);
        token.claimRevenue(0);

        // Should receive half (0.1 ether) since both investors have equal tokens
        assertEq(investor1.balance - balanceBefore, 0.1 ether);
    }

    function test_CannotClaimTwice() public {
        // Setup
        vm.prank(investor1);
        token.acceptTerms();
        vm.prank(investor1);
        token.invest{value: 1 ether}();

        // Distribute
        vm.prank(admin);
        token.distributeRevenue{value: 0.1 ether}(0.1 ether, "Test");

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
        vm.prank(investor1);
        token.acceptTerms();
        vm.prank(investor1);
        token.invest{value: 1 ether}();

        // Distribute
        uint256 revenueAmount = 1 ether;
        vm.prank(admin);
        token.distributeRevenue{value: revenueAmount}(revenueAmount, "Test");

        // Check pending
        uint256 pending = token.getPendingRevenue(investor1, 0);
        assertEq(pending, revenueAmount); // investor1 has 100% of tokens
    }

    // ===== Transfer Restrictions =====
    function test_CannotTransferWithoutKYC() public {
        // Setup investor1 with tokens
        vm.prank(investor1);
        token.acceptTerms();
        vm.prank(investor1);
        token.invest{value: 1 ether}();

        // Try to transfer to investor2 (no KYC)
        vm.prank(investor1);
        vm.expectRevert("Recipient must accept terms");
        token.transfer(investor2, 100);
    }

    function test_CanTransferWithKYC() public {
        // Setup both investors with KYC
        vm.prank(investor1);
        token.acceptTerms();
        vm.prank(investor1);
        token.invest{value: 1 ether}();

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
        vm.prank(investor1);
        token.acceptTerms();
        vm.prank(investor1);
        vm.expectRevert();
        token.invest{value: 1 ether}();
    }

    function test_Unpause() public {
        vm.prank(admin);
        token.pause();
        vm.prank(admin);
        token.unpause();

        // Can invest after unpause
        vm.prank(investor1);
        token.acceptTerms();
        vm.prank(investor1);
        token.invest{value: 1 ether}();

        assertTrue(token.balanceOf(investor1) > 0);
    }

    function test_UpdateMetadata() public {
        string memory newURI = "ipfs://new-uri";
        vm.prank(admin);
        token.updatePropertyMetadata(newURI);

        (,,,,,, string memory metadataURI,) = token.property();
        assertEq(metadataURI, newURI);
    }

    function test_SetPropertyActive() public {
        vm.prank(admin);
        token.setPropertyActive(false);

        (,,,,,,, bool isActive) = token.property();
        assertFalse(isActive);
    }

    // ===== Token Supply Tests =====
    function test_PreMintedSupply() public {
        // Contract should have all tokens pre-minted
        assertEq(token.totalSupply(), property.maxSupply);
        assertEq(token.balanceOf(address(token)), property.maxSupply);
    }

    function test_GetAvailableTokens() public {
        // Initially all tokens available
        assertEq(token.getAvailableTokens(), property.maxSupply);

        // After investment, available tokens decrease
        vm.prank(investor1);
        token.acceptTerms();
        vm.prank(investor1);
        token.invest{value: 1 ether}();

        uint256 expectedAvailable = property.maxSupply - (1 ether / token.pricePerToken());
        assertEq(token.getAvailableTokens(), expectedAvailable);
    }

    function test_GetSoldTokens() public {
        // Initially no tokens sold
        assertEq(token.getSoldTokens(), 0);

        // After investment, sold tokens increase
        vm.prank(investor1);
        token.acceptTerms();
        vm.prank(investor1);
        token.invest{value: 1 ether}();

        uint256 expectedSold = 1 ether / token.pricePerToken();
        assertEq(token.getSoldTokens(), expectedSold);
    }

    function test_CannotInvestWhenSoldOut() public {
        // Give investor1 enough funds to buy all tokens
        vm.deal(investor1, 100000 ether + 1 ether);

        // Buy all tokens
        vm.prank(investor1);
        token.acceptTerms();
        vm.prank(investor1);
        token.invest{value: 100000 ether}(); // Buy all tokens

        // Verify all tokens are sold
        assertEq(token.getAvailableTokens(), 0);
        assertEq(token.getSoldTokens(), property.maxSupply);

        // Second investor cannot buy
        vm.prank(investor2);
        token.acceptTerms();
        vm.prank(investor2);
        vm.expectRevert("Not enough tokens available");
        token.invest{value: 1 ether}();
    }

    function test_NoShareDilution() public {
        // Give investors enough funds
        vm.deal(investor1, 50000 ether + 1 ether);
        vm.deal(investor2, 25000 ether + 1 ether);

        // Investor1 buys 50% of tokens
        vm.prank(investor1);
        token.acceptTerms();
        vm.prank(investor1);
        token.invest{value: 50000 ether}();

        uint256 investor1Balance = token.balanceOf(investor1);
        uint256 investor1Percentage = (investor1Balance * 100) / token.totalSupply();

        // Investor2 buys 25% of tokens
        vm.prank(investor2);
        token.acceptTerms();
        vm.prank(investor2);
        token.invest{value: 25000 ether}();

        // Investor1's balance should remain the same (no dilution)
        assertEq(token.balanceOf(investor1), investor1Balance);

        // Investor1's percentage should remain 50%
        assertEq(investor1Percentage, 50);
    }
}
