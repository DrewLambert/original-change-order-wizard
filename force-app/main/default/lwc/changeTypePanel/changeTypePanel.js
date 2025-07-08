import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPicklistValues from '@salesforce/apex/ChangeOrderController.getPicklistValues';

export default class ChangeTypePanel extends LightningElement {
    @api selectedChangeTypes = {};
    @api changeValues = {};
    @api accountId;
    
    @track showValidationError = false;
    @track validationMessage = '';
    @track serviceModelOptions = [];
    @track pricingModelOptions = [];
    @track contactFilter = {};
    
    wiredPicklistValues;
    
    @wire(getPicklistValues)
    wiredGetPicklistValues(result) {
        this.wiredPicklistValues = result;
        if (result.data) {
            this.serviceModelOptions = result.data.serviceModels || [];
            this.pricingModelOptions = result.data.pricingModels || [];
        } else if (result.error) {
            this.showToast('Error', 'Failed to load picklist values', 'error');
        }
    }
    
    get todayDate() {
        return new Date().toISOString().split('T')[0];
    }
    
    // Icon getters for change type options
    get serviceModelIcon() {
        return this.selectedChangeTypes.changeServiceModel ? 'utility:check' : 'utility:add';
    }
    
    get serviceModelIconClass() {
        return this.selectedChangeTypes.changeServiceModel ? 'icon-selected' : 'icon-unselected';
    }
    
    get pricingModelIcon() {
        return this.selectedChangeTypes.changePricingModel ? 'utility:check' : 'utility:add';
    }
    
    get pricingModelIconClass() {
        return this.selectedChangeTypes.changePricingModel ? 'icon-selected' : 'icon-unselected';
    }
    
    get termIcon() {
        return this.selectedChangeTypes.changeTerm ? 'utility:check' : 'utility:add';
    }
    
    get termIconClass() {
        return this.selectedChangeTypes.changeTerm ? 'icon-selected' : 'icon-unselected';
    }
    
    get priceIcon() {
        return this.selectedChangeTypes.changePrice ? 'utility:check' : 'utility:add';
    }
    
    get priceIconClass() {
        return this.selectedChangeTypes.changePrice ? 'icon-selected' : 'icon-unselected';
    }
    
    get productIcon() {
        return this.selectedChangeTypes.changeProduct ? 'utility:check' : 'utility:add';
    }
    
    get productIconClass() {
        return this.selectedChangeTypes.changeProduct ? 'icon-selected' : 'icon-unselected';
    }
    
    get abatementIcon() {
        return this.selectedChangeTypes.addAbatement ? 'utility:check' : 'utility:add';
    }
    
    get abatementIconClass() {
        return this.selectedChangeTypes.addAbatement ? 'icon-selected' : 'icon-unselected';
    }
    
    get coTermIcon() {
        return this.selectedChangeTypes.coTermContracts ? 'utility:check' : 'utility:add';
    }
    
    get coTermIconClass() {
        return this.selectedChangeTypes.coTermContracts ? 'icon-selected' : 'icon-unselected';
    }
    
    // Option class getters for dynamic styling
    get serviceModelOptionClass() {
        return this.selectedChangeTypes.changeServiceModel ? 'change-type-option selected' : 'change-type-option';
    }
    
    get pricingModelOptionClass() {
        return this.selectedChangeTypes.changePricingModel ? 'change-type-option selected' : 'change-type-option';
    }
    
    get termOptionClass() {
        return this.selectedChangeTypes.changeTerm ? 'change-type-option selected' : 'change-type-option';
    }
    
    get priceOptionClass() {
        return this.selectedChangeTypes.changePrice ? 'change-type-option selected' : 'change-type-option';
    }
    
    get productOptionClass() {
        return this.selectedChangeTypes.changeProduct ? 'change-type-option selected' : 'change-type-option';
    }
    
    get abatementOptionClass() {
        return this.selectedChangeTypes.addAbatement ? 'change-type-option selected' : 'change-type-option';
    }
    
    get coTermOptionClass() {
        return this.selectedChangeTypes.coTermContracts ? 'change-type-option selected' : 'change-type-option';
    }
    
    connectedCallback() {
        // Initialize default values
        if (!this.changeValues.effectiveDate) {
            this.changeValues = {
                ...this.changeValues,
                effectiveDate: this.todayDate
            };
        }
        
        // Set up contact filter if accountId is provided
        if (this.accountId) {
            this.contactFilter = {
                criteria: [
                    {
                        fieldPath: 'AccountId',
                        operator: 'eq',
                        value: this.accountId
                    }
                ]
            };
        }
    }
    
