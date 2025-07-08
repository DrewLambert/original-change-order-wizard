import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOpportunities from '@salesforce/apex/ChangeOrderController.getOpportunities';
import { refreshApex } from '@salesforce/apex';

export default class OpportunitySelector extends LightningElement {
    @api accountId;
    @api selectedOpportunities = [];
    @api preselectedOpportunityIds = [];
    
    @track searchTerm = '';
    @track allOpportunities = [];
    @track displayedOpportunities = [];
    @track selectedOpportunityIds = [];
    @track isLoading = false;
    @track hasError = false;
    @track errorMessage = '';
    @track showValidationError = false;
    
    wiredOpportunities;
    
    // Removed columns - now using custom list format
    
    @wire(getOpportunities, { accountId: '$accountId' })
    wiredOpportunitiesMethod(result) {
        this.wiredOpportunities = result;
        this.isLoading = true;
        this.hasError = false;
        
        if (result.data) {
            this.allOpportunities = result.data;
            this.initializePreselectedOpportunities();
            this.filterOpportunities();
            this.isLoading = false;
        } else if (result.error) {
            this.hasError = true;
            this.errorMessage = result.error.body ? result.error.body.message : 'Unknown error occurred';
            this.isLoading = false;
        }
    }
    
    get totalCount() {
        return this.allOpportunities.length;
    }
    
    get selectedCount() {
        return this.selectedOpportunityIds.length;
    }
    
    get allSelected() {
        return this.totalCount > 0 && this.selectedCount === this.totalCount;
    }
    
    // Removed selectedRowsForDataTable - no longer using datatable
    
    get noOpportunities() {
        return !this.isLoading && !this.hasError && this.allOpportunities.length === 0;
    }
    
    connectedCallback() {
        if (this.selectedOpportunities && this.selectedOpportunities.length > 0) {
            this.selectedOpportunityIds = [...this.selectedOpportunities];
        }
        console.log('OpportunitySelector connected with selectedOpportunities:', this.selectedOpportunities);
    }
    
    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.filterOpportunities();
    }
    
    filterOpportunities() {
        let filteredOpps;
        if (!this.searchTerm) {
            filteredOpps = [...this.allOpportunities];
        } else {
            const searchLower = this.searchTerm.toLowerCase();
            filteredOpps = this.allOpportunities.filter(opp => 
                opp.Name.toLowerCase().includes(searchLower) ||
                opp.StageName.toLowerCase().includes(searchLower)
            );
        }
        
        // Add display properties to each opportunity
        this.displayedOpportunities = filteredOpps.map(opp => {
            const isSelected = this.selectedOpportunityIds.includes(opp.Id);
            return {
                ...opp,
                cssClass: `slds-item opportunity-item ${isSelected ? 'selected' : ''}`,
                buttonClass: `slds-button slds-button_icon slds-button_icon-border-filled selection-button ${isSelected ? 'selected' : ''}`,
                iconName: isSelected ? 'utility:dash' : 'utility:add',
                buttonLabel: isSelected ? 'Remove opportunity' : 'Add opportunity',
                formattedAmount: this.formatCurrency(opp.Amount),
                formattedCloseDate: this.formatDate(opp.CloseDate)
            };
        });
    }
    
    handleOpportunityClick(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const opportunityId = event.currentTarget.dataset.id;
        console.log('Opportunity clicked:', opportunityId);
        
        // Toggle selection
        if (this.selectedOpportunityIds.includes(opportunityId)) {
            // Remove from selection
            this.selectedOpportunityIds = this.selectedOpportunityIds.filter(id => id !== opportunityId);
        } else {
            // Add to selection
            this.selectedOpportunityIds = [...this.selectedOpportunityIds, opportunityId];
        }
        
        this.showValidationError = false;
        console.log('Updated selectedOpportunityIds:', this.selectedOpportunityIds);
        
        // Refresh the display to update button states
        this.filterOpportunities();
        
        // Dispatch selection change event
        this.dispatchSelectionChange();
    }
    
    selectAll() {
        this.selectedOpportunityIds = this.allOpportunities.map(opp => opp.Id);
        this.showValidationError = false;
        this.filterOpportunities(); // Refresh display
        this.dispatchSelectionChange();
    }
    
    deselectAll() {
        this.selectedOpportunityIds = [];
        this.filterOpportunities(); // Refresh display
        this.dispatchSelectionChange();
    }
    
    dispatchSelectionChange() {
        const selectionChangeEvent = new CustomEvent('selectionchange', {
            detail: {
                selectedOpportunities: this.selectedOpportunityIds,
                selectedOpportunityData: this.allOpportunities.filter(opp => 
                    this.selectedOpportunityIds.includes(opp.Id)
                )
            }
        });
        this.dispatchEvent(selectionChangeEvent);
    }
    
    @api
    validateSelection() {
        if (this.selectedOpportunityIds.length === 0) {
            this.showValidationError = true;
            return false;
        }
        this.showValidationError = false;
        return true;
    }
    
    @api
    refreshData() {
        this.isLoading = true;
        return refreshApex(this.wiredOpportunities);
    }
    
    loadOpportunities() {
        this.refreshData();
    }
    
    @api
    getSelectedOpportunities() {
        return this.allOpportunities.filter(opp => 
            this.selectedOpportunityIds.includes(opp.Id)
        );
    }
    
    @api
    getOpportunitiesWithoutQuotes() {
        // Return opportunities that don't have Quote_Number__c populated
        return this.allOpportunities.filter(opp => 
            !opp.Quote_Number__c || opp.Quote_Number__c === null || opp.Quote_Number__c === ''
        );
    }
    
    formatCurrency(amount) {
        if (amount == null || amount === undefined) {
            return '$0.00';
        }
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(amount);
    }
    
    formatDate(dateString) {
        if (!dateString) {
            return '';
        }
        const date = new Date(dateString);
        return new Intl.DateTimeFormat('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        }).format(date);
    }
    
    initializePreselectedOpportunities() {
        if (this.preselectedOpportunityIds && this.preselectedOpportunityIds.length > 0) {
            // Initialize selected opportunities with preselected IDs
            this.selectedOpportunityIds = [...this.preselectedOpportunityIds];
            console.log('Initialized with preselected opportunities:', this.selectedOpportunityIds);
            
            // Dispatch initial selection event
            this.dispatchSelectionChange();
        }
    }
}