# README for Claude - Original Change Order Wizard Project

## 🎯 Project Context & Purpose

This is the **Original Change Order Wizard** - a sophisticated, production-ready Lightning Web Component system extracted from a larger Salesforce project. This wizard allows users to create contract change orders through a guided 3-step interface.

### 🔄 Project History
- **Origin**: Extracted from `/PageLayoutTraining/force-app/main/default/lwc/changeOrderWizard`
- **Extraction Date**: July 8, 2025
- **Reason**: To create a standalone, deployable package separate from a simplified flow version
- **Status**: Complete, tested, production-ready

## 🏗️ Architecture Overview

### Component Hierarchy & Relationships
```
changeOrderWizard (Parent/Orchestrator)
├── opportunitySelector (Step 1)
├── changeTypePanel (Step 1) 
├── productGridEditor (Step 2 - Conditional)
└── summaryReview (Step 3)
```

### Data Flow Pattern
```
User Interaction → LWC Component → ChangeOrderController → ChangeOrderService → Salesforce Objects
```

### Key Business Objects
- **Input**: Opportunities, Products, OpportunityLineItems
- **Output**: Contract, ContractOpportunityLink__c, Contract_Line_Item_Link__c, Tasks
- **Context**: Account (for filtering), Contact (for assignments)

## 📋 Detailed Component Specifications

### 1. changeOrderWizard (Main Component)
**File**: `force-app/main/default/lwc/changeOrderWizard/`

**Purpose**: Main orchestrating component that manages the 3-step wizard flow

**Key Properties**:
```javascript
// Context & Data
@api recordId;                    // Current record ID (auto-populated on record pages)
@api accountId;                   // Override account context
@api preselectedOpportunityIds;   // Array of opportunity IDs to pre-select

// UI Customization
@api showWizardHeader = true;     // Show/hide wizard header
@api showStepIcons = true;        // Show/hide step navigation icons
@api wizardThemeColor = 'blue';   // Theme: blue, green, purple, orange, red
@api customHeaderText;            // Override default header text
@api maxOpportunities = 10;       // Maximum selectable opportunities

// Feature Toggles
@api showSummaryStats = true;     // Display summary statistics
@api showProductGrid = true;      // Enable product editing step
@api enableTwoColumnSummary = false; // Two-column summary layout

// Flow Integration
@api contractId;                  // Output: ID of created contract (for flows)
```

**Step Logic**:
1. **Step 1**: Opportunity selection + Change type configuration
2. **Step 2**: Product editing (only if product/price changes selected)
3. **Step 3**: Review and final confirmation

**Navigation Rules**:
- Step 2 is automatically skipped if no product-related changes are selected
- Users can navigate backwards but not forwards without completing current step
- Final submission only available from Step 3 with confirmation

### 2. opportunitySelector
**File**: `force-app/main/default/lwc/opportunitySelector/`

**Purpose**: Handles opportunity selection with smart filtering and validation

**Key Features**:
- Account-based filtering
- Quote number validation (only opportunities with quotes can be selected)
- Stage-based filtering options
- Real-time search functionality
- Visual indicators for quote status

**Important Property**:
```javascript
@api preselectedOpportunityIds = []; // Must be initialized to prevent errors
```

**Data Requirements**:
- Opportunities must have `Quote_Number__c` field populated to be selectable
- Reads `StageName`, `Name`, `Quote_Number__c` fields

### 3. changeTypePanel
**File**: `force-app/main/default/lwc/changeTypePanel/`

**Purpose**: Manages change type selection and dynamic field display

**Supported Change Types**:
1. **Change Service Model** - Requires service model picklist selection
2. **Change Pricing Model** - Requires pricing model picklist selection  
3. **Change Term** - Requires term length, opt-out days, renewal term
4. **Change Price** - No additional fields
5. **Change Product** - Triggers product grid in Step 2
6. **Add Abatement** - Requires abatement period
7. **Co-Term Contracts** - No additional fields

