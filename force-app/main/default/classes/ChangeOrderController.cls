/**
 * @description Controller class for Change Order LWC components
 * @author Drew Lambert
 * @date 2025
 */
public with sharing class ChangeOrderController {
    
    /**
     * @description Retrieves opportunities related to an account with Quote_Number__c populated
     * @param accountId The ID of the account
     * @return List of opportunities
     */
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities(Id accountId) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }
            
            // Check FLS and CRUD permissions
            if (!Schema.sObjectType.Opportunity.isAccessible()) {
                throw new AuraHandledException('You do not have permission to access Opportunities');
            }
            
            List<String> fieldsToCheck = new List<String>{
                'Name', 'CloseDate', 'StageName', 'AccountId', 'Amount', 'Quote_Number__c'
            };
            
            for (String field : fieldsToCheck) {
                if (!Schema.sObjectType.Opportunity.fields.getMap().get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('You do not have permission to access Opportunity.' + field);
                }
            }
            
            return [
                SELECT Id, Name, CloseDate, StageName, AccountId, Amount, Quote_Number__c
                FROM Opportunity 
                WHERE AccountId = :accountId 
                    AND IsClosed = false
                    AND Quote_Number__c != null
                ORDER BY CloseDate ASC, Name ASC
                LIMIT 200
            ];
            
        } catch (Exception e) {
            System.debug('Error in getOpportunities: ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve opportunities: ' + e.getMessage());
        }
    }
    
    /**
     * @description Saves draft change order data
     * @param draftData JSON string containing draft data
     * @param accountId The ID of the account
     * @return String confirmation message
     */
    @AuraEnabled
    public static String saveDraft(String draftData, Id accountId) {
        try {
            if (String.isBlank(draftData) || accountId == null) {
                throw new AuraHandledException('Draft data and Account ID are required');
            }
            
            // Create or update draft record (could use custom object or custom setting)
            // For this example, we'll use a simple approach with a custom setting
            
            // Note: In a real implementation, you would create a custom object to store drafts
            // This is a simplified version using static resource or custom metadata
            
            System.debug('Draft saved for account: ' + accountId);
            return 'Draft saved successfully';
            
        } catch (Exception e) {
            System.debug('Error in saveDraft: ' + e.getMessage());
            throw new AuraHandledException('Failed to save draft: ' + e.getMessage());
        }
    }
    
    /**
     * @description Loads existing draft change order data
     * @param accountId The ID of the account
     * @return String JSON data or null if no draft exists
     */
    @AuraEnabled(cacheable=true)
    public static String loadDraft(Id accountId) {
        try {
            if (accountId == null) {
                throw new AuraHandledException('Account ID is required');
            }
            
            // Load draft from custom object or setting
            // This is a placeholder implementation
            
            System.debug('Loading draft for account: ' + accountId);
            return null; // No draft found
            
        } catch (Exception e) {
            System.debug('Error in loadDraft: ' + e.getMessage());
            throw new AuraHandledException('Failed to load draft: ' + e.getMessage());
        }
    }
    
    /**
     * @description Retrieves products from selected opportunities where Product_Family__c = 'Machine'
     * @param opportunityIds List of opportunity IDs
     * @return List of OpportunityLineItems with related data
     */
    @AuraEnabled(cacheable=true)
    public static List<OpportunityLineItem> getProducts(List<Id> opportunityIds) {
        try {
            if (opportunityIds == null || opportunityIds.isEmpty()) {
                return new List<OpportunityLineItem>();
            }
            
            // Check FLS and CRUD permissions
            if (!Schema.sObjectType.OpportunityLineItem.isAccessible()) {
                throw new AuraHandledException('You do not have permission to access Opportunity Products');
            }
            
            List<String> fieldsToCheck = new List<String>{
                'Id', 'OpportunityId', 'Product2Id', 'UnitPrice', 'Quantity', 'Recurring_Revenue__c', 'Lease_Rate__c'
            };
            
            for (String field : fieldsToCheck) {
                if (!Schema.sObjectType.OpportunityLineItem.fields.getMap().get(field).getDescribe().isAccessible()) {
                    throw new AuraHandledException('You do not have permission to access OpportunityLineItem.' + field);
                }
            }
            
            return [
                SELECT Id, OpportunityId, Product2Id, UnitPrice, Quantity, Recurring_Revenue__c, Lease_Rate__c,
                       Opportunity.Name,
                       Product2.Name, Product2.Family
                FROM OpportunityLineItem 
                WHERE OpportunityId IN :opportunityIds 
                    AND Product2.Family = 'Machine'
                ORDER BY Opportunity.Name, Product2.Name
                LIMIT 500
            ];
            
        } catch (Exception e) {
            System.debug('Error in getProducts: ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve products: ' + e.getMessage());
        }
    }
    
    /**
     * @description Retrieves picklist values for change order forms
     * @return Map containing picklist values for different fields
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<PicklistValue>> getPicklistValues() {
        try {
            Map<String, List<PicklistValue>> picklistMap = new Map<String, List<PicklistValue>>();
            
            // Service Models (example values - replace with actual field)
            picklistMap.put('serviceModels', new List<PicklistValue>{
                new PicklistValue('Full Service', 'Full Service'),
                new PicklistValue('Self Service', 'Self Service'),
                new PicklistValue('Hybrid', 'Hybrid')
            });
            
            // Pricing Models (example values - replace with actual field)
            picklistMap.put('pricingModels', new List<PicklistValue>{
                new PicklistValue('Monthly', 'Monthly'),
                new PicklistValue('Annual', 'Annual'),
                new PicklistValue('Per Transaction', 'Per Transaction')
            });
            
            // Machine Types - get from Product2 where Family = 'Machine'
            List<PicklistValue> machineTypes = new List<PicklistValue>();
            
            if (Schema.sObjectType.Product2.isAccessible()) {
                List<Product2> machines = [
                    SELECT Id, Name 
                    FROM Product2 
                    WHERE Family = 'Machine' 
                        AND IsActive = true 
                    ORDER BY Name 
                    LIMIT 200
                ];
                
                for (Product2 machine : machines) {
                    machineTypes.add(new PicklistValue(machine.Name, machine.Id));
                }
            }
            
            picklistMap.put('machineTypes', machineTypes);
            
            return picklistMap;
            
        } catch (Exception e) {
            System.debug('Error in getPicklistValues: ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve picklist values: ' + e.getMessage());
        }
    }
    
    /**
     * @description Retrieves active products from the pricebook associated with the opportunity
     * @param opportunityId The ID of the opportunity
     * @return List of PicklistValue objects containing available products
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistValue> getAvailableProductsForOpportunity(Id opportunityId) {
        try {
            if (opportunityId == null) {
                throw new AuraHandledException('Opportunity ID is required');
            }
            
            // Check FLS and CRUD permissions
            if (!Schema.sObjectType.PricebookEntry.isAccessible()) {
                throw new AuraHandledException('You do not have permission to access Pricebook Entries');
            }
            
            // Get the opportunity's pricebook
            List<Opportunity> opportunities = [
                SELECT Pricebook2Id 
                FROM Opportunity 
                WHERE Id = :opportunityId 
                LIMIT 1
            ];
            
            if (opportunities.isEmpty()) {
                throw new AuraHandledException('Opportunity not found');
            }
            
            Id pricebookId = opportunities[0].Pricebook2Id;
            if (pricebookId == null) {
                // Use standard pricebook if no pricebook is set
                pricebookId = Test.getStandardPricebookId();
            }
            
            // Get active pricebook entries for Machine products
            List<PricebookEntry> pricebookEntries = [
                SELECT Product2Id, Product2.Name 
                FROM PricebookEntry 
                WHERE Pricebook2Id = :pricebookId 
                    AND IsActive = true 
                    AND Product2.IsActive = true 
                    AND Product2.Family = 'Machine'
                ORDER BY Product2.Name 
                LIMIT 200
            ];
            
            List<PicklistValue> productOptions = new List<PicklistValue>();
            for (PricebookEntry entry : pricebookEntries) {
                productOptions.add(new PicklistValue(entry.Product2.Name, entry.Product2Id));
            }
            
            return productOptions;
            
        } catch (Exception e) {
            System.debug('Error in getAvailableProductsForOpportunity: ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve available products: ' + e.getMessage());
        }
    }
    
    /**
     * @description Processes the change order request and creates necessary records
     * @param request The change order request containing all data
     * @return ChangeOrderResult with success status and created record IDs
     */
    @AuraEnabled
    public static ChangeOrderResult processChangeOrder(ChangeOrderRequest request) {
        ChangeOrderResult result = new ChangeOrderResult();
        result.success = false;
        result.errors = new List<String>();
        result.createdRecords = new Map<String, Id>();
        
        Savepoint sp = Database.setSavepoint();
        
        try {
            // Validate input
            System.debug('processChangeOrder called with request: ' + JSON.serialize(request));
            
            if (request == null) {
                throw new AuraHandledException('Change order request is required');
            }
            
            System.debug('Request opportunityIds: ' + request.opportunityIds);
            System.debug('Request opportunityIds type: ' + (request.opportunityIds != null ? 'List with ' + request.opportunityIds.size() + ' items' : 'null'));
            
            if (request.opportunityIds == null || request.opportunityIds.isEmpty()) {
                throw new AuraHandledException('At least one opportunity must be selected');
            }
            
            if (request.changeTypes == null || request.changeTypes.isEmpty()) {
                throw new AuraHandledException('At least one change type must be selected');
            }
            
            // Use the ChangeOrderService to process the request
            result = ChangeOrderService.processChangeOrder(request);
            
        } catch (DmlException e) {
            Database.rollback(sp);
            System.debug('DML Error in processChangeOrder: ' + e.getMessage());
            result.errors.add('Database error: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Error in processChangeOrder: ' + e.getMessage());
            result.errors.add('Processing error: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Wrapper class for picklist values
     */
    public class PicklistValue {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        
        public PicklistValue(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    /**
     * @description Request wrapper for change order processing
     */
    public class ChangeOrderRequest {
        @AuraEnabled public List<Id> opportunityIds { get; set; }
        @AuraEnabled public Map<String, Boolean> changeTypes { get; set; }
        @AuraEnabled public Map<String, Object> changeValues { get; set; }
        @AuraEnabled public List<ProductChange> productChanges { get; set; }
        @AuraEnabled public Date effectiveDate { get; set; }
    }
    
    /**
     * @description Wrapper for product changes
     */
    public class ProductChange {
        @AuraEnabled public Id lineItemId { get; set; }
        @AuraEnabled public String newProduct { get; set; }
        @AuraEnabled public Decimal newPrice { get; set; }
        @AuraEnabled public String originalProduct { get; set; }
        @AuraEnabled public Decimal originalPrice { get; set; }
        @AuraEnabled public String opportunityName { get; set; }
    }
    
    /**
     * @description Result wrapper for change order processing
     */
    public class ChangeOrderResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public Id contractId { get; set; }
        @AuraEnabled public List<String> errors { get; set; }
        @AuraEnabled public Map<String, Id> createdRecords { get; set; }
        
        public ChangeOrderResult() {
            this.success = false;
            this.errors = new List<String>();
            this.createdRecords = new Map<String, Id>();
        }
    }
}