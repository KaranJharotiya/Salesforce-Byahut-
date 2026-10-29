import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSearchedProducts from '@salesforce/apex/DirectProductSelectionController.getSearchedProducts';
import getIndustryValues from '@salesforce/apex/DirectProductSelectionController.getIndustryValues';
import getSuggestedProduct from '@salesforce/apex/DirectProductSelectionController.getSuggestedProduct';
import getProductNameById from '@salesforce/apex/DirectProductSelectionController.getProductNameById';
import getProductCasById from '@salesforce/apex/DirectProductSelectionController.getProductCasById';
import getProductCodeById from '@salesforce/apex/DirectProductSelectionController.getProductCodeById';
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import CART_LINE_ITEMOBJ from "@salesforce/schema/Cart_Line_Item__c";
import PRIORITY_FIELD from "@salesforce/schema/Cart_Line_Item__c.Priority__c";

export default class DirectProductSelectionCmp extends LightningElement {
    isLoading = false;
    grandTotalAmount = 0;

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
    cartLineItemRecordTypeId;
    priorityOptions;

    pNameDisplayInfo = {
        primaryField: 'Name',
        additionalFields: ['Product_Display_Info__c']
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
        } else if (error) {
            console.log('error priorityOptions', error);
            this.priorityOptions = undefined;
        }
    }
    // Pagination - Searched Products
    pageSize = 25;
    currentPage = 1;

    // Pagination - Suggested Products
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

    // Pagination Getters - Suggested Products
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

    pCasMatchingInfo = { primaryField: { fieldPath: 'CAS_Number__c' } };
    pCasDisplayInfo = { primaryField: 'CAS_Number__c', additionalFields: ['Name'] };
    pBrandMatchingInfo = { primaryField: { fieldPath: 'Name' } };
    pBrandDisplayInfo = { primaryField: 'Name' };
    pCodeMatchingInfo = { primaryField: { fieldPath: 'Code__c' } };
    pCodeDisplayInfo = { primaryField: 'Code__c', additionalFields: ['Name'] };

    @wire(getIndustryValues)
    wiredGetIndustryValues({ data, error }) {
        if (data) {
            this.options = data;
        }
    }

    _initialProducts = [];

    @api
    get initialProducts() {
        return this._initialProducts;
    }

    set initialProducts(value) {
        this._initialProducts = Array.isArray(value) ? value : [];
        this.applyInitialProducts();
    }

    applyInitialProducts() {
        if (!this._initialProducts.length) {
            return;
        }
        const existingIds = new Set(this.productRecords.map((row) => row.Id));
        const seededRows = [];
        this._initialProducts.forEach((product) => {
            const productId = product?.productId || product?.Id;
            if (!productId || existingIds.has(productId)) {
                return;
            }
            const row = {
                Id: productId,
                Name: product.productName || product.Name || '',
                Industry__c: product.industry || product.Industry__c || '',
                CAS_Number__c: product.casNumber || product.CAS_Number__c || '',
                Code__c: product.productCode || product.Code__c || '',
                brand: product.brandName || product.brand || '',
                subBrand: product.subBrandName || product.subBrand || '',
                category: product.categoryName || product.category || '',
                subCategory: product.subCategoryName || product.subCategory || '',
                Stock__c: product.stock ?? product.Stock__c ?? 0,
                Hold_Quantity__c: product.holdQuantity ?? product.Hold_Quantity__c ?? 0,
                Available_Quantity__c: product.availableQuantity ?? product.Available_Quantity__c ?? 0,
                List_Price__c: product.listPrice ?? product.List_Price__c ?? 0,
                Quantity: product.quantity ?? product.Quantity ?? 0,
                Discount: 0,
                gst: 0,
                isChecked: true,
                isDisableQty: false,
                isPriorityDisable: false,
                isDisablePrice: false,
                isEditingPrice: false,
                promiseDate: null,
                priority: ''
            };
            this.updatePrices('qty', Number(row.Quantity || 0), row);
            seededRows.push(row);
            existingIds.add(productId);
            if (!this.selectedProductIds.includes(productId)) {
                this.selectedProductIds.push(productId);
            }
        });
        if (!seededRows.length) {
            return;
        }
        this.productRecords = [...seededRows, ...this.productRecords];
        this.calculateGrandTotal();
        this.loadSuggestedProducts();
    }

    /* Exposed method to Parent with strict Quantity Validation */
    @api
    getSelectedLineItems() {
        const mergedArray = [...new Set([...this.productRecords, ...this.suggestedProductsList])];
        const selectedItems = [];
        let hasInvalidQty = false;

        mergedArray.forEach(item => {
            if (item.isChecked && !item.isDisableQty) {
                const qty = Number(item.Quantity) || 0;
                if (qty <= 0) {
                    hasInvalidQty = true;
                }
                selectedItems.push({
                    productId: item.Id,
                    quantity: item.Quantity,
                    discount: item.Discount || 0,
                    gst: item.gst || 0,
                    amount: item.List_Price__c || 0,
                    promiseDate: item.promiseDate || null,
                    priority: item.priority || '',
                    availableQuantity: item.Available_Quantity__c,
                    productName : item.Name
                });
            }
        });

        if (hasInvalidQty) {
            return {
                hasError: true,
                errorMessage: 'Please enter a valid Quantity (greater than 0) for all selected products.',
                selectedItems: []
            };
        }

        return {
            hasError: false,
            errorMessage: '',
            selectedItems: selectedItems
        };
    }

    async handleRecordChange(event) {
        const selectedRecordId = event.detail?.recordId || null;
        //this.productName = selectedRecordId ? await getProductNameById({ recordId: selectedRecordId }) : '';
        if(selectedRecordId){
            this.productName = selectedRecordId;
        }else{
            this.productName ='';
        }
        this.currentPage = 1;
        this.searchProducts();
    }

    async handleCASNumberChange(event) {
        const selectedRecordId = event.detail?.recordId || null;
        this.productCASNumber = selectedRecordId ? (await getProductCasById({ recordId: selectedRecordId }) || '') : '';
        if(selectedRecordId){
            this.productCASNumber = selectedRecordId;
        }else{
            this.productCASNumber ='';
        }
        this.currentPage = 1;
        await this.searchProducts();
    }

    async handleBrandNameChange(event) {
        this.productBrand = event.detail?.recordId || '';
        this.currentPage = 1;
        await this.searchProducts();
    }

    async handleCodeChange(event) {
        const selectedRecordId = event.detail?.recordId || null;
        this.productCode = selectedRecordId ? (await getProductCodeById({ recordId: selectedRecordId }) || '') : '';
        if(selectedRecordId){
            this.productCode = selectedRecordId;
        }else{
            this.productCode ='';
        }
        this.currentPage = 1;
        await this.searchProducts();
    }

    handleIndustrySelect(event) {
        this.productIndustry = event.target.value;
        this.currentPage = 1;
        this.searchProducts();
    }

    updatePrices(name, inputValue, row) {
        if (name === 'price') row.List_Price__c = inputValue;
        else if (name === 'qty') row.Quantity = inputValue;
        else if (name === 'discount') row.Discount = inputValue;
        else if (name === 'gst') row.gst = inputValue;

        const totalQuantityPrice = Number(row.List_Price__c || 0) * Number(row.Quantity || 0);
        row.amount = totalQuantityPrice;
        row.discountAmount = ((totalQuantityPrice * Number(row.Discount || 0)) / 100).toFixed(2);
        row.afterDiscount = (totalQuantityPrice - row.discountAmount).toFixed(2);
        row.gstAmount = row.gst > 0 ? ((row.afterDiscount * Number(row.gst || 0)) / 100).toFixed(2) : 0;
        row.TotalAmount = (Number(row.afterDiscount || 0) + Number(row.gstAmount || 0)).toFixed(2);
    }

    async handleInputChange(event) {
        const index = Number(event.target.dataset.index);
        const name = event.target.name;
        const id = event.target.dataset.id;

        const tempRecords = [...this.productRecords];
        const row = { ...tempRecords[index] };

        if (name === 'price' || name === 'qty' || name === 'discount' || name === 'gst') {
            this.updatePrices(name, Number(event.target.value || 0), row);
        } else if (name === 'promiseDate') {
            row.promiseDate = event.detail.value;
        } else if (name === 'priority') {
            row.priority = event.detail.value;
        } else if (name === 'checkbox') {
            const isChecked = event.target.checked;
            row.isChecked = isChecked;
            row.isDisableQty = !isChecked;
            row.isDisablePrice = !isChecked;
            row.isPriorityDisable = !isChecked;
            if (!this.selectedProductIds.includes(id) && isChecked) {
                this.selectedProductIds.push(id);
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

        const tempRecords = [...this.suggestedProductsList];
        const row = { ...tempRecords[index] };

        if (name === 'price' || name === 'qty' || name === 'discount' || name === 'gst') {
            this.updatePrices(name, Number(event.target.value || 0), row);
        } else if (name === 'promiseDate') {
            row.promiseDate = event.detail.value;
        } else if (name === 'priority') {
            row.priority = event.detail.value;
        } else if (name === 'checkbox') {
            const isChecked = event.target.checked;
            row.isChecked = isChecked;
            row.isDisableQty = !isChecked;
            row.isPriorityDisable = !isChecked;
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
            const selectedRecords = this.productRecords.filter(item => this.selectedProductIds.includes(item.Id));

            if (!this.productName && !this.productCASNumber && !this.productBrand && !this.productCode && !this.productIndustry) {
                this.productRecords = selectedRecords;
                this.calculateGrandTotal();
                return;
            }
            let result;
            await getSearchedProducts({
                productName: this.productName,
                productCASNumber: this.productCASNumber,
                productBrand: this.productBrand,
                productCode: this.productCode,
                productIndustry: this.productIndustry
            }).then((data) => {
                result = data;
            }).catch((error) => {
                console.log('getSearchedProducts Error', error);
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
                        TotalAmount: null,
                        isChecked: isAlreadySelected,
                        isDisableQty: !isAlreadySelected,
                        isPriorityDisable: !isAlreadySelected,
                        isDisablePrice: !isAlreadySelected,
                        isEditingPrice: false,
                        promiseDate: null,
                        priority: '',
                    });
                });
            }

            const selectedIds = new Set(selectedRecords.map(item => item.Id));
            this.productRecords = [
                ...selectedRecords,
                ...searchedRecords.filter(item => !selectedIds.has(item.Id))
            ];

            if (searchedRecords.length === 0 && selectedRecords.length === 0) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Warning', message: 'No product found!', variant: 'warning' }));
            }

            this.calculateGrandTotal();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error?.body?.message || error?.message, variant: 'error' }));
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
                        isPriorityDisable: true,
                        isDisablePrice: true,
                        isEditingPrice: false,
                        promiseDate: null,
                        priority: ''
                    });
                });
            }
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error?.body?.message || error?.message, variant: 'error' }));
        } finally {
            this.isLoading = false;
        }
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