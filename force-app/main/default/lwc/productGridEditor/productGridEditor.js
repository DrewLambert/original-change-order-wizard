import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProducts from '@salesforce/apex/ChangeOrderController.getProducts';
import getPicklistValues from '@salesforce/apex/ChangeOrderController.getPicklistValues';
import getAvailableProductsForOpportunity from '@salesforce/apex/ChangeOrderController.getAvailableProductsForOpportunity';

export default class ProductGridEditor extends LightningElement {
    @api opportunityIds = [];
    @api productChanges = [];
    
    @track productItems = [];
    @track selectedRows = [];
    @track bulkNewProduct = '';
    @track bulkNewPrice = '';
    @track productOptions = [];
    @track productOptionsByOpportunity = new Map();
    @track isLoading = false;
    
    wiredProducts;
    wiredPicklistValues;
    
    @wire(getProducts, { opportunityIds: '$opportunityIds' })
    wiredGetProducts(result) {
        this.wiredProducts = result;
        this.isLoading = true;
        
        if (result.data) {
            this.processProductData(result.data);
            this.isLoading = false;
        } else if (result.error) {
            console.error('Error loading products:', result.error);
            this.showToast('Error', 'Failed to load products', 'error');
            this.isLoading = false;
        }
    }
    
    @wire(getPicklistValues)
    wiredGetPicklistValues(result) {
        this.wiredPicklistValues = result;
        if (result.data) {
            this.productOptions = result.data.machineTypes || [];
        }
    }
    
    get allSelected() {
        return this.productItems.length > 0 && this.selectedRows.length === this.productItems.length;
    }
    
    get applyBulkDisabled() {
        return this.selectedRows.length === 0 || (!this.bulkNewProduct && !this.bulkNewPrice);
    }
    
    get noProducts() {
        return !this.isLoading && this.productItems.length === 0;
    }
    
    get showSummary() {
        return this.productItems.length > 0;
    }
    
    get totalCount() {
        return this.productItems.length;
    }
    
    get modifiedCount() {
        return this.productItems.filter(item => item.isModified).length;
    }
    
    get totalImpact() {
        return this.productItems.reduce((total, item) => {
            if (item.isModified && item.newPrice) {
                return total + (parseFloat(item.newPrice) - parseFloat(item.originalPrice));
            }
            return total;
        }, 0);
    }
    
    processProductData(products) {
        this.productItems = products.map(product => {
            // Determine the correct price field based on recurring revenue
            const isRecurringRevenue = product.Recurring_Revenue__c === true;
            const originalPrice = isRecurringRevenue ? product.Lease_Rate__c : product.UnitPrice;
            
            return {
                id: product.Id,
                opportunityId: product.OpportunityId,
                opportunityName: product.Opportunity.Name,
                originalProductName: product.Product2.Name,
                originalProduct: product.Product2.Id,
                originalPrice: originalPrice,
                originalUnitPrice: product.UnitPrice,
                originalLeaseRate: product.Lease_Rate__c,
                isRecurringRevenue: isRecurringRevenue,
                newProduct: '',
                newPrice: '',
                selected: false,
                isModified: false,
                rowClass: '',
                availableProducts: []
            };
        });
        
        // Load available products for each opportunity
        this.loadAvailableProductsForOpportunities();
        
        // Apply existing changes if any
        this.applyExistingChanges();
    }
    
    async loadAvailableProductsForOpportunities() {
        try {
            // Get unique opportunity IDs
            const uniqueOpportunityIds = [...new Set(this.productItems.map(item => item.opportunityId))];
            
            // Load products for each opportunity
            for (const opportunityId of uniqueOpportunityIds) {
                try {
                    const availableProducts = await getAvailableProductsForOpportunity({ opportunityId });
                    this.productOptionsByOpportunity.set(opportunityId, availableProducts);
                    
                    // Update product items with available products
                    this.productItems = this.productItems.map(item => {
                        if (item.opportunityId === opportunityId) {
                            return {
                                ...item,
                                availableProducts: availableProducts
                            };
                        }
                        return item;
                    });
                } catch (error) {
                    console.error(`Error loading products for opportunity ${opportunityId}:`, error);
                    this.showToast('Warning', `Could not load available products for ${opportunityId}`, 'warning');
                }
            }
        } catch (error) {
            console.error('Error loading available products:', error);
            this.showToast('Error', 'Failed to load available products', 'error');
        }
    }
    
    applyExistingChanges() {
        if (this.productChanges && this.productChanges.length > 0) {
            this.productItems = this.productItems.map(item => {
                const existingChange = this.productChanges.find(change => change.lineItemId === item.id);
                if (existingChange) {
                    return {
                        ...item,
                        newProduct: existingChange.newProduct || '',
                        newPrice: existingChange.newPrice || '',
                        isModified: !!(existingChange.newProduct || existingChange.newPrice),
                        rowClass: 'slds-hint-parent'
                    };
                }
                return item;
            });
        }
    }
    
    handleRowSelection(event) {
        const itemId = event.target.dataset.id;
        const isSelected = event.target.checked;
        
        this.productItems = this.productItems.map(item => {
            if (item.id === itemId) {
                return { ...item, selected: isSelected };
            }
            return item;
        });
        
        this.updateSelectedRows();
    }
    
    handleSelectAll(event) {
        const isSelected = event.target.checked;
        
        this.productItems = this.productItems.map(item => ({
            ...item,
            selected: isSelected
        }));
        
        this.updateSelectedRows();
    }
    