    handleChangeTypeSelection(event) {
        const changeType = event.target.name;
        const isChecked = event.target.checked;
        
        this.selectedChangeTypes = {
            ...this.selectedChangeTypes,
            [changeType]: isChecked
        };
        
        // Clear related values when unchecking
        if (!isChecked) {
            this.clearRelatedValues(changeType);
        }
        
        this.showValidationError = false;
        this.dispatchChangeEvent();
    }
    
    handleChangeTypeToggle(event) {
        const changeType = event.currentTarget.dataset.type;
        const isCurrentlySelected = this.selectedChangeTypes[changeType] || false;
        
        this.selectedChangeTypes = {
            ...this.selectedChangeTypes,
            [changeType]: !isCurrentlySelected
        };
        
        // Clear related values when unchecking
        if (isCurrentlySelected) {
            this.clearRelatedValues(changeType);
        }
        
        this.showValidationError = false;
        this.dispatchChangeEvent();
    }
    
    clearRelatedValues(changeType) {
        const updatedValues = { ...this.changeValues };
        
        switch (changeType) {
            case 'changeServiceModel':
                delete updatedValues.serviceModel;
                break;
            case 'changePricingModel':
                delete updatedValues.pricingModel;
                break;
            case 'changeTerm':
                delete updatedValues.termLength;
                delete updatedValues.optOutDays;
                delete updatedValues.renewalTerm;
                break;
            case 'addAbatement':
                delete updatedValues.abatementPeriod;
                break;
        }
        
        this.changeValues = updatedValues;
    }
    
    handleServiceModelChange(event) {
        this.changeValues = {
            ...this.changeValues,
            serviceModel: event.detail.value
        };
        this.dispatchChangeEvent();
    }
    
    handlePricingModelChange(event) {
        this.changeValues = {
            ...this.changeValues,
            pricingModel: event.detail.value
        };
        this.dispatchChangeEvent();
    }
    
    handleTermLengthChange(event) {
        this.changeValues = {
            ...this.changeValues,
            termLength: event.target.value
        };
        this.dispatchChangeEvent();
    }
    
    handleOptOutDaysChange(event) {
        this.changeValues = {
            ...this.changeValues,
            optOutDays: event.target.value
        };
        this.dispatchChangeEvent();
    }
    
    handleRenewalTermChange(event) {
        this.changeValues = {
            ...this.changeValues,
            renewalTerm: event.target.value
        };
        this.dispatchChangeEvent();
    }
    
    handleAbatementPeriodChange(event) {
        this.changeValues = {
            ...this.changeValues,
            abatementPeriod: event.target.value
        };
        this.dispatchChangeEvent();
    }
    
    
    handleEffectiveDateChange(event) {
        this.changeValues = {
            ...this.changeValues,
            effectiveDate: event.target.value
        };
        this.dispatchChangeEvent();
    }
    
    dispatchChangeEvent() {
        const changeEvent = new CustomEvent('changetypeselection', {
            detail: {
                selectedChangeTypes: this.selectedChangeTypes,
                changeValues: this.changeValues
            }
        });
        this.dispatchEvent(changeEvent);
    }
    
    @api
    validateSelection() {
        // Check if at least one change type is selected
        const hasSelectedChangeType = Object.values(this.selectedChangeTypes).some(value => value === true);
        
        if (!hasSelectedChangeType) {
            this.showValidationError = true;
            this.validationMessage = 'Please select at least one change type.';
            return false;
        }
        
        // Check required fields for selected change types
        const validationErrors = [];
        
        if (this.selectedChangeTypes.changeServiceModel && !this.changeValues.serviceModel) {
            validationErrors.push('Service Model is required when Change Service Model is selected.');
        }
        
        if (this.selectedChangeTypes.changePricingModel && !this.changeValues.pricingModel) {
            validationErrors.push('Pricing Model is required when Change Pricing Model is selected.');
        }
        
        if (this.selectedChangeTypes.changeTerm) {
            if (!this.changeValues.termLength) {
                validationErrors.push('Term Length is required when Change Term is selected.');
            }
        }
        
        if (this.selectedChangeTypes.addAbatement && !this.changeValues.abatementPeriod) {
            validationErrors.push('Abatement Period is required when Add Abatement is selected.');
        }
        
        
        if (!this.changeValues.effectiveDate) {
            validationErrors.push('Effective Date is required.');
        }
        
        if (validationErrors.length > 0) {
            this.showValidationError = true;
            this.validationMessage = validationErrors.join(' ');
            return false;
        }
        
        this.showValidationError = false;
        return true;
    }
    
    @api
    getSelectedChangeTypes() {
        return Object.keys(this.selectedChangeTypes).filter(key => this.selectedChangeTypes[key]);
    }
    
    @api
    hasProductChanges() {
        return this.selectedChangeTypes.changeProduct || this.selectedChangeTypes.changePrice;
    }
    
    @api
    resetValidation() {
        this.showValidationError = false;
        this.validationMessage = '';
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}