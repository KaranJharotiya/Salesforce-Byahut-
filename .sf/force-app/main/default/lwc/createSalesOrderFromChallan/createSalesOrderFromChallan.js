import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getEligibleProducts from '@salesforce/apex/CreateSalesOrderFromChallanController.getEligibleProducts';
import createSalesOrder from '@salesforce/apex/CreateSalesOrderFromChallanController.createSalesOrder';

export default class CreateSalesOrderFromChallan extends NavigationMixin(LightningElement) {
    @api recordId;

    salesOrderDate;
    customerPurchaseOrderNo = '';
    products = [];
    blockerMessage;
    isAuthorized = true;
    canProceed = false;
    isLoading = false;
    hasLoaded = false;
    pageSize = 25;
    currentPage = 1;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        const urlRecordId = currentPageReference?.state?.c__recordId;
        if (urlRecordId) {
            this.recordId = urlRecordId;
        }
        if (this.recordId && !this.hasLoaded) {
            this.loadProducts();
        }
    }

    connectedCallback() {
        if (this.recordId && !this.hasLoaded) {
            this.loadProducts();
        }
    }

    get showAccessDenied() {
        return this.hasLoaded && !this.isAuthorized;
    }

    get showBlocker() {
        return this.hasLoaded && this.isAuthorized && !this.canProceed;
    }

    get showForm() {
        return this.hasLoaded && this.isAuthorized && this.canProceed;
    }

    get totalPages() {
        return Math.ceil(this.products.length / this.pageSize) || 1;
    }

    get disablePagination() {
        return this.products.length <= this.pageSize;
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get displayedProducts() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.products.slice(start, start + this.pageSize).map((product, index) => ({
            ...product,
            serialNumber: start + index + 1
        }));
    }

    loadProducts() {
        this.hasLoaded = true;
        this.isLoading = true;
        getEligibleProducts({ challanId: this.recordId })
            .then((result) => {
                this.isAuthorized = result.isAuthorized;
                this.canProceed = result.canProceed;
                this.blockerMessage = result.message;
                this.products = (result.products || []).map((product) => ({
                    ...product,
                    isSelected: true
                }));
                this.currentPage = 1;
            })
            .catch((error) => {
                this.isAuthorized = true;
                this.canProceed = false;
                this.blockerMessage = this.errorMessage(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleHeaderChange(event) {
        const field = event.target.dataset.field;
        if (field === 'Sales_Order_Date__c') {
            this.salesOrderDate = event.detail.value;
        } else if (field === 'Customer_Purchase_Order_No__c') {
            this.customerPurchaseOrderNo = event.detail.value;
        }
    }

    handleCheckboxChange(event) {
        const productId = event.target.dataset.id;
        const isChecked = event.target.checked;
        this.products = this.products.map((product) => (
            product.productId === productId
                ? { ...product, isSelected: isChecked }
                : product
        ));
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage += 1;
        }
    }

    handleSave() {
        if (!this.salesOrderDate) {
            this.showToast('Warning', 'Please select Sales Order Date.', 'warning');
            return;
        }
        if (this.customerPurchaseOrderNo && this.customerPurchaseOrderNo.length > 255) {
            this.showToast('Warning', 'Customer Purchase Order No cannot be longer than 255 characters.', 'warning');
            return;
        }

        const selectedProductIds = this.products
            .filter((product) => product.isSelected)
            .map((product) => product.productId);
        if (selectedProductIds.length === 0) {
            this.showToast('Warning', 'Please select at least one product to create the Sales Order.', 'warning');
            return;
        }

        this.isLoading = true;
        createSalesOrder({
            challanId: this.recordId,
            salesOrderJson: JSON.stringify({
                Sales_Order_Date__c: this.salesOrderDate,
                Customer_Purchase_Order_No__c: this.customerPurchaseOrderNo
            }),
            productIds: selectedProductIds
        })
            .then((salesOrderId) => {
                this.showToast('Success', 'Sales Order created successfully.', 'success');
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: salesOrderId,
                        objectApiName: 'Sales_Order__c',
                        actionName: 'view'
                    }
                });
            })
            .catch((error) => {
                this.showToast('Error', this.errorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCancel() {
        if (!this.recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Challan__c',
                actionName: 'view'
            }
        });
    }

    errorMessage(error) {
        return error?.body?.message || error?.message || 'The Sales Order could not be created.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}