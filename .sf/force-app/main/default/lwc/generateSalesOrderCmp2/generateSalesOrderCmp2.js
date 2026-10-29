import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getQuotationsWithItems from '@salesforce/apex/GenerateSalesOrderQuotationController.getQuotationsWithItems';
import saveSalesOrderRec from '@salesforce/apex/GenerateSalesOrderQuotationController.saveSalesOrderRec';
import getEligibleProducts from '@salesforce/apex/CreateSalesOrderFromChallanController.getEligibleProducts';
import saveVFAsFile from '@salesforce/apex/SaveSalesOrderAttachment.saveVFAsFile';
import { refreshApex } from '@salesforce/apex';
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';
import CART_LINE_ITEMOBJ from "@salesforce/schema/Cart_Line_Item__c";
import PRIORITY_FIELD from "@salesforce/schema/Cart_Line_Item__c.Priority__c";

// Jin profiles ko block karna hai unke exact names yahan daalein
const RESTRICTED_PROFILES = [
    'Operations Executive'
];

export default class GenerateSalesOrderCmp2 extends NavigationMixin(LightningElement) {
    @api recordId = null;

    @track salesOrderId;
    @track quotations = [];
    @track salesorderRec = {};

    selectedQuotationId = null;
    wiredQuotationsResult;
    isLoading = false;
    disableSave = false;
    cartLineItemRecordTypeId;
    priorityOptions;
    userProfileName;
    fromChallan = false;
    challanId = null;
    loadedChallanId = null;
    challanChecked = false;
    challanCanProceed = false;
    challanAccessDenied = false;
    challanMessage = '';
    initialProducts = [];

    @wire(getRecord, { recordId: USER_ID, fields: [PROFILE_NAME_FIELD] })
    wireUser({ error, data }) {
        if (data) {
            this.userProfileName = data.fields?.Profile?.value?.fields?.Name?.value;
        } else if (error) {
            console.error('Error fetching user profile:', error);
        }
    }

    get isAccessDenied() {
        if (this.fromChallan) {
            return this.challanAccessDenied === true;
        }
        return this.userProfileName && RESTRICTED_PROFILES.includes(this.userProfileName);
    }

    get challanBlocked() {
        return this.fromChallan && this.challanChecked && this.challanCanProceed !== true && this.challanAccessDenied !== true;
    }

    get showQuotations() {
        return !this.fromChallan && this.hasQuotations;
    }

    get showProductSelection() {
        return this.fromChallan ? this.challanCanProceed === true : !this.hasQuotations;
    }