    updateSelectedRows() {
        this.selectedRows = this.productItems.filter(item => item.selected).map(item => item.id);
    }
    
    handleNewProductChange(event) {
        const itemId = event.target.dataset.id;
        const newProduct = event.detail.value;
        
        this.updateProductItem(itemId, { newProduct });
    }
    
    handleNewPriceChange(event) {
        const itemId = event.target.dataset.id;
        const newPrice = event.target.value;
        
        this.updateProductItem(itemId, { newPrice });
    }
    
    updateProductItem(itemId, updates) {
        this.productItems = this.productItems.map(item => {
            if (item.id === itemId) {
                const updatedItem = { ...item, ...updates };
                updatedItem.isModified = !!(updatedItem.newProduct || updatedItem.newPrice);
                updatedItem.rowClass = updatedItem.isModified ? 'slds-hint-parent' : '';
                return updatedItem;
            }
            return item;
        });
        
        this.dispatchProductChange();
    }
    
    handleBulkNewProductChange(event) {
        this.bulkNewProduct = event.detail.value;
    }
    
    handleBulkNewPriceChange(event) {
        this.bulkNewPrice = event.target.value;
    }
    
    applyBulkToSelected() {
        if (this.selectedRows.length === 0) {
            this.showToast('Warning', 'Please select at least one product to apply bulk changes', 'warning');
            return;
        }
        
        this.productItems = this.productItems.map(item => {
            if (this.selectedRows.includes(item.id)) {
                const updates = {};
                if (this.bulkNewProduct) {
                    updates.newProduct = this.bulkNewProduct;
                }
                if (this.bulkNewPrice) {
                    updates.newPrice = this.bulkNewPrice;
                }
                
                const updatedItem = { ...item, ...updates };
                updatedItem.isModified = !!(updatedItem.newProduct || updatedItem.newPrice);
                updatedItem.rowClass = updatedItem.isModified ? 'slds-hint-parent' : '';
                return updatedItem;
            }
            return item;
        });
        
        this.dispatchProductChange();
        this.showToast('Success', `Bulk changes applied to ${this.selectedRows.length} product(s)`, 'success');
    }
    
    handleBulkAction(event) {
        const action = event.detail.value;
        
        switch (action) {
            case 'applyToAll':
                this.applyBulkToAll();
                break;
            case 'resetAll':
                this.resetAllToOriginal();
                break;
            case 'removeAll':
                this.removeAllChanges();
                break;
        }
    }
    
    applyBulkToAll() {
        if (!this.bulkNewProduct && !this.bulkNewPrice) {
            this.showToast('Warning', 'Please set bulk new product or price before applying to all', 'warning');
            return;
        }
        
        this.productItems = this.productItems.map(item => {
            const updates = {};
            if (this.bulkNewProduct) {
                updates.newProduct = this.bulkNewProduct;
            }
            if (this.bulkNewPrice) {
                updates.newPrice = this.bulkNewPrice;
            }
            
            const updatedItem = { ...item, ...updates };
            updatedItem.isModified = !!(updatedItem.newProduct || updatedItem.newPrice);
            updatedItem.rowClass = updatedItem.isModified ? 'slds-hint-parent' : '';
            return updatedItem;
        });
        
        this.dispatchProductChange();
        this.showToast('Success', `Bulk changes applied to all ${this.productItems.length} product(s)`, 'success');
    }
    
    resetAllToOriginal() {
        this.productItems = this.productItems.map(item => ({
            ...item,
            newProduct: '',
            newPrice: '',
            isModified: false,
            rowClass: ''
        }));
        
        this.dispatchProductChange();
        this.showToast('Success', 'All products reset to original values', 'success');
    }
    
    removeAllChanges() {
        this.resetAllToOriginal();
    }
    
    handleRemoveRow(event) {
        const itemId = event.target.dataset.id;
        
        this.productItems = this.productItems.map(item => {
            if (item.id === itemId) {
                return {
                    ...item,
                    newProduct: '',
                    newPrice: '',
                    isModified: false,
                    rowClass: ''
                };
            }
            return item;
        });
        
        this.dispatchProductChange();
    }
    
    handleResetRow(event) {
        const itemId = event.target.dataset.id;
        this.handleRemoveRow(event);
    }
    
    dispatchProductChange() {
        const productChanges = this.productItems
            .filter(item => item.isModified)
            .map(item => ({
                lineItemId: item.id,
                opportunityName: item.opportunityName,
                originalProduct: item.originalProductName,
                originalPrice: item.originalPrice,
                originalUnitPrice: item.originalUnitPrice,
                originalLeaseRate: item.originalLeaseRate,
                isRecurringRevenue: item.isRecurringRevenue,
                newProduct: item.newProduct,
                newPrice: item.newPrice
            }));
        
        const changeEvent = new CustomEvent('productchange', {
            detail: {
                productChanges
            }
        });
        this.dispatchEvent(changeEvent);
    }
    
    @api
    getModifiedProducts() {
        return this.productItems.filter(item => item.isModified);
    }
    
    @api
    validateChanges() {
        const modifiedProducts = this.getModifiedProducts();
        const hasInvalidChanges = modifiedProducts.some(item => {
            return (item.newProduct && !item.newPrice) || (!item.newProduct && item.newPrice);
        });
        
        if (hasInvalidChanges) {
            this.showToast('Error', 'Each product change must have both new product and new price', 'error');
            return false;
        }
        
        return true;
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}