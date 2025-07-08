import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';
import saveDraft from '@salesforce/apex/ChangeOrderController.saveDraft';
import loadDraft from '@salesforce/apex/ChangeOrderController.loadDraft';
import processChangeOrder from '@salesforce/apex/ChangeOrderController.processChangeOrder';

export default class ChangeOrderWizard extends NavigationMixin(LightningElement) {
    @api recordId;
    @api accountId;
    @api preselectedOpportunityIds = [];
    
    // Flow output parameters
    @api contractId;
    
    // Flow input parameters for admin control
    @api showWizardHeader = false;
    @api showStepIcons = false;
    @api showSummaryStats = false;
    @api showProductGrid = false;
    @api enableTwoColumnSummary = false;
    @api wizardThemeColor = 'blue';
    @api maxOpportunities = 10;
    @api customHeaderText;
    
    @track currentStep = 1;
    @track selectedOpportunities = [];
    @track selectedOpportunityData = [];
    @track selectedChangeTypes = {};
    @track changeValues = {};
    @track productChanges = [];
    @track isConfirmed = false;
    @track isLoading = false;
    
    // Removed auto-save functionality
    
    // Step navigation properties
    get isStepOne() {
        return this.currentStep === 1;
    }
    
    get isStepTwo() {
        return this.currentStep === 2;
    }
    
    get isStepThree() {
        return this.currentStep === 3;
    }
    
    get showProductStep() {
        return this.showProductGrid && (this.selectedChangeTypes.changeProduct || this.selectedChangeTypes.changePrice);
    }
    
    get stepOneClass() {
        return `slds-progress__item ${this.currentStep === 1 ? 'slds-is-active' : this.currentStep > 1 ? 'slds-is-completed' : ''}`;
    }
    
    get stepTwoClass() {
        if (!this.showProductStep) return '';
        return `slds-progress__item ${this.currentStep === 2 ? 'slds-is-active' : this.currentStep > 2 ? 'slds-is-completed' : ''}`;
    }
    
    get stepThreeClass() {
        const stepNumber = this.showProductStep ? 3 : 2;
        return `slds-progress__item ${this.currentStep === stepNumber ? 'slds-is-active' : this.currentStep > stepNumber ? 'slds-is-completed' : ''}`;
    }
    
    get showPrevious() {
        return this.currentStep > 1;
    }
    
    get showNext() {
        // Always show next until we reach the review step (step 3)
        return this.currentStep < 3;
    }
    
    get showSubmit() {
        // Show submit button when on the review step (step 3)
        return this.currentStep === 3;
    }
    
    get nextDisabled() {
        if (this.currentStep === 1) {
            return this.selectedOpportunities.length === 0 || Object.keys(this.selectedChangeTypes).length === 0;
        }
        return false;
    }
    
    get submitDisabled() {
        return !this.isConfirmed || this.isLoading;
    }

    get submitButtonLabel() {
        return this.isInFlowContext ? 'Create & Continue' : 'Create Change Order';
    }

    // UI Configuration Getters
    get wizardContainerClass() {
        return `wizard-container theme-${this.wizardThemeColor}`;
    }

    get displayHeaderText() {
        return this.customHeaderText || 'Change Order Wizard';
    }

    get effectiveAccountId() {
        // Use explicitly provided accountId, otherwise fall back to recordId
        return this.accountId || this.recordId;
    }

    get isInFlowContext() {
        // Check if we're running in a flow context
        return this.template.host && this.template.host.getAttribute('data-navigation-type') === 'flowscreen';
    }

    
    connectedCallback() {
        this.initializePreselectedOpportunities();
        this.loadExistingDraft();
    }

    initializePreselectedOpportunities() {
        if (this.preselectedOpportunityIds && this.preselectedOpportunityIds.length > 0) {
            this.selectedOpportunities = [...this.preselectedOpportunityIds];
        }
    }

    
    