    get backLabel() {
        return this.fromChallan ? 'Back to Challan' : 'Back to Opportunity';
    }

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

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            const urlRecordId = currentPageReference.state.c__recordId;
            const urlChallanId = currentPageReference.state.c__challanId;
            if (urlRecordId) {
                this.recordId = urlRecordId;
            }
            if (urlChallanId && urlChallanId !== this.loadedChallanId) {
                this.loadedChallanId = urlChallanId;
                this.challanId = urlChallanId;
                this.fromChallan = true;
                this.loadChallanProducts();
            }
        }
    }

    get hasQuotations() {
        return this.quotations && this.quotations.length > 0;
    }

    @wire(getQuotationsWithItems, { opportunityId: '$recordId' })
    wiredQuotations(result) {
        this.wiredQuotationsResult = result;
        const { data, error } = result;

        if (data) {
            this.quotations = JSON.parse(JSON.stringify(data)).map(qWrap => {
                qWrap.lineItems = qWrap.lineItems.map(item => ({
                    ...item,
                    isDisabled: false,
                    isFieldDisabled: true,
                    isEditingPrice: false,
                    promiseDate: null,
                    priority:''
                }));
                return qWrap;
            });
        } else if (error) {
            console.error('Error fetching quotations', error);
            this.showToast('Error', 'Error fetching quotations.', 'error');
        }
    }

    async loadChallanProducts() {
        this.isLoading = true;
        try {
            const result = await getEligibleProducts({ challanId: this.challanId });
            this.challanChecked = true;
            this.challanAccessDenied = result?.isAuthorized !== true;
            this.challanCanProceed = result?.canProceed === true;
            this.challanMessage = result?.message || '';
            if (result?.opportunityId) {
                this.recordId = result.opportunityId;
            }
            this.initialProducts = this.challanCanProceed ? (result.products || []) : [];
        } catch (error) {
            this.challanChecked = true;
            this.challanCanProceed = false;
            this.challanAccessDenied = false;
            this.challanMessage = error?.body?.message || error?.message || 'The Challan products could not be loaded.';
            this.initialProducts = [];
        } finally {
            this.isLoading = false;
        }
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        this.salesorderRec[field] = event.detail.value;
    }

    handleEditPrice(event) {
        const quoteId = event.target.dataset.quoteid;
        const itemId = event.target.dataset.itemid;

        this.quotations = this.quotations.map(qWrap => {
            if (qWrap.quotation.Id === quoteId) {
                qWrap.lineItems = qWrap.lineItems.map(li => {
                    if (li.item.Id === itemId) {
                        return { ...li, isEditingPrice: true };
                    }
                    return li;
                });
            }
            return qWrap;
        });
    }

    handlePriceBlur(event) {
        const quoteId = event.target.dataset.quoteid;
        const itemId = event.target.dataset.itemid;

        this.quotations = this.quotations.map(qWrap => {
            if (qWrap.quotation.Id === quoteId) {
                qWrap.lineItems = qWrap.lineItems.map(li => {
                    if (li.item.Id === itemId) {
                        return { ...li, isEditingPrice: false };
                    }
                    return li;
                });
            }
            return qWrap;
        });
    }

    handleCheckboxChange(event) {
        const quoteId = event.target.dataset.quoteid;
        const itemId = event.target.dataset.itemid;
        const isChecked = event.target.checked;

        this.quotations = this.quotations.map(qWrap => {
            if (qWrap.quotation.Id === quoteId) {
                qWrap.lineItems = qWrap.lineItems.map(li => {
                    if (li.item.Id === itemId) {
                        return {
                            ...li,
                            isSelected: isChecked,
                            isFieldDisabled: !isChecked,
                            isEditingPrice: false
                        };
                    }
                    return li;
                });
            }
            return qWrap;
        });

        const hasSelectedItems = this.quotations.some(q => q.lineItems.some(li => li.isSelected));

        if (hasSelectedItems) {
            this.selectedQuotationId = quoteId;
            this.quotations = this.quotations.map(qWrap => {
                const isOtherQuote = qWrap.quotation.Id !== this.selectedQuotationId;
                qWrap.lineItems = qWrap.lineItems.map(li => ({ ...li, isDisabled: isOtherQuote }));
                return qWrap;
            });
        } else {
            this.selectedQuotationId = null;
            this.quotations = this.quotations.map(qWrap => {
                qWrap.lineItems = qWrap.lineItems.map(li => ({ ...li, isDisabled: false, isFieldDisabled: true, isEditingPrice: false }));
                return qWrap;
            });
        }
    }

    handleRowFieldChange(event) {
        const quoteId = event.target.dataset.quoteid;
        const itemId = event.target.dataset.itemid;
        const field = event.target.dataset.field;
        const rawValue = event.detail.value;

        this.quotations = this.quotations.map(qWrap => {
            if (qWrap.quotation.Id === quoteId) {
                qWrap.lineItems = qWrap.lineItems.map(li => {
                    if (li.item.Id === itemId) {
                        if (field === 'promiseDate' || field === 'priority') {
                            li[field] = rawValue;
                        } else {
                            const value = parseFloat(rawValue) || 0;
                            li[field] = value;

                            const price = parseFloat(li.price) || 0;
                            const qty = parseFloat(li.quantity) || 0;
                            const disc = parseFloat(li.discount) || 0;
                            const gst = parseFloat(li.gst) || 0;

                            const amt = price * qty;
                            const discAmt = (amt * disc) / 100;
                            const afterDisc = amt - discAmt;
                            const gstAmt = (afterDisc * gst) / 100;
                            const totAmt = afterDisc + gstAmt;

                            li.amount = amt.toFixed(2);
                            li.discountAmount = discAmt.toFixed(2);
                            li.afterDiscount = afterDisc.toFixed(2);
                            li.gstAmount = gstAmt.toFixed(2);
                            li.totalAmount = totAmt.toFixed(2);
                        }
                    }
                    return li;
                });
            }
            return qWrap;
        });
    }

    handleFooterSave() {
        if (this.isAccessDenied) {
            this.showToast('Access Denied', "You don't have access to generate a Sales Order.", 'error');
            return;
        }

        if (!this.recordId) {
            this.showToast('Error', 'Opportunity record not found.', 'error');
            return;
        }
        if (!this.salesorderRec.Sales_Order_Date__c) {
            this.showToast('Warning', 'Please select Sales Order Date.', 'warning');
            return;
        }

        let selectedItems = [];

        if (this.hasQuotations && !this.fromChallan) {
            let hasAnySelected = false;
            let hasInvalidQty = false;
            let excessQtyProducts = [];
            if (this.selectedQuotationId && this.quotations) {
                this.quotations.forEach(qWrap => {
                    if (qWrap.quotation.Id === this.selectedQuotationId) {
                        qWrap.lineItems.forEach(li => {
                            if (li.isSelected) {
                                hasAnySelected = true;
                                const qty = parseFloat(li.quantity) || 0;
                                if (qty <= 0) {
                                    hasInvalidQty = true;
                                }
                                // Available Quantity validation check
                                const availableQty = parseFloat(li.availableQuantity) || 0;
                                if (availableQty != null && qty > parseFloat(availableQty)) {
                                    const prodName = li.item?.Product__r?.Name || li.Name || li.productName || 'Product';
                                    excessQtyProducts.push(prodName);
                                }
                                selectedItems.push({
                                    productId: li.item.Product__c,
                                    quantity: li.quantity,
                                    discount: li.discount,
                                    gst: li.gst,
                                    amount: li.amount,
                                    promiseDate: li.promiseDate,
                                    priority: li.priority
                                });
                            }
                        });
                    }
                });
            }

            if (!hasAnySelected || selectedItems.length === 0) {
                this.showToast('Warning', 'Please select at least one line item to generate Sales Order.', 'warning');
                return;
            }

            if (hasInvalidQty) {
                this.showToast('Error', 'Please enter a valid Quantity (greater than 0) for all selected items.', 'error');
                return;
            }
           
            
            if (excessQtyProducts.length > 0) {
                this.showToast(
                    'Error',
                    `Quantity cannot be greater than Available Quantity for: ${excessQtyProducts.join(', ')}`,
                    'error'
                );
                return;
            }
            
        } else {
            const childCmp = this.template.querySelector('.childProductCmp');
            if (childCmp) {
                const childResult = childCmp.getSelectedLineItems();
                if (childResult.hasError) {
                    this.showToast('Error', childResult.errorMessage, 'error');
                    return;
                }
                selectedItems = childResult.selectedItems;
            }

            if (!selectedItems || selectedItems.length === 0) {
                this.showToast('Warning', 'Please select at least one product with valid quantity to generate Sales Order.', 'warning');
                return;
            }
            console.log('selectedItems', selectedItems);
            
            // Validation for child component items if available quantity is present
            const excessChildItems = selectedItems.filter(item => {
                const availQty = item.Available_Quantity__c ?? item.availableQuantity;
                return availQty != null && parseFloat(item.quantity || 0) > parseFloat(availQty);
            });

            if (excessChildItems.length > 0) {
                const prodNames = excessChildItems.map(item => item.productName || item.Name || 'Product').join(', ');
                this.showToast('Error', `Quantity cannot be greater than Available Quantity for: ${prodNames}`, 'error');
                return;
            }
        }
        
        
        this.isLoading = true;
        saveSalesOrderRec({
            strsalesOrderRec: JSON.stringify(this.salesorderRec),
            selectedQuotationId: this.selectedQuotationId,
            strSelectedLineItems: JSON.stringify(selectedItems),
            OpportunityId: this.recordId
        }).then((result) => {
            this.salesOrderId = result;
            this.showToast('Success', 'Sales Order created successfully.', 'success');

            saveVFAsFile({
                recordId: this.recordId,
                salesOrderId: this.salesOrderId
            }).catch(error => console.error('saveVFAsFile error', error));

            if (this.fromChallan && this.salesOrderId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.salesOrderId,
                        objectApiName: 'Sales_Order__c',
                        actionName: 'view'
                    }
                });
            } else {
                this.navigateToSource();
            }
        }).catch((error) => {
            console.error('Save Error:', error);
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }).finally(() => {
            this.isLoading = false;
        });
    }

    handleCancel() {
        this.navigateToSource();
    }

    navigateToSource() {
        const recordId = this.fromChallan && this.challanId ? this.challanId : this.recordId;
        const objectApiName = this.fromChallan && this.challanId ? 'Challan__c' : 'Opportunity__c';
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName,
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}