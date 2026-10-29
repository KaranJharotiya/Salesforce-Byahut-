import { LightningElement, wire, track, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import QuickActionModalSize from '@salesforce/resourceUrl/QuickActionModalSize';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import CART_LINE_ITEMOBJ from '@salesforce/schema/Cart_Line_Item__c';
import PRIORITY_FIELD from '@salesforce/schema/Cart_Line_Item__c.Priority__c';

// ONLY from EditSalesOrderController
import getCurrentSalesOrder from '@salesforce/apex/EditSalesOrderController.getCurrentSalesOrder';
import getExistingSalesOrderProducts from '@salesforce/apex/EditSalesOrderController.getExistingSalesOrderProducts';
import getIndustryValues from '@salesforce/apex/EditSalesOrderController.getIndustryValues';
import getSearchedProducts from '@salesforce/apex/EditSalesOrderController.getSearchedProducts';
import getSuggestedProduct from '@salesforce/apex/EditSalesOrderController.getSuggestedProduct';
import upsertSalesOrderLineItems from '@salesforce/apex/EditSalesOrderController.upsertSalesOrderLineItems';
import updateSalesOrderData from '@salesforce/apex/EditSalesOrderController.updateSalesOrderData';

export default class SalesOrderLineItemsForQuoteEditCmp extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName = 'Sales_Order__c';

    grandTotalAmount = 0;
    disableSave = false;

    // Filter Variables
    productName = '';
    productCASNumber = '';
    productBrand = '';
    productCode = '';
    productIndustry = '';
    value = '';
    @track options = [];
    selectedProductIds = [];

    @track productRecords = [];
    @track suggestedProductsList = [];
    @track currentSalesOrder = {};
    salesOrderDateOnly = ''; // Input date binding (YYYY-MM-DD)
    @track cartLineItemRecordTypeId;
    @track priorityOptions = [];

    isSalesOrderChange = false;
    isDateOnlyChanged = false; // Sirf tab true hoga jab Date change ho
    isLoading = false;

    // Pagination - Searched Products
    pageSize = 25;
    currentPage = 1;

    // Pagination - Suggested Products
    suggestedPageSize = 25;
    currentSuggestedPage = 1;

    pNameMatchingInfo = { primaryField: { fieldPath: 'Name' } };
    pNameDisplayInfo = {
        primaryField: 'Name',
        additionalFields: ['Product_Display_Info__c']
    };

    pCasMatchingInfo = { primaryField: { fieldPath: 'CAS_Number__c' } };
    pCasDisplayInfo = {
        primaryField: 'CAS_Number__c',
        additionalFields: ['Name']
    };

    pBrandMatchingInfo = { primaryField: { fieldPath: 'Name' } };
    pBrandDisplayInfo = { primaryField: 'Name' };

    pCodeMatchingInfo = { primaryField: { fieldPath: 'Code__c' } };
    pCodeDisplayInfo = {
        primaryField: 'Code__c',
        additionalFields: ['Name']
    };

    get isDataLoaded() {
        return this.productRecords.length > 0;
    }

    get isSuggestedDateLoad() {
        return this.suggestedProductsList.length > 0;
    }

    get totalProductRecords() {
        return this.productRecords.length;
    }

    get totalPages() {
        return Math.ceil(this.productRecords.length / this.pageSize) || 1;
    }

    get disablePaginationSearchProducts() {
        return this.productRecords.length <= 25;
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get displayedProductRecords() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        return this.productRecords.slice(start, end).map((record, index) => ({
            ...record,
            originalIndex: start + index,
            serialNumber: start + index + 1
        }));
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }

    get totalSuggestedRecords() {
        return this.suggestedProductsList.length;
    }

    get totalSuggestedPages() {
        return Math.ceil(this.suggestedProductsList.length / this.suggestedPageSize) || 1;
    }

    get disablePaginationSuggestedProducts() {
        return this.suggestedProductsList.length <= 25;
    }

    get isFirstSuggestedPage() {
        return this.currentSuggestedPage <= 1;
    }

    get isLastSuggestedPage() {
        return this.currentSuggestedPage >= this.totalSuggestedPages;
    }

    get displayedSuggestedProductRecords() {
        const start = (this.currentSuggestedPage - 1) * this.suggestedPageSize;
        const end = start + this.suggestedPageSize;
        return this.suggestedProductsList.slice(start, end).map((record, index) => ({
            ...record,
            originalIndex: start + index,
            serialNumber: start + index + 1
        }));
    }

    handleSuggestedPrevPage() {
        if (this.currentSuggestedPage > 1) {
            this.currentSuggestedPage--;
        }
    }

    handleSuggestedNextPage() {
        if (this.currentSuggestedPage < this.totalSuggestedPages) {
            this.currentSuggestedPage++;
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            const urlRecordId = currentPageReference.state?.c__recordId || currentPageReference.attributes?.recordId;
            if (urlRecordId && !this.recordId) {
                this.recordId = urlRecordId;
            }
            if (this.recordId) {
                this.loadInitialData();
            }
        }
    }

    @wire(getObjectInfo, { objectApiName: CART_LINE_ITEMOBJ })
    results({ error, data }) {
        if (data) {
            this.cartLineItemRecordTypeId = data.defaultRecordTypeId;
        } else if (error) {
            console.error('Error fetching CLI Object Info:', error);
            this.cartLineItemRecordTypeId = undefined;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$cartLineItemRecordTypeId', fieldApiName: PRIORITY_FIELD })
    picklistResults({ error, data }) {
        if (data) {
            this.priorityOptions = data.values;
        } else if (error) {
            console.error('Error priorityOptions', error);
            this.priorityOptions = undefined;
        }
    }

    @wire(getIndustryValues)
    wiredGetIndustryValues({ data, error }) {
        if (data) {
            this.options = data;
        } else if (error) {
            console.error('Error fetching industry values:', error);
        }
    }

    connectedCallback() {
        this.disableSave = false;
        loadStyle(this, QuickActionModalSize);
        if (this.recordId) {
            this.loadInitialData();
        }
    }

    disconnectedCallback() {
        const cssLinks = document.querySelectorAll('link');
        if (cssLinks) {
            cssLinks.forEach((link) => {
                if (link.href && link.href.includes('QuickActionModalSize')) {
                    link.remove();
                }
            });
        }
    }

    async loadInitialData() {
        try {
            this.isLoading = true;
            const so = await getCurrentSalesOrder({ salesOrderId: this.recordId });
            if (so) {
                this.currentSalesOrder = { ...so };
                if (so.Sales_Order_Date__c) {
                    this.salesOrderDateOnly = so.Sales_Order_Date__c.split('T')[0];
                }
            }
            await this.loadExistingSalesOrderLineItems();
        } catch (err) {
            console.error('Error loading initial SO data:', err);
        } finally {
            this.isLoading = false;
        }
    }

    async loadExistingSalesOrderLineItems() {
        try {
            const result = await getExistingSalesOrderProducts({ salesOrderId: this.recordId });
            if (result && result.length > 0) {
                let searchedRecords = [];
                this.selectedProductIds = result.map(item => item.id);

                result.forEach(item => {
                    const listPrice = item.listPrice || 0;
                    const qty = item.quantity || 0;
                    const discount = item.discount || 0;
                    const gst = item.gst || 0;

                    const amount = listPrice * qty;
                    const discountAmt = (amount * discount) / 100;
                    const afterDiscount = amount - discountAmt;
                    const gstAmt = (afterDiscount * gst) / 100;
                    const totalAmt = afterDiscount + gstAmt;

                    searchedRecords.push({
                        lineItemId: item.lineItemId,
                        Id: item.id,
                        Name: item.name,
                        CAS_Number__c: item.casNumber,
                        List_Price__c: item.listPrice,
                        Industry__c: item.industry,
                        Stock__c: item.stock,
                        Hold_Quantity__c: item.holdQuantity,
                        Available_Quantity__c: item.availableQuantity,
                        Code__c: item.code,
                        brand: item.brandName,
                        subBrand: item.subBrandName,
                        category: item.categoryName,
                        subCategory: item.subCategoryName,
                        Quantity: item.quantity,
                        Discount: item.discount,
                        gst: item.gst,
                        priority: item.priority || '',
                        promiseDispatchDate: item.promiseDispatchDate || null,
                        amount: amount > 0 ? amount.toFixed(2) : null,
                        discountAmount: discountAmt > 0 ? discountAmt.toFixed(2) : null,
                        afterDiscount: afterDiscount > 0 ? afterDiscount.toFixed(2) : null,
                        gstAmount: gstAmt > 0 ? gstAmt.toFixed(2) : null,
                        TotalAmount: totalAmt > 0 ? totalAmt.toFixed(2) : null,
                        isChecked: true,
                        isDisableQty: false,
                        isDisablePrice: false,
                        isEditingPrice: false
                    });
                });

                this.productRecords = searchedRecords;
                this.currentPage = 1;
                this.calculateGrandTotal();
            }
        } catch (error) {
            console.error('Error fetching Line Items:', error);
            this.showErrorNotification('Error fetching Line Items');
        }
    }

    salesOrderDataChange(event) {
        this.isSalesOrderChange = true;
        const field = event.target.dataset.field;
        if (field === 'Sales_Order_Date__c') {
            this.salesOrderDateOnly = event.detail.value;
            this.isDateOnlyChanged = true; // Date change explicitly mark hui
        } else {
            this.currentSalesOrder[field] = event.detail.value;
        }
    }

    handleRecordChange(event) {
        const selectedRecordId = event.detail?.recordId || null;
        this.productName = selectedRecordId ? selectedRecordId : '';
        this.currentPage = 1;
        this.searchProducts();
    }

    handleCASNumberChange(event) {
        const selectedRecordId = event.detail?.recordId || null;
        this.productCASNumber = selectedRecordId ? selectedRecordId : '';
        this.currentPage = 1;
        this.searchProducts();
    }

    handleBrandNameChange(event) {
        const selectedRecordId = event.detail?.recordId || null;
        this.productBrand = selectedRecordId ? selectedRecordId : '';
        this.currentPage = 1;
        this.searchProducts();
    }

    handleCodeChange(event) {
        const selectedRecordId = event.detail?.recordId || null;
        this.productCode = selectedRecordId ? selectedRecordId : '';
        this.currentPage = 1;
        this.searchProducts();
    }

    handleIndustrySelect(event) {
        this.productIndustry = event.target.value;
        this.currentPage = 1;
        this.searchProducts();
    }

    updatePrices(name, inputValue, row) {
        if (name === 'price') {
            row.List_Price__c = inputValue;
        } else if (name === 'qty') {
            row.Quantity = inputValue;
        } else if (name === 'discount') {
            row.Discount = inputValue;
        } else if (name === 'gst') {
            row.gst = inputValue;
        } else if (name === 'priority') {
            row.priority = String(inputValue);
        } else if (name === 'promiseDispatchDate' || name === 'Dispatch_Date') {
            row.promiseDispatchDate = inputValue;
        }

        const totalQuantityPrice = Number(row.List_Price__c || 0) * Number(row.Quantity || 0);
        row.amount = totalQuantityPrice.toFixed(2);

        row.discountAmount = ((totalQuantityPrice * Number(row.Discount || 0)) / 100).toFixed(2);
        row.afterDiscount = (totalQuantityPrice - Number(row.discountAmount || 0)).toFixed(2);

        if (row.gst > 0) {
            row.gstAmount = ((Number(row.afterDiscount || 0) * Number(row.gst || 0)) / 100).toFixed(2);
        } else {
            row.gstAmount = '0.00';
        }

        row.TotalAmount = (Number(row.afterDiscount || 0) + Number(row.gstAmount || 0)).toFixed(2);
    }

    async handleInputChange(event) {
        this.disableSave = false;
        const index = Number(event.target.dataset.index);
        const name = event.target.name;
        const id = event.target.dataset.id;
        const inputValue = event.target.value;

        const tempRecords = [...this.productRecords];
        const row = { ...tempRecords[index] };

        if (name === 'price' || name === 'qty' || name === 'discount' || name === 'gst') {
            this.updatePrices(name, Number(inputValue || 0), row);
        } else if (name === 'priority' || name === 'promiseDispatchDate') {
            this.updatePrices(name, inputValue, row);
        } else if (name === 'checkbox') {
            const isChecked = event.target.checked;
            row.isChecked = isChecked;
            row.isDisableQty = !isChecked;
            row.isDisablePrice = !isChecked;

            if (isChecked) {
                if (!this.selectedProductIds.includes(id)) {
                    this.selectedProductIds.push(id);
                }
            } else {
                this.selectedProductIds = this.selectedProductIds.filter(item => item !== id);
            }
            await this.loadSuggestedProducts();
        }

        tempRecords[index] = row;
        this.productRecords = tempRecords;
        this.calculateGrandTotal();
    }

    handleSuggestedInputChange(event) {
        const index = Number(event.target.dataset.index);
        const name = event.target.name;
        const inputValue = event.target.value;

        const tempRecords = [...this.suggestedProductsList];
        const row = { ...tempRecords[index] };

        if (name === 'price' || name === 'qty' || name === 'discount' || name === 'gst') {
            this.updatePrices(name, Number(inputValue || 0), row);
        } else if (name === 'priority' || name === 'Dispatch_Date') {
            this.updatePrices(name, inputValue, row);
        } else if (name === 'checkbox') {
            const isChecked = event.target.checked;
            row.isChecked = isChecked;
            row.isDisableQty = !isChecked;
            row.isDisablePrice = !isChecked;
        }

        tempRecords[index] = row;
        this.suggestedProductsList = tempRecords;
        this.calculateGrandTotal();
    }

    calculateGrandTotal() {
        const totalProducts = this.productRecords
            .filter(r => r.isChecked)
            .reduce((sum, r) => sum + Number(r.TotalAmount || 0), 0);

        const totalSuggested = this.suggestedProductsList
            .filter(r => r.isChecked)
            .reduce((sum, r) => sum + Number(r.TotalAmount || 0), 0);

        this.grandTotalAmount = (totalProducts + totalSuggested).toFixed(2);
    }

    async searchProducts() {
        try {
            this.isLoading = true;

            const selectedRecords = this.productRecords.filter(item =>
                this.selectedProductIds.includes(item.Id)
            );

            if (!this.productName && !this.productCASNumber && !this.productBrand && !this.productCode && !this.productIndustry) {
                this.productRecords = selectedRecords;
                this.calculateGrandTotal();
                return;
            }

            const result = await getSearchedProducts({
                productName: this.productName,
                productCASNumber: this.productCASNumber,
                productBrand: this.productBrand,
                productCode: this.productCode,
                productIndustry: this.productIndustry
            });

            const searchedRecords = [];
            if (result && result.length > 0) {
                result.forEach(item => {
                    const isAlreadySelected = this.selectedProductIds.includes(item.Id);
                    searchedRecords.push({
                        ...item,
                        brand: item.Brand__r?.Name || '',
                        subBrand: item.Sub_Brand__r?.Name || '',
                        category: item.Category__r?.Name || '',
                        subCategory: item.Sub_Category__r?.Name || '',
                        Hold_Quantity__c: item.Hold_Quantity__c || 0,
                        Available_Quantity__c: item.Available_Quantity__c || 0,
                        TotalAmount: null,
                        isChecked: isAlreadySelected,
                        isDisableQty: !isAlreadySelected,
                        isDisablePrice: !isAlreadySelected,
                        isEditingPrice: false
                    });
                });
            }

            const selectedIds = new Set(selectedRecords.map(item => item.Id));
            this.productRecords = [
                ...selectedRecords,
                ...searchedRecords.filter(item => !selectedIds.has(item.Id))
            ];

            if (searchedRecords.length === 0 && selectedRecords.length === 0) {
                this.showWarningNotification('No product found!');
            }
            this.calculateGrandTotal();
        } catch (error) {
            this.showErrorNotification('Internal server error ' + (error?.body?.message || error?.message));
        } finally {
            this.isLoading = false;
        }
    }

    async loadSuggestedProducts() {
        try {
            this.isLoading = true;
            const result = await getSuggestedProduct({ productIds: this.selectedProductIds });
            this.suggestedProductsList = [];
            this.currentSuggestedPage = 1;
            if (result && result.length > 0) {
                result.forEach(item => {
                    this.suggestedProductsList.push({
                        Id: item?.Product__c,
                        Name: item?.Product__r?.Name,
                        Industry__c: item?.Product__r?.Industry__c,
                        CAS_Number__c: item?.Product__r?.CAS_Number__c,
                        Code__c: item?.Product__r?.Code__c,
                        Stock__c: item?.Product__r?.Stock__c,
                        Hold_Quantity__c: item?.Product__r?.Hold_Quantity__c,
                        Available_Quantity__c: item?.Product__r?.Available_Quantity__c,
                        List_Price__c: item?.Product__r?.List_Price__c,
                        brand: item?.Product__r?.Brand__r?.Name || '',
                        subBrand: item?.Product__r?.Sub_Brand__r?.Name || '',
                        category: item?.Product__r?.Category__r?.Name || '',
                        subCategory: item?.Product__r?.Sub_Category__r?.Name || '',
                        TotalAmount: null,
                        isChecked: false,
                        isDisableQty: true,
                        isDisablePrice: true,
                        isEditingPrice: false
                    });
                });
            }
        } catch (error) {
            this.showErrorNotification('Internal server error ' + (error?.body?.message || error?.message));
        } finally {
            this.isLoading = false;
        }
    }

    async handleClickSave() {
        const mergedArray = [...new Set([...this.productRecords, ...this.suggestedProductsList])];

        // 1. Validation: Quantity must be greater than 0
        const invalidQtyItems = mergedArray.filter(
            item => item.isChecked && (!item.Quantity || Number(item.Quantity) <= 0)
        );

        if (invalidQtyItems.length > 0) {
            this.showErrorNotification('Please enter a valid Quantity (greater than 0) for all selected items.');
            return;
        }

        // 2. Validation: Quantity cannot exceed Available Quantity (Quotation Edit Parity)
        const excessQtyItems = mergedArray.filter(
            item => (item.isChecked || !item.isDisableQty) &&
                item.Available_Quantity__c != null &&
                Number(item.Quantity) > Number(item.Available_Quantity__c)
        );

        if (excessQtyItems.length > 0) {
            const productNames = excessQtyItems.map(item => item.Name).join(', ');
            this.showErrorNotification(`Quantity cannot be greater than Available Quantity for: ${productNames}`);
            return;
        }

        const selectedCart = [];
        mergedArray.forEach(item => {
            if (item.isChecked && !item.isDisableQty && item.Quantity && Number(item.Quantity) > 0) {
                const lineItemPayload = {
                    Product__c: item.Id,
                    Quantity__c: item.Quantity,
                    Amount__c: item.List_Price__c,
                    Total_Amount__c: item.TotalAmount,
                    Discount__c: item.Discount,
                    GST__c: item.gst,
                    Priority__c: item.priority,
                    Promise_Date__c: item.promiseDispatchDate
                };

                if (item.lineItemId) {
                    lineItemPayload.Id = item.lineItemId;
                }
                selectedCart.push(lineItemPayload);
            }
        });

        if (selectedCart.length === 0) {
            this.showWarningNotification('Please select products with valid quantity.');
            return;
        }

        try {
            this.isLoading = true;
            const result = await upsertSalesOrderLineItems({
                salesOrderId: this.recordId,
                lineItems: selectedCart
            });

            if (this.isSalesOrderChange) {
                await updateSalesOrderData({
                    recordId: this.recordId,
                    customerPurchaseOrderNo: this.currentSalesOrder.Customer_Purchase_Order_No__c,
                    salesOrderDate: this.salesOrderDateOnly ? this.salesOrderDateOnly : null,
                    isDateChanged: this.isDateOnlyChanged // Flag passing: True only if user changed the date
                });
            }

            if (result) {
                this.showSuccessNotification(result);
                this.closeScreen();
                this.disableSave = true;
                getRecordNotifyChange([{ recordId: this.recordId }]);
                setTimeout(() => {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: this.recordId,
                            objectApiName: 'Sales_Order__c',
                            actionName: 'view'
                        }
                    });
                }, 1000);
            }
        } catch (error) {
            this.showErrorNotification(error?.body?.message || error?.message || 'Error saving items');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.closeScreen();
        if (this.recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Sales_Order__c',
                    actionName: 'view'
                }
            });
        }
    }

    closeScreen() {
        try {
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            if (this.recordId) {
                setTimeout(() => {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: this.recordId,
                            objectApiName: 'Sales_Order__c',
                            actionName: 'view'
                        }
                    });
                }, 1000);
            }
        }
    }

    showSuccessNotification(messageText) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: messageText, variant: 'success' }));
    }

    showErrorNotification(messageText) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: messageText, variant: 'error' }));
    }

    showWarningNotification(messageText) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Warning', message: messageText, variant: 'warning' }));
    }

    handleEditPrice(event) {
        const index = Number(event.target.dataset.index);
        const tempRecords = [...this.productRecords];
        tempRecords[index] = { ...tempRecords[index], isEditingPrice: true };
        this.productRecords = tempRecords;
    }

    handlePriceBlur(event) {
        const index = Number(event.target.dataset.index);
        const tempRecords = [...this.productRecords];
        tempRecords[index] = { ...tempRecords[index], isEditingPrice: false };
        this.productRecords = tempRecords;
    }

    handleSuggestedEditPrice(event) {
        const index = Number(event.target.dataset.index);
        const tempRecords = [...this.suggestedProductsList];
        tempRecords[index] = { ...tempRecords[index], isEditingPrice: true };
        this.suggestedProductsList = tempRecords;
    }

    handleSuggestedPriceBlur(event) {
        const index = Number(event.target.dataset.index);
        const tempRecords = [...this.suggestedProductsList];
        tempRecords[index] = { ...tempRecords[index], isEditingPrice: false };
        this.suggestedProductsList = tempRecords;
    }
}