/**
 * @description Service class for processing change orders
 * @author Drew Lambert
 * @date 2025
 */
public with sharing class ChangeOrderService {
    
    /**
     * @description Processes a change order request and creates all necessary records
     * @param request The change order request
     * @return ChangeOrderResult with success status and created records
     */
    public static ChangeOrderController.ChangeOrderResult processChangeOrder(ChangeOrderController.ChangeOrderRequest request) {
        ChangeOrderController.ChangeOrderResult result = new ChangeOrderController.ChangeOrderResult();
        
        try {
            // Validate the request
            validateRequest(request);
            
            // Create the contract amendment record
            Id contractId = createContractAmendment(request);
            result.contractId = contractId;
            result.createdRecords.put('Contract', contractId);
            
            // Create ContractOpportunityLink records (matches Flow logic)
            List<Id> createdOpportunityLinkIds = createContractOpportunityLinks(request, contractId);
            System.debug('Created ' + createdOpportunityLinkIds.size() + ' ContractOpportunityLink records');
            
            // Process opportunity changes
            List<Id> updatedOpportunityIds = processOpportunityChanges(request);
            System.debug('Updated ' + updatedOpportunityIds.size() + ' opportunities');
            
            // Process product changes if any
            if (request.productChanges != null && !request.productChanges.isEmpty()) {
                List<Id> updatedProductIds = processProductChanges(request.productChanges, contractId);
                System.debug('Updated ' + updatedProductIds.size() + ' products');
            }
            
            // Create Contract_Line_Item_Link records if product/price changes are involved
            if ((request.changeTypes.get('changeProduct') == true || request.changeTypes.get('changePrice') == true) 
                && request.productChanges != null && !request.productChanges.isEmpty()) {
                List<Id> createdLineItemLinkIds = createContractLineItemLinks(request, contractId);
                System.debug('Created ' + createdLineItemLinkIds.size() + ' ContractLineItemLink records');
            }
            
            // Create tasks for follow-up
            List<Id> taskIds = createFollowUpTasks(request, contractId);
            System.debug('Created ' + taskIds.size() + ' follow-up tasks');
            
            
            result.success = true;
            
        } catch (Exception e) {
            System.debug('Error in processChangeOrder: ' + e.getMessage());
            System.debug('Exception type: ' + e.getTypeName());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Provide more specific error message
            String errorMessage = e.getMessage();
            if (errorMessage.contains('Invalid id:')) {
                errorMessage = 'ID format error: ' + errorMessage + '. This may be due to a validation rule or automation.';
            }
            
            result.errors.add(errorMessage);
            result.success = false;
        }
        
        return result;
    }
    
    /**
     * @description Validates the change order request
     * @param request The request to validate
     */
    private static void validateRequest(ChangeOrderController.ChangeOrderRequest request) {
        System.debug('Validating request with opportunityIds: ' + request.opportunityIds);
        System.debug('OpportunityIds size: ' + (request.opportunityIds != null ? request.opportunityIds.size() : 0));
        
        if (request.opportunityIds == null || request.opportunityIds.isEmpty()) {
            throw new ChangeOrderException('At least one opportunity must be selected');
        }
        
        // Validate that all opportunity IDs are valid format
        for (Id oppId : request.opportunityIds) {
            String oppIdString = String.valueOf(oppId);
            if (oppIdString == null || (!oppIdString.startsWith('006') || (oppIdString.length() != 15 && oppIdString.length() != 18))) {
                throw new ChangeOrderException('Invalid opportunity ID format: ' + oppIdString);
            }
        }
        
        // Critical validation: Check that all opportunities have Quote_Number__c (matches Flow logic)
        List<Opportunity> qualifiedOpps = [
            SELECT Id, Name, Quote_Number__c, AccountId
            FROM Opportunity 
            WHERE Id IN :request.opportunityIds
        ];
        
        if (qualifiedOpps.isEmpty()) {
            throw new ChangeOrderException('No valid opportunities found for the provided IDs');
        }
        
        List<String> oppsWithoutQuotes = new List<String>();
        for (Opportunity opp : qualifiedOpps) {
            if (String.isBlank(opp.Quote_Number__c)) {
                oppsWithoutQuotes.add(opp.Name);
            }
        }
        
        if (!oppsWithoutQuotes.isEmpty()) {
            throw new ChangeOrderException('The following opportunities do not have Quote Numbers and cannot be processed: ' + String.join(oppsWithoutQuotes, ', '));
        }
        
        if (request.changeTypes == null || request.changeTypes.isEmpty()) {
            throw new ChangeOrderException('At least one change type must be selected');
        }
        
        if (request.effectiveDate == null) {
            throw new ChangeOrderException('Effective date is required');
        }
        
        if (request.effectiveDate < Date.today()) {
            throw new ChangeOrderException('Effective date cannot be in the past');
        }
        
        // Validate specific change type requirements
        validateChangeTypeRequirements(request);
    }
    
    /**
     * @description Validates specific requirements for each change type
     * @param request The request to validate
     */
    private static void validateChangeTypeRequirements(ChangeOrderController.ChangeOrderRequest request) {
        Map<String, Object> changeValues = request.changeValues;
        
        if (request.changeTypes.get('changeServiceModel') == true) {
            if (changeValues.get('serviceModel') == null) {
                throw new ChangeOrderException('Service Model is required when Change Service Model is selected');
            }
        }
        
        if (request.changeTypes.get('changePricingModel') == true) {
            if (changeValues.get('pricingModel') == null) {
                throw new ChangeOrderException('Pricing Model is required when Change Pricing Model is selected');
            }
        }
        
        if (request.changeTypes.get('changeTerm') == true) {
            if (changeValues.get('termLength') == null) {
                throw new ChangeOrderException('Term Length is required when Change Term is selected');
            }
        }
        
        if (request.changeTypes.get('addAbatement') == true) {
            if (changeValues.get('abatementPeriod') == null) {
                throw new ChangeOrderException('Abatement Period is required when Add Abatement is selected');
            }
        }
    }
    
    /**
     * @description Creates ContractOpportunityLink records for each qualified opportunity
     * @param request The change order request
     * @param contractId The created contract ID
     * @return List of created ContractOpportunityLink IDs
     */
    private static List<Id> createContractOpportunityLinks(ChangeOrderController.ChangeOrderRequest request, Id contractId) {
        List<Id> createdLinkIds = new List<Id>();
        
        try {
            // Check permissions for ContractOpportunityLink creation
            if (!Schema.sObjectType.ContractOpportunityLink__c.isCreateable()) {
                throw new ChangeOrderException('You do not have permission to create contract opportunity links');
            }
            
            // Get opportunities with Quote_Number__c (already validated in validateRequest)
            List<Opportunity> qualifiedOpps = [
                SELECT Id, Quote_Number__c, Service_Model__c, Name, Account.Name
                FROM Opportunity 
                WHERE Id IN :request.opportunityIds
                AND Quote_Number__c != null
            ];
            
            List<ContractOpportunityLink__c> linksToCreate = new List<ContractOpportunityLink__c>();
            
            // Collect unique quote numbers for the Quote_Order_Numbers__c field (limit to 255 chars)
            Set<String> uniqueQuoteNumbers = new Set<String>();
            for (Opportunity opp : qualifiedOpps) {
                if (String.isNotBlank(opp.Quote_Number__c)) {
                    uniqueQuoteNumbers.add(opp.Quote_Number__c);
                }
            }
            String quoteOrderNumbers = String.join(new List<String>(uniqueQuoteNumbers), ', ');
            
            // Truncate if too long for the field (max 255 characters)
            if (quoteOrderNumbers.length() > 255) {
                quoteOrderNumbers = quoteOrderNumbers.substring(0, 252) + '...';
            }
            
            // Create a link record for each qualified opportunity (matches Flow logic)
            for (Opportunity opp : qualifiedOpps) {
                ContractOpportunityLink__c link = new ContractOpportunityLink__c();
                link.Contract__c = contractId;
                link.Opportunity__c = opp.Id;
                
                // Set service model values from request
                if (request.changeTypes.get('changeServiceModel') == true && request.changeValues.get('serviceModel') != null) {
                    link.New_Service_Model__c = String.valueOf(request.changeValues.get('serviceModel'));
                }
                
                // Set pricing model values from request  
                if (request.changeTypes.get('changePricingModel') == true && request.changeValues.get('pricingModel') != null) {
                    link.New_Pricing_Model__c = String.valueOf(request.changeValues.get('pricingModel'));
                }
                
                // Set Quote Order Numbers (matches Flow Col_UniqueQuoteOppIDs logic)
                link.Quote_Order_Numbers__c = quoteOrderNumbers;
                
                // Note: Effective_Date__c is a formula field and cannot be set directly
                
                linksToCreate.add(link);
            }
            
            if (!linksToCreate.isEmpty()) {
                insert linksToCreate;
                for (ContractOpportunityLink__c link : linksToCreate) {
                    createdLinkIds.add(link.Id);
                }
            }
            
            System.debug('Created ' + linksToCreate.size() + ' ContractOpportunityLink records');
            
        } catch (DmlException e) {
            throw new ChangeOrderException('Failed to create contract opportunity links: ' + e.getDmlMessage(0));
        }
        
        return createdLinkIds;
    }
    
    /**
     * @description Creates Contract_Line_Item_Link records for product changes
     * @param request The change order request
     * @param contractId The created contract ID
     * @return List of created Contract_Line_Item_Link IDs
     */
    private static List<Id> createContractLineItemLinks(ChangeOrderController.ChangeOrderRequest request, Id contractId) {
        List<Id> createdLinkIds = new List<Id>();
        
        try {
            // Check permissions for Contract_Line_Item_Link creation
            if (!Schema.sObjectType.Contract_Line_Item_Link__c.isCreateable()) {
                throw new ChangeOrderException('You do not have permission to create contract line item links');
            }
            
            // Get product names for the line items and new products
            Map<Id, String> lineItemToProductName = new Map<Id, String>();
            Map<Id, String> productIdToName = new Map<Id, String>();
            
            Set<Id> lineItemIds = new Set<Id>();
            Set<Id> newProductIds = new Set<Id>();
            
            for (ChangeOrderController.ProductChange productChange : request.productChanges) {
                if (productChange.lineItemId != null) {
                    lineItemIds.add(productChange.lineItemId);
                }
                if (String.isNotBlank(productChange.newProduct)) {
                    newProductIds.add(productChange.newProduct);
                }
            }
            
            // Query OpportunityLineItems to get current product names
            if (!lineItemIds.isEmpty()) {
                List<OpportunityLineItem> lineItems = [
                    SELECT Id, Product2.Name
                    FROM OpportunityLineItem 
                    WHERE Id IN :lineItemIds
                ];
                
                for (OpportunityLineItem lineItem : lineItems) {
                    lineItemToProductName.put(lineItem.Id, lineItem.Product2.Name);
                }
            }
            
            // Query Products to get new product names
            if (!newProductIds.isEmpty()) {
                List<Product2> products = [
                    SELECT Id, Name
                    FROM Product2 
                    WHERE Id IN :newProductIds
                ];
                
                for (Product2 product : products) {
                    productIdToName.put(product.Id, product.Name);
                }
            }
            
            List<Contract_Line_Item_Link__c> linksToCreate = new List<Contract_Line_Item_Link__c>();
            
            // Create a link record for each product change (matches Flow logic)
            for (ChangeOrderController.ProductChange productChange : request.productChanges) {
                Contract_Line_Item_Link__c link = new Contract_Line_Item_Link__c();
                link.Contract__c = contractId;
                
                // Set line item reference (this will populate the formula fields)
                if (productChange.lineItemId != null) {
                    link.Line_Item__c = productChange.lineItemId;
                    
                    // Set current machine type using product name from line item
                    String currentProductName = lineItemToProductName.get(productChange.lineItemId);
                    if (String.isNotBlank(currentProductName)) {
                        link.Type_of_Machine__c = currentProductName;
                    }
                }
                
                // Set new machine type using product name (not ID)
                if (String.isNotBlank(productChange.newProduct)) {
                    String newProductName = productIdToName.get(productChange.newProduct);
                    if (String.isNotBlank(newProductName)) {
                        link.New_Machine_Type__c = newProductName;
                    }
                }
                
                // Set new rate if changing price
                if (productChange.newPrice != null) {
                    link.New_Rate__c = productChange.newPrice;
                }
                
                // Set service model from change request
                if (request.changeTypes.get('changeServiceModel') == true && request.changeValues.get('serviceModel') != null) {
                    link.New_Service_Model__c = String.valueOf(request.changeValues.get('serviceModel'));
                }
                
                // Note: Machine_Type__c and Serial_Number__c are formula fields and cannot be set directly
                
                linksToCreate.add(link);
            }
            
            if (!linksToCreate.isEmpty()) {
                insert linksToCreate;
                for (Contract_Line_Item_Link__c link : linksToCreate) {
                    createdLinkIds.add(link.Id);
                }
            }
            
            System.debug('Created ' + linksToCreate.size() + ' Contract_Line_Item_Link records');
            
        } catch (DmlException e) {
            throw new ChangeOrderException('Failed to create contract line item links: ' + e.getDmlMessage(0));
        }
        
        return createdLinkIds;
    }
    
    /**
     * @description Creates a contract amendment record
     * @param request The change order request
     * @return Id of the created contract
     */
    private static Id createContractAmendment(ChangeOrderController.ChangeOrderRequest request) {
        try {
            // Check permissions for Contract creation
            if (!Schema.sObjectType.Contract.isCreateable()) {
                throw new ChangeOrderException('You do not have permission to create contracts');
            }
            
            // Get the account from the first opportunity
            System.debug('About to query opportunities with IDs: ' + request.opportunityIds);
            System.debug('OpportunityIds in query: ' + JSON.serialize(request.opportunityIds));
            
            List<Opportunity> opportunities = [
                SELECT AccountId, Account.Name 
                FROM Opportunity 
                WHERE Id IN :request.opportunityIds 
                LIMIT 1
            ];
            
            if (opportunities.isEmpty()) {
                throw new ChangeOrderException('No valid opportunities found');
            }
            
            Opportunity firstOpp = opportunities[0];
            
            Contract contract = new Contract();
            contract.AccountId = firstOpp.AccountId;
            contract.Status = 'Draft';
            contract.StartDate = request.effectiveDate;
            contract.ContractTerm = 12; // Default term
            
            // Set all change type boolean fields (matches Flow logic)
            if (request.changeTypes.containsKey('changeServiceModel')) {
                contract.put('Change_Service__c', request.changeTypes.get('changeServiceModel'));
            }
            if (request.changeTypes.containsKey('changePricingModel')) {
                contract.put('Change_Pricing_Model__c', request.changeTypes.get('changePricingModel'));
            }
            if (request.changeTypes.containsKey('changeTerm')) {
                contract.put('Change_Term__c', request.changeTypes.get('changeTerm'));
            }
            if (request.changeTypes.containsKey('changePrice')) {
                contract.put('Change_Price__c', request.changeTypes.get('changePrice'));
            }
            if (request.changeTypes.containsKey('changeProduct')) {
                contract.put('Change_Product__c', request.changeTypes.get('changeProduct'));
            }
            if (request.changeTypes.containsKey('addAbatement')) {
                contract.put('Abatement__c', request.changeTypes.get('addAbatement'));
            }
            if (request.changeTypes.containsKey('coTermContracts')) {
                contract.put('Co_Term__c', request.changeTypes.get('coTermContracts'));
            }
            
            // Set contract name based on change types
            List<String> changeTypeLabels = new List<String>();
            if (request.changeTypes.get('changeServiceModel') == true) changeTypeLabels.add('Service Model');
            if (request.changeTypes.get('changePricingModel') == true) changeTypeLabels.add('Pricing Model');
            if (request.changeTypes.get('changeTerm') == true) changeTypeLabels.add('Term');
            if (request.changeTypes.get('changePrice') == true) changeTypeLabels.add('Price');
            if (request.changeTypes.get('changeProduct') == true) changeTypeLabels.add('Product');
            if (request.changeTypes.get('addAbatement') == true) changeTypeLabels.add('Abatement');
            if (request.changeTypes.get('coTermContracts') == true) changeTypeLabels.add('Co-Term');
            
            String changeTypesString = String.join(changeTypeLabels, ', ');
            String baseContractName = firstOpp.Account.Name + ' - Change Order: ' + changeTypesString;
            
            // Ensure contract name is never greater than 80 characters
            if (baseContractName.length() > 80) {
                // Try with abbreviated change types first
                List<String> abbreviatedLabels = new List<String>();
                if (request.changeTypes.get('changeServiceModel') == true) abbreviatedLabels.add('Service');
                if (request.changeTypes.get('changePricingModel') == true) abbreviatedLabels.add('Pricing');
                if (request.changeTypes.get('changeTerm') == true) abbreviatedLabels.add('Term');
                if (request.changeTypes.get('changePrice') == true) abbreviatedLabels.add('Price');
                if (request.changeTypes.get('changeProduct') == true) abbreviatedLabels.add('Product');
                if (request.changeTypes.get('addAbatement') == true) abbreviatedLabels.add('Abatement');
                if (request.changeTypes.get('coTermContracts') == true) abbreviatedLabels.add('Co-Term');
                
                String abbreviatedString = String.join(abbreviatedLabels, ', ');
                baseContractName = firstOpp.Account.Name + ' - CO: ' + abbreviatedString;
                
                // If still too long, truncate account name
                if (baseContractName.length() > 80) {
                    String suffix = ' - CO: ' + abbreviatedString;
                    Integer maxAccountNameLength = 80 - suffix.length();
                    
                    if (maxAccountNameLength > 0) {
                        String truncatedAccountName = firstOpp.Account.Name.length() > maxAccountNameLength 
                            ? firstOpp.Account.Name.substring(0, maxAccountNameLength - 3) + '...'
                            : firstOpp.Account.Name;
                        baseContractName = truncatedAccountName + suffix;
                    } else {
                        // Final fallback - just use account name truncated
                        baseContractName = firstOpp.Account.Name.length() > 77 
                            ? firstOpp.Account.Name.substring(0, 77) + '...'
                            : firstOpp.Account.Name + ' - CO';
                    }
                }
            }
            
            contract.Name = baseContractName;
            
            // Set new value fields based on change types and values (matches Flow logic)
            if (request.changeTypes.get('changeTerm') == true && request.changeValues.get('termLength') != null) {
                contract.ContractTerm = Integer.valueOf(request.changeValues.get('termLength'));
            }
            
            if (request.changeTypes.get('changeServiceModel') == true && request.changeValues.get('serviceModel') != null) {
                contract.put('New_Service_Model__c', String.valueOf(request.changeValues.get('serviceModel')));
            }
            
            if (request.changeTypes.get('changePricingModel') == true && request.changeValues.get('pricingModel') != null) {
                contract.put('New_Pricing_Model__c', String.valueOf(request.changeValues.get('pricingModel')));
            }
            
            if (request.changeTypes.get('addAbatement') == true && request.changeValues.get('abatementPeriod') != null) {
                contract.put('Abatement_Period__c', Integer.valueOf(request.changeValues.get('abatementPeriod')));
            }
            
            if (request.changeTypes.get('changeTerm') == true && request.changeValues.get('renewalTerm') != null) {
                contract.put('Renewal_Term__c', Integer.valueOf(request.changeValues.get('renewalTerm')));
            }
            
            if (request.changeTypes.get('changeTerm') == true && request.changeValues.get('optOutDays') != null) {
                contract.put('Contract_Opt_out_Days__c', Integer.valueOf(request.changeValues.get('optOutDays')));
            }
            
            // Set contact fields if provided (matches Flow logic)
            if (request.changeValues.get('salesContact') != null) {
                contract.put('Sales_Contact__c', String.valueOf(request.changeValues.get('salesContact')));
            }
            
            if (request.changeValues.get('docusignContact') != null) {
                contract.put('Docusign_Contact__c', String.valueOf(request.changeValues.get('docusignContact')));
            }
            
            insert contract;
            
            System.debug('Created contract: ' + contract.Id);
            return contract.Id;
            
        } catch (DmlException e) {
            throw new ChangeOrderException('Failed to create contract: ' + e.getDmlMessage(0));
        }
    }
    
    /**
     * @description Processes changes to opportunities
     * @param request The change order request
     * @return List of updated opportunity IDs
     */
    private static List<Id> processOpportunityChanges(ChangeOrderController.ChangeOrderRequest request) {
        List<Id> opportunityIds = new List<Id>();
        
        // Simply return the opportunity IDs without making any updates
        // Opportunities should not have their stage changed during change order creation
        for (Id oppId : request.opportunityIds) {
            opportunityIds.add(oppId);
        }
        
        System.debug('Referenced ' + opportunityIds.size() + ' opportunities (no updates performed)');
        
        return opportunityIds;
    }
    
    /**
     * @description Processes product changes by creating Contract Line Item Links only
     * Note: OpportunityLineItem.Product2Id is read-only, so we track changes in Contract_Line_Item_Link__c
     * @param productChanges List of product changes
     * @param contractId The contract ID for reference
     * @return List of processed product change IDs
     */
    private static List<Id> processProductChanges(List<ChangeOrderController.ProductChange> productChanges, Id contractId) {
        List<Id> processedIds = new List<Id>();
        
        try {
            // Product changes are handled through Contract_Line_Item_Link__c records
            // OpportunityLineItem.Product2Id is read-only, so we don't update it directly
            // Instead, the Contract_Line_Item_Link__c records track the product changes
            
            for (ChangeOrderController.ProductChange change : productChanges) {
                if (change.lineItemId != null) {
                    // Track that this product change was processed
                    processedIds.add(change.lineItemId);
                    
                    System.debug('Product change tracked for line item: ' + change.lineItemId + 
                               ', Original: ' + change.originalProduct + 
                               ', New: ' + change.newProduct + 
                               ', New Price: ' + change.newPrice);
                }
            }
            
            System.debug('Processed ' + processedIds.size() + ' product changes (tracked in Contract_Line_Item_Link__c records)');
            
        } catch (Exception e) {
            throw new ChangeOrderException('Failed to process product changes: ' + e.getMessage());
        }
        
        return processedIds;
    }
    
    /**
     * @description Creates follow-up tasks for the change order
     * @param request The change order request
     * @param contractId The contract ID
     * @return List of created task IDs
     */
    private static List<Id> createFollowUpTasks(ChangeOrderController.ChangeOrderRequest request, Id contractId) {
        List<Id> taskIds = new List<Id>();
        
        try {
            // Check permissions for Task creation
            if (!Schema.sObjectType.Task.isCreateable()) {
                System.debug('No permission to create tasks, skipping task creation');
                return taskIds;
            }
            
            List<Task> tasksToCreate = new List<Task>();
            
            // Create a task for contract review
            Task reviewTask = new Task();
            reviewTask.Subject = 'Review Change Order Contract';
            reviewTask.Description = 'Review and approve the change order contract for processing';
            reviewTask.WhatId = contractId;
            reviewTask.ActivityDate = Date.today().addDays(1);
            reviewTask.Priority = 'High';
            reviewTask.Status = 'Not Started';
            tasksToCreate.add(reviewTask);
            
            
            if (!tasksToCreate.isEmpty()) {
                insert tasksToCreate;
                for (Task t : tasksToCreate) {
                    taskIds.add(t.Id);
                }
            }
            
            System.debug('Created ' + tasksToCreate.size() + ' follow-up tasks');
            
        } catch (DmlException e) {
            System.debug('Failed to create tasks: ' + e.getDmlMessage(0));
            // Don't throw exception for task creation failure
        }
        
        return taskIds;
    }
    
    
    /**
     * @description Custom exception class for change order processing
     */
    public class ChangeOrderException extends Exception {}
}