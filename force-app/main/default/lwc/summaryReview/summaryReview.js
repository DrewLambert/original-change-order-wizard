import { LightningElement, api, track, wire } from 'lwc';

export default class SummaryReview extends LightningElement {
    @api selectedOpportunities = [];
    @api selectedChangeTypes = {};
    @api changeValues = {};
    @api productChanges = [];
    @api opportunityData = [];
    @api isConfirmed = false;
    
    // Flow configuration properties
    @api showSummaryStats = false;
    @api enableTwoColumnSummary = false;
    
    @track warnings = [];
    
    get opportunityCount() {
        return this.selectedOpportunities.length;
    }
    
    get productCount() {
        return this.productChanges.length;
    }
    
    get changeTypeCount() {
        return Object.values(this.selectedChangeTypes).filter(value => value === true).length;
    }
    
    get totalValueImpact() {
        return this.productChanges.reduce((total, change) => {
            if (change.newPrice && change.originalPrice) {
                return total + (parseFloat(change.newPrice) - parseFloat(change.originalPrice));
            }
            return total;
        }, 0);
    }
    
    get valueImpactClass() {
        let baseClass = 'slds-text-heading_large ';
        if (this.totalValueImpact > 0) {
            return baseClass + 'slds-text-color_success';
        } else if (this.totalValueImpact < 0) {
            return baseClass + 'slds-text-color_error';
        }
        return baseClass + 'slds-text-color_default';
    }
    
    get hasProductChanges() {
        return this.productChanges.length > 0;
    }
    
    get hasWarnings() {
        return this.warnings.length > 0;
    }
    
    get changeTypeDetails() {
        const details = [];
        
        if (this.selectedChangeTypes.changeServiceModel) {
            details.push({
                label: 'Change Service Model',
                value: this.changeValues.serviceModel || 'Not specified'
            });
        }
        
        if (this.selectedChangeTypes.changePricingModel) {
            details.push({
                label: 'Change Pricing Model',
                value: this.changeValues.pricingModel || 'Not specified'
            });
        }
        
        if (this.selectedChangeTypes.changeTerm) {
            const termDetails = [];
            if (this.changeValues.termLength) {
                termDetails.push(`${this.changeValues.termLength} months`);
            }
            if (this.changeValues.optOutDays) {
                termDetails.push(`${this.changeValues.optOutDays} opt-out days`);
            }
            if (this.changeValues.renewalTerm) {
                termDetails.push(`${this.changeValues.renewalTerm} months renewal`);
            }
            
            details.push({
                label: 'Change Term',
                value: termDetails.join(', ') || 'Not specified'
            });
        }
        
        if (this.selectedChangeTypes.changePrice) {
            details.push({
                label: 'Change Price',
                value: 'Price modifications specified in product grid'
            });
        }
        
        if (this.selectedChangeTypes.changeProduct) {
            details.push({
                label: 'Change Product',
                value: 'Product modifications specified in product grid'
            });
        }
        
        if (this.selectedChangeTypes.addAbatement) {
            details.push({
                label: 'Add Abatement',
                value: this.changeValues.abatementPeriod ? `${this.changeValues.abatementPeriod} days` : 'Not specified'
            });
        }
        
        if (this.selectedChangeTypes.coTermContracts) {
            details.push({
                label: 'Co-Term Contracts',
                value: 'Contracts will be co-termed'
            });
        }
        
        return details;
    }
    
    get productChangeDetails() {
        return this.productChanges.map(change => {
            const originalPrice = parseFloat(change.originalPrice) || 0;
            const newPrice = parseFloat(change.newPrice) || 0;
            const impact = newPrice - originalPrice;
            
            // Determine revenue type label and badge class
            const isRecurring = change.isRecurringRevenue === true;
            const revenueTypeLabel = isRecurring ? 'Recurring' : 'One-Time';
            const revenueTypeBadgeClass = isRecurring ? 'slds-theme_success' : 'slds-theme_default';
            
            return {
                ...change,
                impact: impact,
                impactClass: impact > 0 ? 'slds-text-color_success' : 
                           impact < 0 ? 'slds-text-color_error' : 
                           'slds-text-color_default',
                revenueTypeLabel: revenueTypeLabel,
                revenueTypeBadgeClass: revenueTypeBadgeClass,
                newProductName: change.newProductName || change.newProduct || 'Product Name Not Available'
            };
        });
    }
    
    connectedCallback() {
        this.generateWarnings();
    }
    
    generateWarnings() {
        this.warnings = [];
        
        // Check for opportunities without amounts
        const opportunitiesWithoutAmount = this.opportunityData.filter(opp => !opp.Amount || opp.Amount === 0);
        if (opportunitiesWithoutAmount.length > 0) {
            this.warnings.push(`${opportunitiesWithoutAmount.length} opportunity(ies) do not have amounts specified`);
        }
        
        // Check for large price increases
        const largeIncreases = this.productChangeDetails.filter(change => 
            change.impact > 0 && (change.impact / change.originalPrice) > 0.25
        );
        if (largeIncreases.length > 0) {
            this.warnings.push(`${largeIncreases.length} product(s) have price increases greater than 25%`);
        }
        
        // Check for large price decreases
        const largeDecreases = this.productChangeDetails.filter(change => 
            change.impact < 0 && Math.abs(change.impact / change.originalPrice) > 0.25
        );
        if (largeDecreases.length > 0) {
            this.warnings.push(`${largeDecreases.length} product(s) have price decreases greater than 25%`);
        }
        
        // Check for effective date in the past
        if (this.changeValues.effectiveDate) {
            const effectiveDate = new Date(this.changeValues.effectiveDate);
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            
            if (effectiveDate < today) {
                this.warnings.push('Effective date is in the past');
            }
        }
    }
    
    handleConfirmationChange(event) {
        this.isConfirmed = event.target.checked;
        
        const confirmationEvent = new CustomEvent('confirmationchange', {
            detail: {
                isConfirmed: this.isConfirmed
            }
        });
        this.dispatchEvent(confirmationEvent);
    }
    
    
    @api
    refreshWarnings() {
        this.generateWarnings();
    }
    
    @api
    getSummaryData() {
        return {
            opportunityCount: this.opportunityCount,
            productCount: this.productCount,
            changeTypeCount: this.changeTypeCount,
            totalValueImpact: this.totalValueImpact,
            warnings: this.warnings,
            hasWarnings: this.hasWarnings
        };
    }
}