    async loadExistingDraft() {
        try {
            const draftData = await loadDraft({ accountId: this.effectiveAccountId });
            if (draftData) {
                const draft = JSON.parse(draftData);
                // Only override preselected opportunities if no preselection was provided
                if (!this.preselectedOpportunityIds || this.preselectedOpportunityIds.length === 0) {
                    this.selectedOpportunities = draft.selectedOpportunities || [];
                }
                this.selectedChangeTypes = draft.selectedChangeTypes || {};
                this.changeValues = draft.changeValues || {};
                this.productChanges = draft.productChanges || [];
                this.currentStep = draft.currentStep || 1;
            }
        } catch (error) {
            console.error('Error loading draft:', error);
        }
    }
    
    
    handleOpportunitySelection(event) {
        this.selectedOpportunities = event.detail.selectedOpportunities;
        this.selectedOpportunityData = event.detail.selectedOpportunityData || [];
    }
    
    handleChangeTypeSelection(event) {
        this.selectedChangeTypes = event.detail.selectedChangeTypes;
        this.changeValues = event.detail.changeValues;
    }
    
    handleProductChange(event) {
        this.productChanges = event.detail.productChanges;
    }
    
    handleConfirmationChange(event) {
        this.isConfirmed = event.detail.isConfirmed;
    }
    
    goToStep(event) {
        const step = parseInt(event.target.dataset.step);
        if (step <= this.currentStep || this.canNavigateToStep(step)) {
            this.currentStep = step;
        }
    }
    
    canNavigateToStep(step) {
        if (step === 1) return true;
        if (step === 2) {
            // Can only navigate to product step if product changes are selected
            return this.showProductStep && this.selectedOpportunities.length > 0 && Object.keys(this.selectedChangeTypes).length > 0;
        }
        if (step === 3) {
            // Can navigate to review step if opportunities and change types are selected
            return this.selectedOpportunities.length > 0 && Object.keys(this.selectedChangeTypes).length > 0;
        }
        return false;
    }
    
    previousStep() {
        if (this.currentStep > 1) {
            if (this.currentStep === 3) {
                // If we're on review step, go back to product step if it exists, otherwise go to step 1
                if (this.showProductStep) {
                    this.currentStep = 2;
                } else {
                    this.currentStep = 1;
                }
            } else {
                // For any other step, just go back one step
                this.currentStep--;
            }
        }
    }
    
    nextStep() {
        if (this.currentStep < 3) {
            if (this.currentStep === 1) {
                // If product changes are selected, go to product step (step 2)
                // Otherwise, skip directly to review step (step 3)
                if (this.showProductStep) {
                    this.currentStep = 2;
                } else {
                    this.currentStep = 3;
                }
            } else if (this.currentStep === 2) {
                // From product step, always go to review step
                this.currentStep = 3;
            }
        }
    }
    
