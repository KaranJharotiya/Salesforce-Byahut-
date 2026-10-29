import { LightningElement, wire, track, api } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CurrentPageReference } from 'lightning/navigation';
import { RefreshEvent } from 'lightning/refresh';
// import { loadStyle } from 'lightning/platformResourceLoader';
// import QuickActionModalSize from '@salesforce/resourceUrl/QuickActionModalSize';
import getSelectedProduct from '@salesforce/apex/CartLineItemController.getSelectedProduct';
import getSearchedProducts from '@salesforce/apex/CartLineItemController.getSearchedProducts';
import createCartLineItem from '@salesforce/apex/CartLineItemController.createCartLineItem';
import getObjectNameFromId from '@salesforce/apex/CartLineItemController.getObjectNameFromId';
import getIndustryValues from '@salesforce/apex/CartLineItemController.getIndustryValues';
import getSuggestedProduct from '@salesforce/apex/CartLineItemController.getSuggestedProduct';

export default class CartLineItemComp extends LightningElement {





    // productColumns = columns;
    recordId;
    objectApiName;
    grandTotalAmount = 0;

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
    searchedText;

    isLoading = false;

    get isDataLoaded() {
        return this.productRecords.length > 0;
    }

    get isSuggestedDateLoad() {
        return this.suggestedProductsList.length > 0;
    }