**Dynamic Fields**:
- Fields only appear when corresponding change type is selected
- All fields are validated before proceeding to next step
- Effective date is required for all change orders

### 4. productGridEditor
**File**: `force-app/main/default/lwc/productGridEditor/`

**Purpose**: Provides product editing capabilities when product/price changes are selected

**Functionality**:
- Display existing opportunity line items
- Allow quantity and price modifications
- Add new products from catalog
- Remove existing products
- Calculate recurring revenue totals

**Data Integration**:
- Reads from OpportunityLineItem, Product2, PricebookEntry
- Filters products by Family = 'Machine'
- Calculates `Recurring_Revenue__c` and `Lease_Rate__c`

### 5. summaryReview
**File**: `force-app/main/default/lwc/summaryReview/`

**Purpose**: Final review interface with comprehensive change summary

**Display Elements**:
- Selected opportunities summary
- Change types and values summary
- Product changes summary (if applicable)
- Final confirmation checkbox
- Error validation display

## 🔧 Backend Architecture

### ChangeOrderController.cls
**Main API Methods**:

1. **`getOpportunities(Id accountId)`**
   - Returns opportunities filtered by account
   - Only includes opportunities with Quote_Number__c
   - Used by opportunitySelector component

2. **`processChangeOrder(ChangeOrderRequest request)`**
   - Main business logic method
   - Creates Contract and related records
   - Returns ChangeOrderResponse with success/error status

3. **`getProducts(List<Id> opportunityIds)`**
   - Returns products for selected opportunities
   - Includes opportunity line item data
   - Used by productGridEditor component

4. **`getPicklistValues(String objectName, String fieldName)`**
   - Dynamic picklist value retrieval
   - Used for service/pricing model dropdowns

5. **`loadDraft(Id accountId)` / `saveDraft(Id accountId, String draftData)`**
   - Draft persistence functionality
   - Saves user progress for later completion

**Request/Response Objects**:
```apex
public class ChangeOrderRequest {
    public List<Id> opportunityIds;
    public Map<String, Boolean> changeTypes;
    public Map<String, Object> changeValues;
    public List<ProductChange> productChanges;
    public Date effectiveDate;
}

public class ChangeOrderResponse {
    public Boolean success;
    public String message;
    public Id contractId;
    public List<String> errors;
}
```

### ChangeOrderService.cls
**Core Business Logic**:
- Contract creation with proper field mapping
- ContractOpportunityLink__c record creation
- Contract_Line_Item_Link__c record creation for product changes
- Task creation for follow-up activities
- Comprehensive error handling and validation

**Security Pattern**:
- Uses `WITH SECURITY_ENFORCED` in SOQL queries
- Respects field-level security
- Validates user permissions before DML operations

## 🗃️ Data Model

### Custom Objects

#### ContractOpportunityLink__c
**Purpose**: Junction object linking contracts to opportunities they modify

**Key Fields**:
- `Contract__c` (Lookup to Contract)
- `Opportunity__c` (Lookup to Opportunity)
- `Effective_Date__c` (Date)
- `New_Service_Model__c` (Text)
- `New_Pricing_Model__c` (Text)
- `New_Rate__c` (Currency)
- `Quote_Order_Numbers__c` (Text)
- `Service_Type__c` (Picklist)

#### Contract_Line_Item_Link__c
**Purpose**: Tracks specific line item changes within contracts

**Key Fields**:
- `Contract__c` (Lookup to Contract)
- `Line_Item__c` (Text - stores OpportunityLineItem ID)
- `Machine_Type__c` (Text)
- `New_Machine_Type__c` (Text)
- `New_Rate__c` (Currency)
- `New_Service_Model__c` (Text)
- `Serial_Number__c` (Text)
- `Type_of_Machine__c` (Text)

### Required Custom Fields on Standard Objects

