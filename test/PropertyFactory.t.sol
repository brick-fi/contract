// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {PropertyFactory} from "../src/PropertyFactory.sol";
import {PropertyToken} from "../src/PropertyToken.sol";
import {DemoUSDC} from "../src/demo/USDC.sol";

contract PropertyFactoryTest is Test {
    PropertyFactory public factory;
    DemoUSDC public usdc;
    address public seller1;
    address public seller2;
    address public investor;

    function setUp() public {
        usdc = new DemoUSDC();
        factory = new PropertyFactory(address(usdc));
        seller1 = makeAddr("seller1");
        seller2 = makeAddr("seller2");
        investor = makeAddr("investor");

        // Mint USDC to accounts
        usdc.mint(seller1, 100000 * 1e6);
        usdc.mint(seller2, 100000 * 1e6);
        usdc.mint(investor, 100000 * 1e6);
    }

    // ===== Property Creation Tests =====
    function test_CreateProperty() public {
        PropertyToken.PropertyInfo memory property = PropertyToken.PropertyInfo({
            propertyId: 1,
            name: "Test Property",
            location: "Test Location",
            totalValue: 100000 * 1e6,
            expectedMonthlyIncome: 1000 * 1e6,
            metadataURI: "ipfs://test",
            isActive: true
        });

        vm.prank(seller1);
        address propertyToken = factory.createProperty("Test Token", "TEST", property);

        assertTrue(propertyToken != address(0));
        assertTrue(factory.isValidPropertyToken(propertyToken));
    }

    function test_CreatePropertyEmitsEvent() public {
        PropertyToken.PropertyInfo memory property = PropertyToken.PropertyInfo({
            propertyId: 1,
            name: "Test Property",
            location: "Test Location",
            totalValue: 100000 * 1e6,
            expectedMonthlyIncome: 1000 * 1e6,
            metadataURI: "ipfs://test",
            isActive: true
        });

        vm.prank(seller1);
        vm.expectEmit(false, true, false, false);
        emit PropertyFactory.PropertyCreated(address(0), seller1, "Test Token", "TEST", 1, 100000 * 1e6);
        factory.createProperty("Test Token", "TEST", property);
    }

    function test_CreatorIsAdmin() public {
        PropertyToken.PropertyInfo memory property = PropertyToken.PropertyInfo({
            propertyId: 1,
            name: "Test Property",
            location: "Test Location",
            totalValue: 100000 * 1e6,
            expectedMonthlyIncome: 1000 * 1e6,
            metadataURI: "ipfs://test",
            isActive: true
        });

        vm.prank(seller1);
        address propertyTokenAddr = factory.createProperty("Test Token", "TEST", property);

        PropertyToken propertyToken = PropertyToken(propertyTokenAddr);

        // Verify seller1 has admin role
        assertTrue(propertyToken.hasRole(propertyToken.ADMIN_ROLE(), seller1));
        assertTrue(propertyToken.hasRole(propertyToken.DISTRIBUTOR_ROLE(), seller1));
    }

    function test_MultiplePropertiesCreation() public {
        PropertyToken.PropertyInfo memory property1 = PropertyToken.PropertyInfo({
            propertyId: 1,
            name: "Property 1",
            location: "Location 1",
            totalValue: 100000 * 1e6,
            expectedMonthlyIncome: 1000 * 1e6,
            metadataURI: "ipfs://test1",
            isActive: true
        });

        PropertyToken.PropertyInfo memory property2 = PropertyToken.PropertyInfo({
            propertyId: 2,
            name: "Property 2",
            location: "Location 2",
            totalValue: 200000 * 1e6,
            expectedMonthlyIncome: 2000 * 1e6,
            metadataURI: "ipfs://test2",
            isActive: true
        });

        vm.prank(seller1);
        factory.createProperty("Token 1", "TK1", property1);

        vm.prank(seller2);
        factory.createProperty("Token 2", "TK2", property2);

        assertEq(factory.getAllPropertiesCount(), 2);
    }

    // ===== Registry Tests =====
    function test_GetAllProperties() public {
        _createTestProperty(seller1, 1);
        _createTestProperty(seller2, 2);

        PropertyToken[] memory properties = factory.getAllProperties();
        assertEq(properties.length, 2);
    }

    function test_GetPropertiesByOwner() public {
        _createTestProperty(seller1, 1);
        _createTestProperty(seller1, 2);
        _createTestProperty(seller2, 3);

        PropertyToken[] memory seller1Properties = factory.getPropertiesByOwner(seller1);
        PropertyToken[] memory seller2Properties = factory.getPropertiesByOwner(seller2);

        assertEq(seller1Properties.length, 2);
        assertEq(seller2Properties.length, 1);
    }

    function test_GetPropertiesCountByOwner() public {
        _createTestProperty(seller1, 1);
        _createTestProperty(seller1, 2);

        assertEq(factory.getPropertiesCountByOwner(seller1), 2);
        assertEq(factory.getPropertiesCountByOwner(seller2), 0);
    }

    function test_GetPropertyAt() public {
        address property1 = _createTestProperty(seller1, 1);
        address property2 = _createTestProperty(seller2, 2);

        assertEq(address(factory.getPropertyAt(0)), property1);
        assertEq(address(factory.getPropertyAt(1)), property2);
    }

    function test_GetPropertyAtRevertsOnInvalidIndex() public {
        vm.expectRevert("Index out of bounds");
        factory.getPropertyAt(0);
    }

    function test_IsValidPropertyToken() public {
        address property = _createTestProperty(seller1, 1);
        address randomAddress = makeAddr("random");

        assertTrue(factory.isValidPropertyToken(property));
        assertFalse(factory.isValidPropertyToken(randomAddress));
    }

    // ===== Integration Tests =====
    function test_InvestorCanInvestInCreatedProperty() public {
        PropertyToken.PropertyInfo memory property = PropertyToken.PropertyInfo({
            propertyId: 1,
            name: "Test Property",
            location: "Test Location",
            totalValue: 100000 * 1e6,
            expectedMonthlyIncome: 1000 * 1e6,
            metadataURI: "ipfs://test",
            isActive: true
        });

        vm.prank(seller1);
        address propertyTokenAddr = factory.createProperty("Test Token", "TEST", property);

        PropertyToken propertyToken = PropertyToken(propertyTokenAddr);

        // Investor accepts terms and invests
        vm.startPrank(investor);
        propertyToken.acceptTerms();
        usdc.approve(address(propertyToken), 100 * 1e6);
        propertyToken.invest(100 * 1e6);
        vm.stopPrank();

        // Verify investor received tokens
        uint256 expectedTokens = (100 * 1e6 * 1e18) / propertyToken.TOKEN_PRICE();
        assertEq(propertyToken.balanceOf(investor), expectedTokens);
    }

    function test_SellerCanDistributeRevenue() public {
        PropertyToken.PropertyInfo memory property = PropertyToken.PropertyInfo({
            propertyId: 1,
            name: "Test Property",
            location: "Test Location",
            totalValue: 100000 * 1e6,
            expectedMonthlyIncome: 1000 * 1e6,
            metadataURI: "ipfs://test",
            isActive: true
        });

        vm.prank(seller1);
        address propertyTokenAddr = factory.createProperty("Test Token", "TEST", property);

        PropertyToken propertyToken = PropertyToken(propertyTokenAddr);

        // Investor buys tokens
        vm.startPrank(investor);
        propertyToken.acceptTerms();
        usdc.approve(address(propertyToken), 100 * 1e6);
        propertyToken.invest(100 * 1e6);
        vm.stopPrank();

        // Seller distributes revenue
        vm.startPrank(seller1);
        usdc.approve(address(propertyToken), 1000 * 1e6);
        propertyToken.distributeRevenue(1000 * 1e6, "January revenue");
        vm.stopPrank();

        assertEq(propertyToken.getDistributionCount(), 1);
    }

    function test_OnlySellerCanDistribute() public {
        PropertyToken.PropertyInfo memory property = PropertyToken.PropertyInfo({
            propertyId: 1,
            name: "Test Property",
            location: "Test Location",
            totalValue: 100000 * 1e6,
            expectedMonthlyIncome: 1000 * 1e6,
            metadataURI: "ipfs://test",
            isActive: true
        });

        vm.prank(seller1);
        address propertyTokenAddr = factory.createProperty("Test Token", "TEST", property);

        PropertyToken propertyToken = PropertyToken(propertyTokenAddr);

        // Investor tries to distribute (should fail)
        vm.startPrank(investor);
        usdc.approve(address(propertyToken), 1000 * 1e6);
        vm.expectRevert();
        propertyToken.distributeRevenue(1000 * 1e6, "Unauthorized");
        vm.stopPrank();
    }

    // ===== Helper Functions =====
    function _createTestProperty(address seller, uint256 propertyId) internal returns (address) {
        PropertyToken.PropertyInfo memory property = PropertyToken.PropertyInfo({
            propertyId: propertyId,
            name: "Test Property",
            location: "Test Location",
            totalValue: 100000 * 1e6,
            expectedMonthlyIncome: 1000 * 1e6,
            metadataURI: "ipfs://test",
            isActive: true
        });

        vm.prank(seller);
        return factory.createProperty("Test Token", "TEST", property);
    }
}
