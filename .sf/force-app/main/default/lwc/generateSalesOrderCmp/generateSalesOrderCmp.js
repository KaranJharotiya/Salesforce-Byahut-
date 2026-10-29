import { LightningElement, api, wire, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import { loadStyle } from 'lightning/platformResourceLoader';
// import QuickActionModalSize from '@salesforce/resourceUrl/QuickActionModalSize';
import getQuotationsWithItems from '@salesforce/apex/GenerateSalesOrderQuotationController.getQuotationsWithItems';
import saveSalesOrderRec from '@salesforce/apex/GenerateSalesOrderQuotationController.saveSalesOrderRec';
import saveVFAsFile from '@salesforce/apex/SaveSalesOrderAttachment.saveVFAsFile';
import { refreshApex } from '@salesforce/apex';

export default class GenerateSalesOrderCmp extends LightningElement {
    @api recordId;

    @track salesOrderId;
    @track quotations = [];
    @track salesorderRec = {};

    selectedQuotationId = null;
    wiredQuotationsResult;
    isLoading = false;
    disableSave = false;

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
                    promiseDate: null
                }));
                return qWrap;
            });
        } else if (error) {
            console.error('Error fetching quotations', error);
            this.showToast('Error', 'Error fetching quotations.', 'error');
            this.closeModal();
        }
    }

    connectedCallback() {
        // loadStyle(this, QuickActionModalSize);
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        this.salesorderRec[field] = event.detail.value;
    }

    handleCheckboxChange(event) {
        const quoteId = event.target.dataset.quoteid;
        const itemId = event.target.dataset.itemid;
        const isChecked = event.target.checked;

        this.quotations = this.quotations.map(qWrap => {
            if (qWrap.quotation.Id === quoteId) {
                qWrap.lineItems = qWrap.lineItems.map(li => {
                    if (li.item.Id === itemId) {
                        return { ...li, isSelected: isChecked, isFieldDisabled: !isChecked };
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
                qWrap.lineItems = qWrap.lineItems.map(li => ({ ...li, isDisabled: false, isFieldDisabled: true }));
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
                        if (field === 'promiseDate') {
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
        let selectedItems = [];

        if (this.hasQuotations) {
            let hasAnySelected = false;
            let hasInvalidQty = false;

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
                                selectedItems.push({
                                    productId: li.item.Product__c,
                                    quantity: li.quantity,
                                    discount: li.discount,
                                    gst: li.gst,
                                    amount: li.amount,
                                    promiseDate: li.promiseDate
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

            refreshApex(this.wiredQuotationsResult);
            this.closeModal();

            saveVFAsFile({
                recordId: this.recordId,
                salesOrderId: this.salesOrderId
            }).catch(error => console.error('saveVFAsFile error', error));
        }).catch((error) => {
            console.error('Save Error:', error);
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }).finally(() => {
            this.isLoading = false;
        });
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
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
}