#### Opportunity
```apex
Quote_Number__c (Text, 50) - REQUIRED for opportunity selection
Attribution_2024__c (Text, 255) - Used for tracking
Service_Model__c (Picklist) - Current service model
```

#### Contract
```apex
// Change type flags
Change_Service__c (Checkbox)
Change_Pricing_Model__c (Checkbox)
Change_Term__c (Checkbox)
Change_Price__c (Checkbox)
Change_Product__c (Checkbox)
Abatement__c (Checkbox)
Co_Term__c (Checkbox)

// New values
New_Service_Model__c (Text, 100)
New_Pricing_Model__c (Text, 100)
Abatement_Period__c (Number, 3, 0)
Renewal_Term__c (Number, 3, 0)
Contract_Opt_out_Days__c (Number, 3, 0)

// Contact assignments
Sales_Contact__c (Lookup to Contact)
Docusign_Contact__c (Lookup to Contact)
```

#### OpportunityLineItem
```apex
Recurring_Revenue__c (Currency, 16, 2) - Monthly recurring revenue
Lease_Rate__c (Currency, 16, 2) - Machine lease rate
```

## 🔧 Development Patterns & Best Practices

### Error Handling Pattern
```javascript
// Client-side error handling
try {
    const result = await apexMethod({ param: value });
    if (result.success) {
        // Handle success
        this.contractId = result.contractId;
        this.showSuccessToast();
    } else {
        // Handle business logic errors
        this.error = result.message;
    }
} catch (error) {
    // Handle system errors
    this.handleError('Operation failed', error);
}
```

### Data Validation Pattern
```apex
// Server-side validation pattern
public static ChangeOrderResponse processChangeOrder(ChangeOrderRequest request) {
    ChangeOrderResponse response = new ChangeOrderResponse();
    
    // Input validation
    if (request.opportunityIds == null || request.opportunityIds.isEmpty()) {
        response.success = false;
        response.message = 'At least one opportunity must be selected';
        return response;
    }
    
    // Business logic execution
    try {
        // Delegate to service class
        Id contractId = ChangeOrderService.createChangeOrder(request);
        response.success = true;
        response.contractId = contractId;
    } catch (Exception e) {
        response.success = false;
        response.message = 'Error creating change order: ' + e.getMessage();
    }
    
    return response;
}
```

### Flow Integration Pattern
```javascript
// Flow navigation support
import { FlowNavigationNextEvent } from 'lightning/flowSupport';

// In component method
if (this.isInFlowContext) {
    // Set output variables
    this.contractId = result.contractId;
    
    // Navigate to next flow screen
    const navigateNextEvent = new FlowNavigationNextEvent();
    this.dispatchEvent(navigateNextEvent);
}
```

## 🎨 UI/UX Patterns

### Theme System
```css
/* Theme color CSS custom properties */
.wizard-container.theme-blue .step-icon { color: #3b82f6; }
.wizard-container.theme-green .step-icon { color: #10b981; }
.wizard-container.theme-purple .step-icon { color: #8b5cf6; }
.wizard-container.theme-orange .step-icon { color: #f59e0b; }
.wizard-container.theme-red .step-icon { color: #ef4444; }
```

### Responsive Design Pattern
```css
/* Mobile-first responsive design */
@media (max-width: 768px) {
    .selection-grid {
        grid-template-columns: 1fr; /* Single column on mobile */
    }
    
    .action-buttons {
        flex-direction: column; /* Stack buttons vertically */
    }
}
```

### Animation Pattern
```css
/* Smooth transitions for user experience */
.step-container {
    animation: fadeIn 0.3s ease-in-out;
}

@keyframes fadeIn {
    from { opacity: 0; transform: translateY(10px); }
    to { opacity: 1; transform: translateY(0); }
}
```

## 🧪 Testing Strategy

### ChangeOrderControllerTest.cls
**Coverage Areas**:
- All controller methods (100% code coverage)
- Error scenarios and edge cases
- Data creation and validation
- Permission and security testing

