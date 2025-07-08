# Deployment Guide - Original Change Order Wizard

This guide provides step-by-step instructions for deploying the Original Change Order Wizard to a Salesforce org.

## Prerequisites

1. **Salesforce CLI** installed and authenticated to your org
2. **System Administrator** permissions in the target org
3. **Custom Object and Field Creation** permissions
4. **Lightning Platform** enabled

## Pre-Deployment Requirements

### 1. Custom Fields on Standard Objects

Before deploying, ensure these custom fields exist on standard objects:

#### Opportunity Object
```apex
// Required fields - must be created before deployment
Quote_Number__c (Text, Length: 50)
Attribution_2024__c (Text, Length: 255)
Service_Model__c (Picklist: Full Service, Self Service, Hybrid)
```

#### Contract Object
```apex
// Required fields - must be created before deployment
Change_Service__c (Checkbox)
Change_Pricing_Model__c (Checkbox)
Change_Term__c (Checkbox)
Change_Price__c (Checkbox)
Change_Product__c (Checkbox)
Abatement__c (Checkbox)
Co_Term__c (Checkbox)
New_Service_Model__c (Text, Length: 100)
New_Pricing_Model__c (Text, Length: 100)
Abatement_Period__c (Number, Length: 3, Decimal Places: 0)
Renewal_Term__c (Number, Length: 3, Decimal Places: 0)
Contract_Opt_out_Days__c (Number, Length: 3, Decimal Places: 0)
Sales_Contact__c (Lookup to Contact)
Docusign_Contact__c (Lookup to Contact)
```

#### OpportunityLineItem Object
```apex
// Required fields - must be created before deployment
Recurring_Revenue__c (Currency, Length: 16, Decimal Places: 2)
Lease_Rate__c (Currency, Length: 16, Decimal Places: 2)
```

#### Product2 Object
```apex
// Ensure Family field has 'Machine' picklist value
Family (Standard field - add 'Machine' as picklist value)
```

## Deployment Steps

### Step 1: Prepare Your Environment
```bash
# Navigate to the project directory
cd /path/to/OriginalChangeOrderWizard

# Authenticate to your org (if not already done)
sfdx org login web -a MyOrg

# Set default org
sfdx config set target-org MyOrg
```

### Step 2: Validate Deployment
```bash
# Validate the deployment without actually deploying
sfdx project deploy start --dry-run --manifest package.xml
```

### Step 3: Deploy to Org
```bash
# Deploy all components
sfdx project deploy start --manifest package.xml

# Alternative: Deploy specific directories
sfdx project deploy start --source-dir force-app/main/default/lwc
sfdx project deploy start --source-dir force-app/main/default/classes
sfdx project deploy start --source-dir force-app/main/default/objects
```

### Step 4: Run Tests
```bash
# Run the test class to ensure everything works
sfdx apex run test --class-names ChangeOrderControllerTest --result-format human
```

## Post-Deployment Configuration

### 1. Permission Sets (Recommended)
Create a permission set with these permissions:
- Read/Edit access to Opportunity, Contract, Product2, OpportunityLineItem
- Create access to Contract, ContractOpportunityLink__c, Contract_Line_Item_Link__c
- Read access to Account, Contact, PricebookEntry

### 2. Component Permissions
Grant Lightning Component permissions:
- changeOrderWizard
- opportunitySelector
- changeTypePanel
- productGridEditor
- summaryReview

### 3. Add to Lightning Pages
Add the changeOrderWizard component to relevant Lightning pages:

#### Record Pages
1. Go to Setup → Lightning App Builder
2. Edit the Opportunity, Account, or Contract record page
3. Add the "Change Order Wizard" component
4. Configure component properties as needed

#### Home Pages or App Pages
1. Create a new Lightning Page (App Page or Home Page)
2. Add the "Change Order Wizard" component
3. Set appropriate input parameters

### 4. Flow Integration (Optional)
To use in Screen Flows:
1. Create a new Flow (Screen Flow type)
2. Add a Screen element
3. Add the "Flow Change Order Wizard" component
4. Configure input/output variables

## Verification Checklist

After deployment, verify:

- [ ] All Apex classes deployed successfully
- [ ] All LWC components are available in App Builder
- [ ] Custom objects and fields are created
- [ ] Test class passes with 100% coverage
- [ ] Component appears on assigned Lightning pages
- [ ] Users can create change orders successfully
- [ ] Flow integration works (if using flows)

## Troubleshooting

### Common Issues

1. **Missing Custom Fields**
   - Error: "Invalid field reference"
   - Solution: Create all required custom fields listed above

2. **Permission Issues**
   - Error: "Insufficient privileges"
   - Solution: Grant appropriate object and field permissions

3. **API Version Conflicts**
   - Error: "Invalid API version"
   - Solution: Ensure all metadata uses API version 63.0 or higher

4. **Component Not Visible**
   - Issue: Component doesn't appear in App Builder
   - Solution: Check Lightning Component Bundle permissions

### Test Failures
If tests fail:
1. Check that all custom fields exist
2. Verify sample data creation in test methods
3. Ensure test user has appropriate permissions
4. Check for org-specific validation rules that might interfere

## Configuration Options

### Component Parameters
When adding to Lightning pages, configure these parameters:

#### Basic Parameters
- `recordId`: Auto-populated for record pages
- `accountId`: Override account context
- `preselectedOpportunityIds`: Pre-select specific opportunities

#### UI Customization
- `showWizardHeader`: Show/hide wizard header (default: true)
- `showStepIcons`: Show/hide step icons (default: true)
- `wizardThemeColor`: Theme color (blue, green, purple, orange, red)
- `maxOpportunities`: Maximum selectable opportunities (default: 10)

#### Feature Toggles
- `showSummaryStats`: Display summary statistics
- `showProductGrid`: Enable product editing step
- `enableTwoColumnSummary`: Two-column summary layout

### Flow Variables
For Screen Flow integration:

#### Input Variables
```
recordId (Text)
accountId (Text)
preselectedOpportunityIds (Text Collection)
```

#### Output Variables
```
contractId (Text) - Returns ID of created contract
```

## Maintenance

### Regular Tasks
1. **Monitor Usage**: Review component performance and user feedback
2. **Update Tests**: Keep test methods current with business logic changes
3. **Version Control**: Maintain version history of customizations

### Business Logic Updates
To modify business logic:
1. Update `ChangeOrderService.cls` for core business rules
2. Modify validation in `ChangeOrderController.cls`
3. Adjust UI behavior in component JavaScript files
4. Update test methods to reflect changes

### Security Review
Regularly review:
- Field-level security settings
- Object permissions
- Component access permissions
- Integration security patterns

## Support

For additional support:
1. Review the comprehensive README.md file
2. Check component documentation in source code
3. Run debug logs to troubleshoot specific issues
4. Consult Salesforce Lightning Component documentation

---

**Important**: Always deploy to a sandbox environment first and test thoroughly before deploying to production.