    connectedCallback() {
        // loadStyle(this, QuickActionModalSize);
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



    parentAccountSelectedRecord;
    handleValueSelectedOnAccount(event) {
        console.log('event.detail >> ' + JSON.stringify(event.detail))
        this.parentAccountSelectedRecord = event.detail;

        const fieldName = event.detail.fieldApiName;
        const fieldValue = event.detail.mainField;
        const objectName = event.detail.objectApiName;



        if (fieldName == 'Name' && objectName == 'Product__c') {
            this.productName = fieldValue;
        } else if (fieldName == 'CAS_Number__c' && objectName == 'Product__c') {
            this.productCASNumber = fieldValue;
        } else if (fieldName == 'Code__c' && objectName == 'Product__c') {
            this.productCode = fieldValue;
        } else if (fieldName == 'Name' && objectName == 'Brand_Master__c') {
            this.productBrand = event.detail.id;
        }
        this.searchProducts();


    }

    handleValueRemoved(event) {
        console.log('event.detail >> ' + JSON.stringify(event.detail))

        const fieldName = event.detail.fieldApiName;
        const objectName = event.detail.objectApiName;

        if (fieldName == 'Name' && objectName == 'Product__c') {
            this.productName = '';
        } else if (fieldName == 'CAS_Number__c' && objectName == 'Product__c') {
            this.productCASNumber = '';
        } else if (fieldName == 'Code__c' && objectName == 'Product__c') {
            this.productCode = '';
        } else if (fieldName == 'Name' && objectName == 'Brand_Master__c') {
            this.productBrand = '';
        }
        this.searchProducts();

    }

    handleIndustrySelect(event) {
        const value = event.target.value;
        if (!value) {
            this.productRecords = [];
            this.suggestedProductsList = [];
            return;
        }
        console.log('value value >> ', value)
        this.productIndustry = value;
        this.searchProducts();
    }




    handleChange(event) {
        this.value = event.detail.value;
    }



    @wire(CurrentPageReference)
    getPageRef(pageRef) {
        if (pageRef) {
            console.log('pageRef >> ', pageRef)
            this.recordId = pageRef.state.recordId ? pageRef.state.recordId : pageRef.attributes.recordId;

            this.getObjectApiName()
            console.log('RecordId => ', this.recordId);
        }
    }


    @wire(getIndustryValues)
    wiredGetIndustryValues({ data, error }) {
        console.log('data >> ', data)
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
                console.log('res => ', res)
            }
        } catch (error) {

        }
    }


    async handleClickSave() {

        console.log('save clicked!!')

        const mergedArray = [...new Set([...this.productRecords, ...this.suggestedProductsList])];


        // if (this.selectedRows.length == 0) {
        //     this.showWarningNotification('Please select row to save record')
        //     return;
        // }

        console.log('mergedArray >> ', JSON.stringify(mergedArray))

        console.log('this.objectApiName >> ', JSON.stringify(this.objectApiName))

        const selectedCart = [];
        mergedArray.forEach(item => {
            if (!item.isDisableQty && item.Quantity && item.Quantity > 0) {
                if (this.objectApiName == 'Opportunity__c') {
                    selectedCart.push({
                        Opportunity__c: this.recordId,
                        Product__c: item.Id,
                        Quantity__c: item.Quantity,
                        Amount__c: item.List_Price__c,
                        Total_Amount__c: item.TotalAmount,
                        Discount__c: item.Discount,
                      //  GST__c: item.gst,
                        // After_Discount__c : item.afterDiscount
                    });
                } else if (this.objectApiName == 'Lead__c')
                    selectedCart.push({
                        Lead__c: this.recordId,
                        Product__c: item.Id,
                        Quantity__c: item.Quantity,
                        Amount__c: item.List_Price__c,
                        Total_Amount__c: item.TotalAmount,
                        Discount__c: item.Discount,
                     //   GST__c: item.gst,
                        // After_Discount__c : item.afterDiscount
                    });
            }

        })

        console.log('selectedCart >> ', JSON.stringify(selectedCart))

        if (selectedCart.length == 0) {
            return;
        }



        console.log('Selected Rows => ', JSON.stringify(selectedCart));


        try {
            this.isLoading = true;
            const result = await createCartLineItem({ cartLineItem: selectedCart });
            if (result) {
                // this.dispatchEvent(new RefreshEvent());
                this.showSuccessNotification(result);
                this.dispatchEvent(new CloseActionScreenEvent());

                
                setTimeout(() => {
                    window.location.reload();
                }, 1000)

            }
        } catch (error) {
            this.showErrorNotification(error.error);
        } finally {
            this.isLoading = false;
        }

        console.log('selectedCart >> ', JSON.stringify(selectedCart))
    }


    @track nameFilter = { criteria: [] };
    @track casFilter = { criteria: [] };



    async handleGetSelectProduct(selectedProductId) {
        try {
            const result = await getSelectedProduct({ productId: selectedProductId });
            if (result) {
                return result;
            }
        } catch (error) {
            console.log('error => ', JSON.stringify(error))
        }
    }


    updatePrices(name, inputValue, row) {
        if (name == 'qty') {
            row.Quantity = inputValue;

        } else if (name == 'discount') {
            row.Discount = inputValue;
        } else if (name == 'gst') {
            row.gst = inputValue;
        }

        const totalQuantityPrice = Number(row.List_Price__c || 0) * Number(row.Quantity || 0);

        row.amount = totalQuantityPrice;

            row.discountAmount = ((totalQuantityPrice * Number(row.Discount || 0)) / 100).toFixed(2);
            row.afterDiscount = (totalQuantityPrice - row.discountAmount).toFixed(2);
        




        if (row.gst > 0) {
            row.gstAmount = ((row.afterDiscount * Number(row.gst || 0)) / 100).toFixed(2);
        }


        row.TotalAmount = (Number(row.afterDiscount || 0) + Number(row.gstAmount || 0)).toFixed(2);
    }



    async handleInputChange(event) {
        const index = Number(event.target.dataset.index);
        const inputValue = Number(event.target.value || 0);
        const name = event.target.name;
        const id = event.target.dataset.id;

        const tempRecords = [...this.productRecords];
        const row = { ...tempRecords[index] };


        if (name == 'qty' || name == 'discount' || name == 'gst') {
            this.updatePrices(name, inputValue, row);
        } else if (name == 'checkbox') {
            const isChecked = event.target.checked;
            row.isDisableQty = !isChecked;
            if (!this.selectedProductIds.includes(id) && isChecked == true) {
                this.selectedProductIds.push(id);
            } else {
                this.selectedProductIds = this.selectedProductIds.filter(item => item !== id);
            }
           await this.loadSuggestedProducts();

        }
        tempRecords[index] = row;
        this.productRecords = tempRecords;

        console.log('this.productRecords >> ', JSON.stringify(this.productRecords[index]))

        this.grandTotalAmount = this.productRecords.reduce(
            (sum, r) => sum + Number(r.TotalAmount || 0),
            0
        );
    }



    handleSuggestedInputChange(event) {
        const index = Number(event.target.dataset.index);
        const qty = Number(event.target.value || 0);
        const name = event.target.name;

        const tempRecords = [...this.suggestedProductsList];
        const row = { ...tempRecords[index] };




        // if (name == 'qty') {
        //     row.Quantity = qty;
        //     row.TotalAmount = qty * Number(row.List_Price__c || 0);
        // }

        if (name == 'qty' || name == 'discount' || name == 'gst') {
            this.updatePrices(name, qty, row);
        } else if (name == 'checkbox') {
            const isChecked = event.target.checked;
            row.isDisableQty = !isChecked;


        }
        tempRecords[index] = row;
        this.suggestedProductsList = tempRecords;

        console.log('this.suggestedProductsList >> ', JSON.stringify(this.suggestedProductsList[index]))

        this.grandTotalAmount = this.suggestedProductsList.reduce(
            (sum, r) => sum + Number(r.TotalAmount || 0),
            0
        );
    }










    // --------------------------------------- Load Products -----------------------------



    async searchProducts() {
        try {
            this.productRecords = [];
            this.suggestedProductsList = [];
            this.handleValueSelectedOnAccount = [];
            if (!this.productName && !this.productCASNumber && !this.productBrand && !this.productCode && !this.productIndustry) {

                this.grandTotalAmount = null;
                return;
            }
            console.log('this.productIndustry >> ', this.productIndustry)
            this.isLoading = true;
            const result = await getSearchedProducts({
                productName: this.productName,
                productCASNumber: this.productCASNumber,
                productBrand: this.productBrand,
                productCode: this.productCode,
                productIndustry: this.productIndustry
            });
            if (result.length > 0) {



                result.forEach(item => {

                    this.productRecords.push({
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
                        isDisableQty: true
                    });
                });


                // this.showSuccessNotification('Products found successfully!');
                console.log('Result:', result);
            } else {
                this.productRecords = [];
                this.suggestedProductsList = [];
                this.showWarningNotification('No product found!');
                return;
            }


        } catch (error) {
            this.showErrorNotification('Internal server error ' + error.message);
            console.error('Error:', error);
        } finally {
            this.isLoading = false;
        }
    }




    async loadSuggestedProducts() {
        try {
            this.isLoading = true;
            console.log('this.selectedProductIds >> ', JSON.stringify(this.selectedProductIds))
            const result = await getSuggestedProduct({ productIds: this.selectedProductIds });
            this.suggestedProductsList = [];
            if (result.length > 0) {
                result.forEach(item => {
                    this.suggestedProductsList.push({
                        Id: item?.Product__c,
                        Name: item?.Product__r?.Name,
                        Industry__c: item?.Product__r?.Industry__c,
                        CAS_Number__c: item?.Product__r?.CAS_Number__c,
                        Code__c: item?.Product__r?.Code__c,
                        brand: item?.Product__r?.Brand__r?.Name,
                        subBrand: item?.Product__r?.Sub_Brand__r?.Name,
                        category: item?.Product__r?.Category__r?.Name,
                        subCategory: item?.Product__r?.Sub_Category__r?.Name,
                        Stock__c: item?.Product__r?.Stock__c,
                        List_Price__c: item?.Product__r?.List_Price__c,




                        brand: item?.Product__r?.Brand__r?.Name || '',
                        brandUrl: item?.Product__r?.Brand__c ? `/lightning/r/Brand__c/${item?.Product__r?.Brand__c}/view` : '',

                        subBrand: item?.Product__r?.Sub_Brand__r?.Name || '',
                        subBrandUrl: item?.Product__r?.Sub_Brand__c ? `/lightning/r/Brand__c/${item?.Product__r?.Sub_Brand__c}/view` : '',

                        category: item?.Product__r?.Category__r?.Name || '',
                        categoryUrl: item?.Product__r?.Category__c ? `/lightning/r/Brand__c/${item?.Product__r?.Category__c}/view` : '',

                        subCategory: item?.Product__r?.Sub_Category__r?.Name || '',
                        subCategoryUrl: item?.Product__r?.Sub_Category__c ? `/lightning/r/Brand__c/${item?.Product__r?.Sub_Category__c}/view` : '',

                        TotalAmount: null,
                        isDisableQty: true

                    });
                })
            }

            console.log('this.suggestedProductsList >> ', JSON.stringify(this.suggestedProductsList))
        } catch (error) {
            this.showErrorNotification('Internal server error ' + error.message);
        } finally {

            this.isLoading = false;
        }
    }





    // --------------------------------- Notifications ----------------------------
    showSuccessNotification(messageText) {
        const evt = new ShowToastEvent({
            title: 'Success',
            message: messageText,
            variant: 'success',
        });
        this.dispatchEvent(evt);
    }
    showErrorNotification(messageText) {
        const evt = new ShowToastEvent({
            title: 'Error',
            message: messageText,
            variant: 'error',
        });
        this.dispatchEvent(evt);
    }

    showWarningNotification(messageText) {
        const evt = new ShowToastEvent({
            title: 'Warning',
            message: messageText,
            variant: 'warning',
        });
        this.dispatchEvent(evt);
    }

}