    async submitChangeOrder() {
        this.isLoading = true;
        
        try {
            // Validate data before submitting
            if (!this.selectedOpportunities || this.selectedOpportunities.length === 0) {
                this.showToast('Error', 'Please select at least one opportunity.', 'error');
                return;
            }
            
            const hasSelectedChangeTypes = Object.values(this.selectedChangeTypes).some(value => value === true);
            if (!hasSelectedChangeTypes) {
                this.showToast('Error', 'Please select at least one change type.', 'error');
                return;
            }
            
            // Check if all selected opportunities have valid IDs
            console.log('Validating selected opportunities:', this.selectedOpportunities);
            for (let i = 0; i < this.selectedOpportunities.length; i++) {
                const oppId = this.selectedOpportunities[i];
                if (!oppId || typeof oppId !== 'string' || oppId.length < 15) {
                    console.error('Invalid opportunity ID at index', i, ':', oppId);
                    this.showToast('Error', `Invalid opportunity ID: ${oppId}`, 'error');
                    return;
                }
            }
            
            // Properly format effective date for Apex Date type
            let effectiveDate;
            if (this.changeValues.effectiveDate) {
                // If effectiveDate is already a string in YYYY-MM-DD format, use it directly
                // If it's a Date object, convert it to YYYY-MM-DD format without timezone issues
                if (typeof this.changeValues.effectiveDate === 'string') {
                    effectiveDate = this.changeValues.effectiveDate;
                } else if (this.changeValues.effectiveDate instanceof Date) {
                    // Use local date components to avoid timezone conversion issues
                    const date = this.changeValues.effectiveDate;
                    effectiveDate = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
                } else {
                    // Try to create a Date object and convert it using local date components
                    const date = new Date(this.changeValues.effectiveDate);
                    effectiveDate = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
                }
            } else {
                // Default to today's date using local date components
                const today = new Date();
                effectiveDate = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
            }
            
            const request = {
                opportunityIds: this.selectedOpportunities,
                changeTypes: this.selectedChangeTypes,
                changeValues: this.changeValues,
                productChanges: this.productChanges || [],
                effectiveDate: effectiveDate
            };
            
            console.log('Submitting change order with request:', JSON.stringify(request, null, 2));
            console.log('Request details:');
            console.log('- OpportunityIds:', this.selectedOpportunities);
            console.log('- OpportunityIds type:', typeof this.selectedOpportunities);
            console.log('- OpportunityIds isArray:', Array.isArray(this.selectedOpportunities));
            console.log('- OpportunityIds length:', this.selectedOpportunities.length);
            
            // Log each opportunity ID to check format
            if (this.selectedOpportunities && this.selectedOpportunities.length > 0) {
                this.selectedOpportunities.forEach((oppId, index) => {
                    console.log(`  - Opportunity[${index}]: "${oppId}" (type: ${typeof oppId}, length: ${oppId ? oppId.length : 'null'})`);
                });
            }
            
            console.log('- EffectiveDate:', effectiveDate);
            console.log('- EffectiveDate type:', typeof effectiveDate);
            console.log('- ChangeTypes:', this.selectedChangeTypes);
            console.log('- ChangeTypes type:', typeof this.selectedChangeTypes);
            console.log('- ChangeValues:', this.changeValues);
            console.log('- ChangeValues type:', typeof this.changeValues);
            console.log('- ProductChanges:', this.productChanges);
            console.log('- ProductChanges type:', typeof this.productChanges);
            console.log('- ProductChanges isArray:', Array.isArray(this.productChanges));
            
            console.log('About to call processChangeOrder with request:', JSON.stringify(request, null, 2));
            
            const result = await processChangeOrder(request);
            
            console.log('Apex result received:', JSON.stringify(result, null, 2));
            console.log('Result type:', typeof result);
            console.log('Result success property:', result ? result.success : 'result is null/undefined');
            
            if (result && result.success) {
                this.showToast('Success', 'Change order created successfully', 'success');
                if (result.contractId) {
                    // Set the output variable for flow
                    this.contractId = result.contractId;
                    
                    // If in flow context, dispatch the next event
                    if (this.isInFlowContext) {
                        const navigateNextEvent = new FlowNavigationNextEvent();
                        this.dispatchEvent(navigateNextEvent);
                    } else {
                        // Otherwise navigate to the record
                        this.navigateToRecord(result.contractId);
                    }
                }
            } else {
                console.error('Apex errors:', result ? result.errors : 'No result returned');
                const errorMessages = (result && result.errors) ? result.errors.join(', ') : 'Unknown error occurred';
                this.showToast('Error', errorMessages, 'error');
            }
        } catch (error) {
            console.error('Error submitting change order:', error);
            console.error('Error type:', error.constructor.name);
            console.error('Error message:', error.message);
            console.error('Error body:', error.body);
            console.error('Full error object:', JSON.stringify(error, Object.getOwnPropertyNames(error)));
            
            let errorMessage = 'Failed to submit change order. Please try again.';
            
            // Better error message extraction
            if (error.body) {
                if (error.body.message) {
                    errorMessage = error.body.message;
                } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                    errorMessage = error.body.pageErrors[0].message;
                } else if (error.body.fieldErrors) {
                    const fieldErrors = Object.values(error.body.fieldErrors);
                    if (fieldErrors.length > 0 && fieldErrors[0].length > 0) {
                        errorMessage = fieldErrors[0][0].message;
                    }
                }
            } else if (error.message) {
                errorMessage = error.message;
            }
            
            console.error('Extracted error message:', errorMessage);
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    cancelWizard() {
        this.navigateToRecord(this.recordId);
    }
    
    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}