**Key Test Patterns**:
```apex
// Test data factory pattern
private static Account createTestAccount() {
    return new Account(Name = 'Test Account', Type = 'Customer');
}

// Negative testing pattern
@isTest
static void testProcessChangeOrder_NoOpportunities() {
    ChangeOrderController.ChangeOrderRequest request = new ChangeOrderController.ChangeOrderRequest();
    request.opportunityIds = new List<Id>();
    
    ChangeOrderController.ChangeOrderResponse response = 
        ChangeOrderController.processChangeOrder(request);
    
    System.assert(!response.success);
    System.assert(response.message.contains('At least one opportunity'));
}
```

## 🔍 Common Issues & Solutions

### 1. "Unknown public property 'preselectedOpportunityIds'"
**Cause**: Property not defined in opportunitySelector component
**Solution**: Ensure `@api preselectedOpportunityIds = [];` exists in opportunitySelector.js

### 2. "Value provided is invalid for action parameter 'request'"
**Cause**: Object wrapper issue when calling Apex method
**Solution**: Pass the request object directly, not wrapped in another object
```javascript
// Correct
const result = await processChangeOrder(request);
// Incorrect  
const result = await processChangeOrder({ request });
```

### 3. "Effective date is in the past" validation error
**Cause**: Timezone conversion issues with date handling
**Solution**: Use local date formatting to avoid timezone conversion
```javascript
// Correct approach
const date = this.changeValues.effectiveDate;
effectiveDate = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;

// Avoid this (timezone issues)
effectiveDate = date.toISOString().split('T')[0];
```

### 4. Duplicate key errors in navigation bar
**Cause**: Platform-level issue unrelated to component code
**Solution**: These are platform warnings and don't affect component functionality

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] All required custom fields created on standard objects
- [ ] Custom objects deployed successfully
- [ ] User permissions configured
- [ ] Test data available for validation

### Deployment
- [ ] Deploy Apex classes first
- [ ] Deploy LWC components
- [ ] Deploy custom objects and fields
- [ ] Run test classes to verify functionality

### Post-Deployment
- [ ] Add components to Lightning pages
- [ ] Configure component permissions
- [ ] Test end-to-end functionality
- [ ] Train users on new interface

## 💡 Enhancement Opportunities

### Potential Improvements
1. **Bulk Processing**: Support for processing hundreds of opportunities
2. **Approval Integration**: Built-in approval workflow triggers
3. **Email Notifications**: Automated stakeholder notifications
4. **Audit Trail**: Enhanced change tracking and history
5. **Mobile Optimization**: Further mobile UX improvements
6. **Integration APIs**: REST/GraphQL API exposure

### Architecture Extensions
1. **Platform Events**: Real-time updates across the org
2. **Custom Metadata**: Configuration-driven change types
3. **Flow Actions**: Expose as invocable Apex methods
4. **Einstein Analytics**: Embedded analytics dashboard

## 📚 Key Documentation Files

1. **README.md** - User-facing feature documentation
2. **DEPLOYMENT-GUIDE.md** - Step-by-step deployment instructions
3. **COMPONENT-INVENTORY.md** - Technical specifications
4. **PROJECT-SUMMARY.md** - Executive overview
5. **README-FOR-CLAUDE.md** - This technical deep-dive (for AI assistants)

---

## 🤖 Instructions for Claude

When working with this project:

1. **Always read this file first** to understand the complete context
2. **Check the git status** to understand any recent changes
3. **Review test failures carefully** - they often indicate missing custom fields
4. **Use the error patterns above** to quickly diagnose common issues
5. **Follow the established patterns** when making modifications
6. **Test thoroughly** in a sandbox before any production changes
7. **Update documentation** when making significant changes

This is a **production-ready, enterprise-grade** solution. Treat it with appropriate care and maintain the high code quality standards established.