import { LightningElement, wire, track, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { RefreshEvent } from 'lightning/refresh';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
// import { loadStyle } from 'lightning/platformResourceLoader';
// import QuickActionModalSize from '@salesforce/resourceUrl/QuickActionModalSize';
import getSelectedProduct from '@salesforce/apex/CartLineItemControllerForQuotationEdit.getSelectedProduct';
import getSearchedProducts from '@salesforce/apex/CartLineItemControllerForQuotationEdit.getSearchedProducts';
import createCartLineItem from '@salesforce/apex/CartLineItemControllerForQuotationEdit.createCartLineItem';
import getObjectNameFromId from '@salesforce/apex/CartLineItemControllerForQuotationEdit.getObjectNameFromId';
import getIndustryValues from '@salesforce/apex/CartLineItemControllerForQuotationEdit.getIndustryValues';
import getSuggestedProduct from '@salesforce/apex/CartLineItemControllerForQuotationEdit.getSuggestedProduct';
import getProductNameById from '@salesforce/apex/CartLineItemControllerForQuotationEdit.getProductNameById';
import getProductCasById from '@salesforce/apex/CartLineItemControllerForQuotationEdit.getProductCasById';
import getBrandNameById from '@salesforce/apex/CartLineItemControllerForQuotationEdit.getBrandNameById';
import getProductCodeById from '@salesforce/apex/CartLineItemControllerForQuotationEdit.getProductCodeById';
import createQuotationWithLineItems from '@salesforce/apex/CartLineItemControllerForQuotationEdit.createQuotationWithLineItems';
import createQuotationWithLineItemsOpp from '@salesforce/apex/CartLineItemControllerForQuotationEdit.createQuotationWithLineItemsOpp';
import updateQuotationLineItems from '@salesforce/apex/CartLineItemControllerForQuotationEdit.updateQuotationLineItems';
//import getExistingQuotationProducts from '@salesforce/apex/CartLineItemControllerForQuotationEdit.getExistingQuotationProducts';
import getExistingSalesOrderProducts from '@salesforce/apex/SalesOrderEditLineItemController.getExistingSalesOrderProducts';
import getCurrentSalesOrder from '@salesforce/apex/SalesOrderEditLineItemController.getCurrentSalesOrder';
import PRIORITY_FIELD from "@salesforce/schema/Cart_Line_Item__c.Priority__c";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import CART_LINE_ITEMOBJ from "@salesforce/schema/Cart_Line_Item__c";
import upsertSalesOrderLineItems from '@salesforce/apex/SalesOrderEditLineItemController.upsertSalesOrderLineItems'

export default class QuotationLineItemsForQuoteEditCmp extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    grandTotalAmount = 0;
    disableSave = false;
    // Lookup Fields Variables
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
    @track cartLineItemRecordTypeId = {};

    searchedText;

    isLoading = false;

    // Pagination Properties - Searched Products
    pageSize = 25;
    currentPage = 1;

    // Pagination Properties - Suggested Products
    suggestedPageSize = 25;
    currentSuggestedPage = 1;

    get isDataLoaded() {
        return this.productRecords.length > 0;
    }

    get isSuggestedDateLoad() {
        return this.suggestedProductsList.length > 0;
    }

    // Pagination Getters - Searched Products
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

    get recordStartIndex() {
        return this.productRecords.length === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1;
    }

    get recordEndIndex() {
        const calculatedEnd = this.currentPage * this.pageSize;
        return calculatedEnd > this.productRecords.length ? this.productRecords.length : calculatedEnd;
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

    // Pagination Getters & Handlers - Suggested Products
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

    connectedCallback() {
        console.log('connectedCallback');
        this.disableSave = false;
        // loadStyle(this, QuickActionModalSize);
        getCurrentSalesOrder({salesOrderId:this.recordId}).then(result => {
            this.currentSalesOrder = result;
            console.log(this.currentSalesOrder);
        })
    }

    // disconnectedCallback() {
    //     const cssLinks = document.querySelectorAll("link");
    //     if (cssLinks) {
    //         cssLinks.forEach((link) => {
    //             const href = link.href;
    //             if (href && href.includes('QuickActionModalSize')) {
    //                 link.remove();
    //             }
    //         });
    //     }
    // }

    pCasMatchingInfo = {
        primaryField: { fieldPath: 'CAS_Number__c' }
    };

    pCasDisplayInfo = {
        primaryField: 'CAS_Number__c',
        additionalFields: ['Name']
    };

    pBrandMatchingInfo = {
        primaryField: { fieldPath: 'Name' }
    };

    pBrandDisplayInfo = {
        primaryField: 'Name'
    };

    pCodeMatchingInfo = {
        primaryField: { fieldPath: 'Code__c' }
    };

    pCodeDisplayInfo = {
        primaryField: 'Code__c',
        additionalFields: ['Name']
    };

    @wire(getObjectInfo, { objectApiName: CART_LINE_ITEMOBJ })
    results({ error, data }) {
        if (data) {
            this.cartLineItemRecordTypeId = data.defaultRecordTypeId;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.cartLineItemRecordTypeId = undefined;
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$cartLineItemRecordTypeId", fieldApiName: PRIORITY_FIELD })
    picklistResults({ error, data }) {
        if (data) {
            this.priorityOptions = data.values;
            console.log('priorityOptions', this.priorityOptions);
        } else if (error) {
            console.log('error priorityOptions', error);
            this.priorityOptions = undefined;
        }
    }

    parentAccountSelectedRecord;
    handleValueSelectedOnAccount(event) {
        this.parentAccountSelectedRecord = event.detail;
        const fieldName = event.detail.fieldApiName;
        const fieldValue = event.detail.mainField;
        const objectName = event.detail.objectApiName;

        if (fieldName === 'Name' && objectName === 'Product__c') {
            this.productName = fieldValue;
        } else if (fieldName === 'CAS_Number__c' && objectName === 'Product__c') {
            this.productCASNumber = fieldValue;
        } else if (fieldName === 'Code__c' && objectName === 'Product__c') {
            this.productCode = fieldValue;
        } else if (fieldName === 'Name' && objectName === 'Brand_Master__c') {
            this.productBrand = event.detail.id;
        }
        this.currentPage = 1;
        this.searchProducts();
    }

    async handleRecordChange(event) {
        const selectedRecordId = event.detail?.recordId || null;
        const fieldName = event.target.dataset.field;
        const objectName = event.target.objectApiName;

        try {
            if (fieldName === 'Name' && objectName === 'Product__c') {
                if (selectedRecordId) {
                    const fetchedName = await getProductNameById({ recordId: selectedRecordId });
                    this.productName = fetchedName;
                } else {
                    this.productName = '';
                }
                this.currentPage = 1;
                this.searchProducts();
            }
        } catch (error) {
            console.error('Error fetching product name:', JSON.stringify(error));
        }
    }

    async handleCASNumberChange(event) {
        const selectedRecordId = event.detail?.recordId || null;
        try {
            if (selectedRecordId) {
                const fetchedCAS = await getProductCasById({ recordId: selectedRecordId });
                this.productCASNumber = fetchedCAS || '';
            } else {
                this.productCASNumber = '';
            }
            this.currentPage = 1;
            await this.searchProducts();
        } catch (error) {
            console.error('handleCASNumberChange Error :::', JSON.stringify(error));
        }
    }

    async handleBrandNameChange(event) {
        const selectedRecordId = event.detail?.recordId || null;
        try {
            if (selectedRecordId) {
                this.productBrand = selectedRecordId;
            } else {
                this.productBrand = '';
            }
            this.currentPage = 1;
            await this.searchProducts();
        } catch (error) {
            console.error('handleBrandNameChange Error :::', JSON.stringify(error));
        }
    }

    async handleCodeChange(event) {
        const selectedRecordId = event.detail?.recordId || null;
        try {
            if (selectedRecordId) {
                const fetchedCode = await getProductCodeById({ recordId: selectedRecordId });
                this.productCode = fetchedCode || '';
            } else {
                this.productCode = '';
            }
            this.currentPage = 1;
            await this.searchProducts();
        } catch (error) {
            console.error('handleCodeChange Error :::', JSON.stringify(error));
        }
    }

    handleValueRemoved(event) {
        const fieldName = event.detail.fieldApiName;
        const objectName = event.detail.objectApiName;

        if (fieldName === 'Name' && objectName === 'Product__c') {
            this.productName = '';
        } else if (fieldName === 'CAS_Number__c' && objectName === 'Product__c') {
            this.productCASNumber = '';
        } else if (fieldName === 'Code__c' && objectName === 'Product__c') {
            this.productCode = '';
        } else if (fieldName === 'Name' && objectName === 'Brand_Master__c') {
            this.productBrand = '';
        }
        this.currentPage = 1;
        this.searchProducts();
    }

    handleIndustrySelect(event) {
        const value = event.target.value;
        this.productIndustry = value;
        this.currentPage = 1;
        this.searchProducts();
    }

    handleChange(event) {
        this.value = event.detail.value;
    }

    @wire(CurrentPageReference)
    async getPageRef(pageRef) {
        if (pageRef) {
            if (!this.recordId && pageRef.state?.c__recordId) {
                this.recordId = pageRef.state.c__recordId;
            }
            if (!this.recordId && pageRef.attributes?.recordId) {
                this.recordId = pageRef.attributes.recordId;
            }

            if (this.recordId) {
                await this.getObjectApiName();
                if (this.objectApiName === 'Sales_Order__c') {
                    console.log('page ref method');
                    await this.loadExistingSalesOrderLineItems();
                    console.log('method called');
                }
            }
        }
    }

    @wire(getIndustryValues)
    wiredGetIndustryValues({ data, error }) {
        if (data) {
            this.options = data;
        }
    }

    async getObjectApiName() {
        if (!this.recordId) {
            return;
        }
        try {
            const res = await getObjectNameFromId({ recordId: this.recordId });
            if (res) {
                this.objectApiName = res;
            }
        } catch (error) {
            console.error(error);
        }
    }

    async loadExistingSalesOrderLineItems() {
        try {
            this.isLoading = true;
            //const result = await getExistingQuotationProducts({ quotationId: this.recordId });
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
                        checkbox:false,
                        lineItemId: item.lineItemId,
                        Id: item.id,
                        Name: item.name,
                        CAS_Number__c: item.casNumber,
                        List_Price__c: item.listPrice,
                        Industry__c: item.industry,
                        Stock__c: item.stock,
                        Code__c: item.code,

                        //brand: item.brandName,
                        //brandUrl: item.brandId ? `/lightning/r/Brand__c/${item.brandId}/view` : '',

                        //subBrand: item.subBrandName,
                        //subBrandUrl: item.subBrandId ? `/lightning/r/Brand__c/${item.subBrandId}/view` : '',

                        //category: item.categoryName,
                        //categoryUrl: item.categoryId ? `/lightning/r/Brand__c/${item.categoryId}/view` : '',

                        //subCategory: item.subCategoryName,
                        //subCategoryUrl: item.subCategoryId ? `/lightning/r/Brand__c/${item.subCategoryId}/view` : '',

                        Quantity: item.quantity,
                        Discount: item.discount,
                        gst: item.gst,

                        priority: item.priority,
                        promiseDispatchDate: item.promiseDispatchDate,

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
        } finally {
            this.isLoading = false;
        }
    }

    async handleClickSave() {
        const mergedArray = [...new Set([
            ...this.productRecords,
            ...this.suggestedProductsList
        ])];

        // 1. Validation: Checked product must have a valid quantity
        const invalidQtyItems = mergedArray.filter(
            item => item.isChecked && (!item.Quantity || Number(item.Quantity) <= 0)
        );

        if (invalidQtyItems.length > 0) {
            this.showErrorNotification('Please enter a valid quantity for all selected products.');
            return;
        }
        const selectedCart = [];

        // 2. Collect only checked items
        mergedArray.forEach(item => {
            if (item.isChecked && !item.isDisableQty && item.Quantity && Number(item.Quantity) > 0) {
                const lineItemPayload = {
                    Product__c: item.Id,
                    Quantity__c: item.Quantity,
                    Amount__c: item.List_Price__c,
                    Total_Amount__c: item.TotalAmount,
                    Discount__c: item.Discount,
                    GST__c: item.gst,
                    priority__c: item.priority,
                    Sales_Order_Date__c: item.promiseDispatchDate
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
            let result;

            /*if (this.objectApiName === 'Lead__c') {
                result = await createQuotationWithLineItems({
                    leadId: this.recordId,
                    lineItems: selectedCart
                });
            } else if (this.objectApiName === 'Opportunity__c') {
                result = await createQuotationWithLineItemsOpp({
                    oppId: this.recordId,
                    lineItems: selectedCart
                });
            } else if (this.objectApiName === 'Quotation__c') {
                result = await updateQuotationLineItems({
                    quotationId: this.recordId,
                    lineItems: selectedCart
                });

            }*/
            if (this.objectApiName === 'Sales_Order__c') {
                console.log('hello save method');
                result = await upsertSalesOrderLineItems({
                    salesOrderId: this.recordId,
                    lineItems: selectedCart
                })
            }

            if (result) {
                this.showSuccessNotification(result);
                this.closeScreen();
                this.disableSave = true;
                const targetObj = this.objectApiName || 'Sales_Order__c';
                getRecordNotifyChange([{ recordId: this.recordId }]);
                setTimeout(() => {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: this.recordId,
                            objectApiName: targetObj,
                            actionName: 'view'
                        }
                    });
                     
                }, 1000);
                
            }

        } catch (error) {
            this.showErrorNotification(
                error?.body?.message || error?.message || 'Error saving items'
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.closeScreen();
        if (this.recordId) {
            const targetObj = this.objectApiName || 'Sales_Order__c';
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: targetObj,
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
                const targetObj = this.objectApiName || 'Quotation__c';
                setTimeout(() => {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: this.recordId,
                            objectApiName: targetObj,
                            actionName: 'view'
                        }
                    });
                }, 1000);
            }
        }
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
        }

        const totalQuantityPrice = Number(row.List_Price__c || 0) * Number(row.Quantity || 0);
        row.amount = totalQuantityPrice;

        row.discountAmount = ((totalQuantityPrice * Number(row.Discount || 0)) / 100).toFixed(2);
        row.afterDiscount = (totalQuantityPrice - row.discountAmount).toFixed(2);

        if (row.gst > 0) {
            row.gstAmount = ((row.afterDiscount * Number(row.gst || 0)) / 100).toFixed(2);
        } else {
            row.gstAmount = 0;
        }

        row.TotalAmount = (Number(row.afterDiscount || 0) + Number(row.gstAmount || 0)).toFixed(2);
    }

    async handleInputChange(event) {
        this.disableSave = false;
        const index = Number(event.target.dataset.index);
        console.log('index '+index);
        const inputValue = Number(event.target.value || 0);
        console.log('inputValue '+inputValue);
        const name = event.target.name;
        console.log('name '+name);
        const id = event.target.dataset.id;
        console.log('id : '+id);

        const tempRecords = [...this.productRecords];
        const row = { ...tempRecords[index] };
        console.log(row);

        if (name === 'price' || name === 'qty' || name === 'discount' || name === 'gst') {
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
        console.log(JSON.stringify(this.productRecords));

        this.calculateGrandTotal();
    }

    handleSuggestedInputChange(event) {
        const index = Number(event.target.dataset.index);
        console.log('index : '+index);
        
        const inputValue = Number(event.target.value || 0);
        console.log('inputValue : '+inputValue)
        
        const name = event.target.name;
        console.log('name : '+name);

        console.log(JSON.stringify())
        const tempRecords = [...this.suggestedProductsList];
        const row = { ...tempRecords[index] };
        console.log(row);

        if (name === 'price' || name === 'qty' || name === 'discount' || name === 'gst') {
            this.updatePrices(name, inputValue, row);
        } else if (name === 'checkbox') {
            console.log('checkbox checked');
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

            const selectedRecords = this.productRecords.filter(
                item => this.selectedProductIds.includes(item.Id)
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
                        brandUrl: item.Brand__c ? `/lightning/r/Brand__c/${item.Brand__c}/view` : '',
                        subBrand: item.Sub_Brand__r?.Name || '',
                        subBrandUrl: item.Sub_Brand__c ? `/lightning/r/Brand__c/${item.Sub_Brand__c}/view` : '',
                        category: item.Category__r?.Name || '',
                        categoryUrl: item.Category__c ? `/lightning/r/Brand__c/${item.Category__c}/view` : '',
                        subCategory: item.Sub_Category__r?.Name || '',
                        subCategoryUrl: item.Sub_Category__c ? `/lightning/r/Brand__c/${item.Sub_Category__c}/view` : '',
                        TotalAmount: null,
                        isChecked: isAlreadySelected,
                        isDisableQty: !isAlreadySelected,
                        isDisablePrice: !isAlreadySelected,
                        isEditingPrice: false
                    });
                });
            }

            const selectedIds = new Set(selectedRecords.map(item => item.Id));

            const finalRecords = [
                ...selectedRecords,
                ...searchedRecords.filter(item => !selectedIds.has(item.Id))
            ];

            this.productRecords = finalRecords;

            if (searchedRecords.length === 0 && selectedRecords.length === 0) {
                this.showWarningNotification('No product found!');
            }

            this.calculateGrandTotal();

        } catch (error) {
            this.showErrorNotification(
                'Internal server error ' + (error?.body?.message || error?.message)
            );
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
                        checkbox:true,
                        Id: item?.Product__c,
                        Name: item?.Product__r?.Name,
                        Industry__c: item?.Product__r?.Industry__c,
                        CAS_Number__c: item?.Product__r?.CAS_Number__c,
                        Code__c: item?.Product__r?.Code__c,
                        Stock__c: item?.Product__r?.Stock__c,
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

    showSuccessNotification(messageText) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: messageText,
            variant: 'success'
        }));
    }

    showErrorNotification(messageText) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: messageText,
            variant: 'error'
        }));
    }

    showWarningNotification(messageText) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Warning',
            message: messageText,
            variant: 'warning'
        }));
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