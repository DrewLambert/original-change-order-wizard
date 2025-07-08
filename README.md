# Original Change Order Wizard - Complete LWC Project

This project contains the complete original changeOrderWizard Lightning Web Component and all its dependencies, extracted into a standalone Salesforce project structure.

## Project Overview

The Change Order Wizard is a sophisticated multi-step Lightning Web Component that allows users to create contract change orders by selecting opportunities and specifying change types. It features a modern wizard-style interface with dynamic navigation and comprehensive validation.

## Features

- **3-Step Wizard Interface**: 
  1. Opportunity & Change Type Selection
  2. Product Configuration (when applicable)
  3. Review & Confirmation

- **Dynamic Navigation**: Automatically skips product step when not needed
- **Flow Integration**: Compatible with Salesforce Screen Flows
- **Bulk Operations**: Supports multiple opportunities and products
- **Draft Management**: Save and restore progress
- **Responsive Design**: Works across different screen sizes
- **Comprehensive Validation**: Client and server-side validation

## Component Architecture

### Main Component
- **changeOrderWizard**: The primary orchestrating component

### Child Components
- **opportunitySelector**: Handles opportunity selection with filtering and validation
- **changeTypePanel**: Manages change type selection and configuration
- **productGridEditor**: Provides product editing capabilities
- **summaryReview**: Final review and confirmation interface

### Apex Backend
- **ChangeOrderController**: Main controller with 6 public methods
- **ChangeOrderService**: Business logic and data manipulation
- **ChangeOrderControllerTest**: Comprehensive test coverage

## File Structure

```
force-app/main/default/
├── lwc/
│   ├── changeOrderWizard/
│   ├── opportunitySelector/
│   ├── changeTypePanel/
│   ├── productGridEditor/
│   └── summaryReview/
├── classes/
│   ├── ChangeOrderController.cls
│   ├── ChangeOrderService.cls
│   └── ChangeOrderControllerTest.cls
└── objects/
    ├── ContractOpportunityLink__c/
    └── Contract_Line_Item_Link__c/
```

## Installation Requirements

### Custom Objects
This component requires these custom objects to be deployed:
- `ContractOpportunityLink__c`: Links contracts to opportunities
- `Contract_Line_Item_Link__c`: Links contract line items

### Custom Fields
The following custom fields must exist on standard objects:

#### Opportunity
- `Quote_Number__c` (Text)
- `Attribution_2024__c` (Text)
- `Service_Model__c` (Picklist)

#### Contract
- `Change_Service__c` (Checkbox)
- `Change_Pricing_Model__c` (Checkbox)
- `Change_Term__c` (Checkbox)
- `Change_Price__c` (Checkbox)
- `Change_Product__c` (Checkbox)
- `Abatement__c` (Checkbox)
- `Co_Term__c` (Checkbox)
- `New_Service_Model__c` (Text)
- `New_Pricing_Model__c` (Text)
- `Abatement_Period__c` (Number)
- `Renewal_Term__c` (Number)
- `Contract_Opt_out_Days__c` (Number)
- `Sales_Contact__c` (Lookup to Contact)
- `Docusign_Contact__c` (Lookup to Contact)

#### OpportunityLineItem
- `Recurring_Revenue__c` (Currency)
- `Lease_Rate__c` (Currency)

### Permissions
Users need appropriate permissions to:
- Read/Edit Opportunities, Contracts, Products
- Create Contract records
- Create custom object records
- Access the Lightning component

## Usage

### As Record Page Component
Add to Opportunity, Account, or Contract record pages with these parameters:
- `recordId`: Auto-populated with current record ID
- `accountId`: Optional override for account context
- `preselectedOpportunityIds`: Array of opportunity IDs to pre-select

### In Screen Flows
Configure as a Screen Flow component with:
- **Input Variables**: recordId, accountId, preselectedOpportunityIds
- **Output Variables**: contractId (newly created contract)

### Component Parameters
```javascript
// Public API properties
@api recordId;              // Current record context
@api accountId;             // Account to filter opportunities
@api preselectedOpportunityIds; // Array of opportunity IDs
@api showWizardHeader;      // Display wizard header
@api showStepIcons;         // Show step navigation icons
@api showSummaryStats;      // Display summary statistics
@api showProductGrid;       // Enable product editing step
@api enableTwoColumnSummary; // Two-column summary layout
@api wizardThemeColor;      // Theme: blue, green, purple, orange, red
@api maxOpportunities;      // Maximum selectable opportunities
@api customHeaderText;      // Custom header text override

// Output (Flow integration)
@api contractId;            // ID of created contract
```

## API Methods (Apex)

### ChangeOrderController
1. `getOpportunities(Id accountId)` - Retrieve filterable opportunities
2. `loadDraft(Id accountId)` - Load saved draft data
3. `saveDraft(Id accountId, String draftData)` - Save current progress
4. `processChangeOrder(ChangeOrderRequest request)` - Create change order
5. `getProducts(List<Id> opportunityIds)` - Get products for opportunities
6. `getPicklistValues(String objectName, String fieldName)` - Get picklist options

### Request Objects
```apex
public class ChangeOrderRequest {
    public List<Id> opportunityIds;
    public Map<String, Boolean> changeTypes;
    public Map<String, Object> changeValues;
    public List<ProductChange> productChanges;
    public Date effectiveDate;
}
```

## Deployment

1. Deploy all files from this project to your Salesforce org
2. Ensure all required custom fields exist on standard objects
3. Deploy custom objects with appropriate field-level security
4. Assign appropriate permissions to users
5. Add component to relevant record pages or flows

## Testing

Run the included test class:
```bash
# In Developer Console or VS Code
ChangeOrderControllerTest.runAllTests();
```

Test coverage includes:
- All controller methods
- Error handling scenarios
- Edge cases and validation
- Integration patterns

## Customization

### Styling
Each component includes CSS files that can be customized:
- Theme colors via CSS custom properties
- Responsive breakpoints
- Animation timing and effects

### Business Logic
Modify `ChangeOrderService.cls` to adjust:
- Validation rules
- Field mappings
- Integration patterns
- Approval processes

### UI Flow
Adjust wizard steps in `changeOrderWizard.js`:
- Add/remove steps
- Modify navigation logic
- Change validation requirements

## Support and Maintenance

This is a complete, production-ready component that has been tested and validated. For support:
1. Check the test class for usage patterns
2. Review component documentation in the code
3. Test thoroughly in a sandbox before production deployment

## Version History

- **v1.0**: Initial complete implementation with all features
- Includes comprehensive error handling
- Full flow integration support
- Responsive design implementation
- Complete test coverage

---

**Note**: This project represents the original, fully-featured changeOrderWizard component. A simplified flow-specific version (`flowChangeOrderWizard`) was created separately for basic screen flow usage without the complexity of the full wizard interface.