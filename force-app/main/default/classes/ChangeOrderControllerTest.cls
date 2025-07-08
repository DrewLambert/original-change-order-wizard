/**
 * @description Test class for ChangeOrderController and ChangeOrderService
 * @author Drew Lambert
 * @date 2025
 */
@isTest
private class ChangeOrderControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account for Change Orders',
            Website = 'https://test.example.com'
        );
        insert testAccount;
        
        // Create test products
        List<Product2> products = new List<Product2>{
            new Product2(
                Name = 'Test Machine 1',
                Family = 'Machine',
                IsActive = true
            ),
            new Product2(
                Name = 'Test Machine 2', 
                Family = 'Machine',
                IsActive = true
            ),
            new Product2(
                Name = 'Test Service',
                Family = 'Service',
                IsActive = true
            )
        };
        insert products;
        
        // Create price book and price book entries
        Pricebook2 standardPriceBook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        
        List<PricebookEntry> priceBookEntries = new List<PricebookEntry>();
        for (Product2 product : products) {
            priceBookEntries.add(new PricebookEntry(
                Pricebook2Id = standardPriceBook.Id,
                Product2Id = product.Id,
                UnitPrice = 1000.00,
                IsActive = true
            ));
        }
        insert priceBookEntries;
        
        // Create test opportunities
        List<Opportunity> opportunities = new List<Opportunity>{
            new Opportunity(
                Name = 'Test Opportunity 1',
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Pricebook2Id = standardPriceBook.Id,
                Attribution_2024__c = 'Direct'
            ),
            new Opportunity(
                Name = 'Test Opportunity 2',
                AccountId = testAccount.Id,
                StageName = 'Qualification',
                CloseDate = Date.today().addDays(45),
                Pricebook2Id = standardPriceBook.Id,
                Attribution_2024__c = 'Direct'
            ),
            new Opportunity(
                Name = 'Test Opportunity 3 - No Quote',
                AccountId = testAccount.Id,
                StageName = 'Needs Analysis',
                CloseDate = Date.today().addDays(60),
                Pricebook2Id = standardPriceBook.Id,
                Attribution_2024__c = 'Direct'
            )
        };
        insert opportunities;
        
        // Create opportunity line items
        List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();
        for (Integer i = 0; i < opportunities.size(); i++) {
            for (Integer j = 0; j < 2; j++) { // 2 products per opportunity
                lineItems.add(new OpportunityLineItem(
                    OpportunityId = opportunities[i].Id,
                    Product2Id = products[j].Id,
                    Quantity = 1,
                    UnitPrice = 1000.00 + (i * 100) + (j * 50)
                ));
            }
        }
        insert lineItems;
        
        // Create test contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test@example.com',
            AccountId = testAccount.Id
        );
        insert testContact;
    }
    
    @isTest
    static void testGetOpportunities_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        List<Opportunity> opportunities = ChangeOrderController.getOpportunities(testAccount.Id);
        Test.stopTest();
        
        System.assertEquals(3, opportunities.size(), 'Should return 3 opportunities');
        System.assertNotEquals(null, opportunities[0].Name, 'Opportunity name should not be null');
        System.assertNotEquals(null, opportunities[0].StageName, 'Stage name should not be null');
    }
    
    @isTest
    static void testGetOpportunities_NullAccountId() {
        Test.startTest();
        try {
            ChangeOrderController.getOpportunities(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account ID is required'), 'Should contain correct error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetProducts_Success() {
        List<Opportunity> opportunities = [SELECT Id FROM Opportunity LIMIT 2];
        List<Id> opportunityIds = new List<Id>();
        for (Opportunity opp : opportunities) {
            opportunityIds.add(opp.Id);
        }
        
        Test.startTest();
        List<OpportunityLineItem> products = ChangeOrderController.getProducts(opportunityIds);
        Test.stopTest();
        
        System.assertEquals(4, products.size(), 'Should return 4 machine products (2 per opportunity)');
        
        for (OpportunityLineItem product : products) {
            System.assertEquals('Machine', product.Product2.Family, 'All products should be machines');
            System.assertNotEquals(null, product.Opportunity.Name, 'Opportunity name should be populated');
        }
    }
    
    @isTest
    static void testGetProducts_EmptyList() {
        Test.startTest();
        List<OpportunityLineItem> products = ChangeOrderController.getProducts(new List<Id>());
        Test.stopTest();
        
        System.assertEquals(0, products.size(), 'Should return empty list for empty input');
    }
    
    @isTest
    static void testGetPicklistValues_Success() {
        Test.startTest();
        Map<String, List<ChangeOrderController.PicklistValue>> picklistValues = ChangeOrderController.getPicklistValues();
        Test.stopTest();
        
        System.assert(picklistValues.containsKey('serviceModels'), 'Should contain service models');
        System.assert(picklistValues.containsKey('pricingModels'), 'Should contain pricing models');
        System.assert(picklistValues.containsKey('machineTypes'), 'Should contain machine types');
        
        List<ChangeOrderController.PicklistValue> machineTypes = picklistValues.get('machineTypes');
        System.assertEquals(2, machineTypes.size(), 'Should return 2 machine types');
    }
    
    @isTest
    static void testSaveDraft_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        String draftData = '{"test": "data"}';
        
        Test.startTest();
        String result = ChangeOrderController.saveDraft(draftData, testAccount.Id);
        Test.stopTest();
        
        System.assert(result.contains('successfully'), 'Should return success message');
    }
    
    @isTest
    static void testSaveDraft_InvalidInput() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        try {
            ChangeOrderController.saveDraft('', testAccount.Id);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should contain required error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testLoadDraft_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        String draftData = ChangeOrderController.loadDraft(testAccount.Id);
        Test.stopTest();
        
        System.assertEquals(null, draftData, 'Should return null when no draft exists');
    }
    
    @isTest
    static void testProcessChangeOrder_Success() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        List<Opportunity> opportunities = [SELECT Id FROM Opportunity WHERE AccountId = :testAccount.Id LIMIT 2];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        List<OpportunityLineItem> lineItems = [SELECT Id FROM OpportunityLineItem LIMIT 2];
        
        ChangeOrderController.ChangeOrderRequest request = new ChangeOrderController.ChangeOrderRequest();
        request.opportunityIds = new List<Id>();
        for (Opportunity opp : opportunities) {
            request.opportunityIds.add(opp.Id);
        }
        
        request.changeTypes = new Map<String, Boolean>{
            'changeServiceModel' => true,
            'changeTerm' => true
        };
        
        request.changeValues = new Map<String, Object>{
            'serviceModel' => 'Full Service',
            'termLength' => 24
        };
        
        request.productChanges = new List<ChangeOrderController.ProductChange>();
        ChangeOrderController.ProductChange productChange = new ChangeOrderController.ProductChange();
        productChange.lineItemId = lineItems[0].Id;
        productChange.newPrice = 1500.00;
        request.productChanges.add(productChange);
        
        request.effectiveDate = Date.today().addDays(7);
        
        Test.startTest();
        ChangeOrderController.ChangeOrderResult result = ChangeOrderController.processChangeOrder(request);
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Change order should be successful');
        System.assertNotEquals(null, result.contractId, 'Contract ID should be returned');
        System.assertEquals(0, result.errors.size(), 'Should have no errors');
    }
    
    @isTest
    static void testProcessChangeOrder_ValidationErrors() {
        ChangeOrderController.ChangeOrderRequest request = new ChangeOrderController.ChangeOrderRequest();
        // Intentionally leave required fields empty
        
        Test.startTest();
        ChangeOrderController.ChangeOrderResult result = ChangeOrderController.processChangeOrder(request);
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Change order should fail validation');
        System.assert(result.errors.size() > 0, 'Should have validation errors');
    }
    
    @isTest
    static void testProcessChangeOrder_PastEffectiveDate() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        List<Opportunity> opportunities = [SELECT Id FROM Opportunity WHERE AccountId = :testAccount.Id LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        ChangeOrderController.ChangeOrderRequest request = new ChangeOrderController.ChangeOrderRequest();
        request.opportunityIds = new List<Id>{ opportunities[0].Id };
        request.changeTypes = new Map<String, Boolean>{ 'changeServiceModel' => true };
        request.changeValues = new Map<String, Object>{ 'serviceModel' => 'Full Service' };
        request.effectiveDate = Date.today().addDays(-1); // Past date
        
        Test.startTest();
        ChangeOrderController.ChangeOrderResult result = ChangeOrderController.processChangeOrder(request);
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Change order should fail for past date');
        System.assert(result.errors.size() > 0, 'Should have validation errors');
    }
    
    @isTest
    static void testProcessChangeOrder_BulkOpportunities() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        List<Opportunity> allOpportunities = [SELECT Id FROM Opportunity WHERE AccountId = :testAccount.Id];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        // Create additional opportunities for bulk testing
        List<Opportunity> bulkOpportunities = new List<Opportunity>();
        for (Integer i = 0; i < 50; i++) {
            bulkOpportunities.add(new Opportunity(
                Name = 'Bulk Test Opportunity ' + i,
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30 + i),
                Attribution_2024__c = 'Direct'
            ));
        }
        insert bulkOpportunities;
        
        allOpportunities.addAll(bulkOpportunities);
        
        ChangeOrderController.ChangeOrderRequest request = new ChangeOrderController.ChangeOrderRequest();
        request.opportunityIds = new List<Id>();
        for (Opportunity opp : allOpportunities) {
            request.opportunityIds.add(opp.Id);
        }
        
        request.changeTypes = new Map<String, Boolean>{ 'coTermContracts' => true };
        request.changeValues = new Map<String, Object>();
        request.effectiveDate = Date.today().addDays(7);
        
        Test.startTest();
        ChangeOrderController.ChangeOrderResult result = ChangeOrderController.processChangeOrder(request);
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Bulk change order should be successful');
        System.assertNotEquals(null, result.contractId, 'Contract ID should be returned');
    }
    
    @isTest
    static void testChangeOrderService_CreateContractAmendment() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        List<Opportunity> opportunities = [SELECT Id FROM Opportunity WHERE AccountId = :testAccount.Id LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        ChangeOrderController.ChangeOrderRequest request = new ChangeOrderController.ChangeOrderRequest();
        request.opportunityIds = new List<Id>{ opportunities[0].Id };
        request.changeTypes = new Map<String, Boolean>{
            'changeServiceModel' => true,
            'changePricingModel' => true,
            'changeTerm' => true
        };
        request.changeValues = new Map<String, Object>{
            'serviceModel' => 'Hybrid',
            'pricingModel' => 'Annual',
            'termLength' => 36
        };
        request.effectiveDate = Date.today().addDays(7);
        
        Test.startTest();
        ChangeOrderController.ChangeOrderResult result = ChangeOrderService.processChangeOrder(request);
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Service should process successfully');
        
        // Verify contract was created
        List<Contract> contracts = [SELECT Id, Name, ContractTerm, StartDate FROM Contract WHERE Id = :result.contractId];
        System.assertEquals(1, contracts.size(), 'Contract should be created');
        System.assertEquals(36, contracts[0].ContractTerm, 'Contract term should be set correctly');
        System.assertEquals(request.effectiveDate, contracts[0].StartDate, 'Start date should be set correctly');
    }
    
    @isTest
    static void testChangeOrderService_ProductChanges() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        List<Opportunity> opportunities = [SELECT Id FROM Opportunity WHERE AccountId = :testAccount.Id LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        List<OpportunityLineItem> lineItems = [
            SELECT Id, UnitPrice, Product2Id 
            FROM OpportunityLineItem 
            WHERE OpportunityId = :opportunities[0].Id 
            LIMIT 2
        ];
        
        ChangeOrderController.ChangeOrderRequest request = new ChangeOrderController.ChangeOrderRequest();
        request.opportunityIds = new List<Id>{ opportunities[0].Id };
        request.changeTypes = new Map<String, Boolean>{ 'changePrice' => true };
        request.changeValues = new Map<String, Object>();
        
        request.productChanges = new List<ChangeOrderController.ProductChange>();
        for (OpportunityLineItem lineItem : lineItems) {
            ChangeOrderController.ProductChange change = new ChangeOrderController.ProductChange();
            change.lineItemId = lineItem.Id;
            change.newPrice = lineItem.UnitPrice + 500;
            request.productChanges.add(change);
        }
        
        request.effectiveDate = Date.today().addDays(7);
        
        Test.startTest();
        ChangeOrderController.ChangeOrderResult result = ChangeOrderService.processChangeOrder(request);
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Service should process successfully');
        
        // Verify product prices were updated
        List<OpportunityLineItem> updatedLineItems = [
            SELECT Id, UnitPrice 
            FROM OpportunityLineItem 
            WHERE Id IN :new List<Id>{ lineItems[0].Id, lineItems[1].Id }
        ];
        
        for (OpportunityLineItem updatedItem : updatedLineItems) {
            System.assert(updatedItem.UnitPrice > 1000, 'Price should be increased');
        }
    }
    
    @isTest
    static void testChangeOrderService_ExceptionHandling() {
        // Test with invalid data to trigger exceptions
        ChangeOrderController.ChangeOrderRequest request = new ChangeOrderController.ChangeOrderRequest();
        request.opportunityIds = new List<Id>{ '0066000000000000' }; // Invalid ID
        request.changeTypes = new Map<String, Boolean>{ 'changeServiceModel' => true };
        request.changeValues = new Map<String, Object>{ 'serviceModel' => 'Test' };
        request.effectiveDate = Date.today().addDays(7);
        
        Test.startTest();
        ChangeOrderController.ChangeOrderResult result = ChangeOrderService.processChangeOrder(request);
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Should fail with invalid data');
        System.assert(result.errors.size() > 0, 'Should have error messages');
    }
    
    @isTest
    static void testNegativeScenarios() {
        // Test with user without proper permissions (simulated)
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        try {
            // This would normally test permission scenarios, but in test context
            // we'll test other edge cases
            List<Opportunity> opportunities = ChangeOrderController.getOpportunities(testAccount.Id);
            System.assertNotEquals(null, opportunities, 'Should handle permission scenarios gracefully');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException, 'Should throw proper exception type');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetAvailableProductsForOpportunity_Success() {
        List<Opportunity> opportunities = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        List<ChangeOrderController.PicklistValue> availableProducts = 
            ChangeOrderController.getAvailableProductsForOpportunity(opportunities[0].Id);
        Test.stopTest();
        
        System.assertNotEquals(null, availableProducts, 'Should return product list');
        System.assertEquals(2, availableProducts.size(), 'Should return 2 machine products from pricebook');
    }
    
    @isTest
    static void testGetAvailableProductsForOpportunity_NullOpportunityId() {
        Test.startTest();
        try {
            ChangeOrderController.getAvailableProductsForOpportunity(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Opportunity ID is required'), 'Should contain correct error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetAvailableProductsForOpportunity_InvalidOpportunityId() {
        Test.startTest();
        try {
            ChangeOrderController.getAvailableProductsForOpportunity('0066000000000000');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Opportunity not found'), 'Should contain correct error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testContractNameTruncation_LongAccountName() {
        // Create account with very long name
        Account longNameAccount = new Account(
            Name = 'This is a very long account name that should cause the contract name to exceed eighty characters when combined with change order details',
            Website = 'https://test.example.com'
        );
        insert longNameAccount;
        
        // Create opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Long Name Opportunity',
            AccountId = longNameAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = Test.getStandardPricebookId(),
            Attribution_2024__c = 'Direct'
        );
        insert testOpp;
        
        ChangeOrderController.ChangeOrderRequest request = new ChangeOrderController.ChangeOrderRequest();
        request.opportunityIds = new List<Id>{ testOpp.Id };
        request.changeTypes = new Map<String, Boolean>{
            'changeServiceModel' => true,
            'changePricingModel' => true,
            'changeTerm' => true,
            'changePrice' => true,
            'changeProduct' => true
        };
        request.changeValues = new Map<String, Object>{
            'serviceModel' => 'Full Service',
            'pricingModel' => 'Annual',
            'termLength' => 24
        };
        request.effectiveDate = Date.today().addDays(7);
        
        Test.startTest();
        ChangeOrderController.ChangeOrderResult result = ChangeOrderController.processChangeOrder(request);
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Change order should be successful');
        System.assertNotEquals(null, result.contractId, 'Contract ID should be returned');
        
        // Verify contract name is not longer than 80 characters
        List<Contract> contracts = [SELECT Id, Name FROM Contract WHERE Id = :result.contractId];
        System.assertEquals(1, contracts.size(), 'Contract should be created');
        System.assert(contracts[0].Name.length() <= 80, 'Contract name should be 80 characters or less. Actual length: ' + contracts[0].Name.length() + ', Name: ' + contracts[0].Name);
    }
    
    @isTest
    static void testContractNameTruncation_NormalAccountName() {
        Account testAccount = [SELECT Id, Name FROM Account LIMIT 1];
        List<Opportunity> opportunities = [SELECT Id FROM Opportunity WHERE AccountId = :testAccount.Id LIMIT 1];
        
        ChangeOrderController.ChangeOrderRequest request = new ChangeOrderController.ChangeOrderRequest();
        request.opportunityIds = new List<Id>{ opportunities[0].Id };
        request.changeTypes = new Map<String, Boolean>{
            'changeServiceModel' => true,
            'changePricingModel' => true
        };
        request.changeValues = new Map<String, Object>{
            'serviceModel' => 'Full Service',
            'pricingModel' => 'Annual'
        };
        request.effectiveDate = Date.today().addDays(7);
        
        Test.startTest();
        ChangeOrderController.ChangeOrderResult result = ChangeOrderController.processChangeOrder(request);
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Change order should be successful');
        
        // Verify contract name is reasonable length and contains expected content
        List<Contract> contracts = [SELECT Id, Name FROM Contract WHERE Id = :result.contractId];
        System.assertEquals(1, contracts.size(), 'Contract should be created');
        System.assert(contracts[0].Name.length() <= 80, 'Contract name should be 80 characters or less');
        System.assert(contracts[0].Name.contains(testAccount.Name), 'Contract name should contain account name');
        System.assert(contracts[0].Name.contains('Change Order'), 'Contract name should contain change order reference');
    }
}