import { LightningElement, api, track } from 'lwc';
import getPRLineItemsForApproval from '@salesforce/apex/PurchaseRequestApprovalReviewController.getPRLineItemsForApproval';
import saveAndApprovePR from '@salesforce/apex/PurchaseRequestApprovalReviewController.saveAndApprovePR';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { updateRecord } from 'lightning/uiRecordApi';

export default class PurchaseRequestApproveScreen extends LightningElement {
    _recordId;
    @api isCommunity;
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadData();
        }
    }

    @track isLoading = false;
    @track accordionData = [];
    @track activeSections = [];

    connectedCallback() {
        if (this._recordId) {
            this.loadData();
        }
    }

    get hasProductSections() {
        return this.accordionData && this.accordionData.length > 0;
    }

    handleCloseModal() {
        if (this.isCommunity) {
            this.dispatchEvent(new CustomEvent('closemodal'));
        } else {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
    }

    async loadData() {
        if (!this._recordId) return;
        this.isLoading = true;
        try {
            const result = await getPRLineItemsForApproval({ purchaseRequestId: this._recordId });
            if (result) {
                this.accordionData = result.map(prod => ({
                    ...prod,
                    sectionLabel: `${prod.productName} (Req Qty: ${prod.requestedQty || 0}) - [${prod.prLineItemNumber}]`,
                    hasVendors: prod.vendorRates && prod.vendorRates.length > 0
                }));
                this.activeSections = this.accordionData.map(p => p.prLineItemId);
            }
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleInputChange(event) {
        const lineId = event.target.dataset.lineId;
        const vendorId = event.target.dataset.vendorId;
        const fieldName = event.target.dataset.field;
        const enteredVal = event.target.value;

        this.accordionData = this.accordionData.map(prod => {
            if (prod.prLineItemId === lineId) {
                const updatedVendors = prod.vendorRates.map(ven => {
                    if (ven.vendorMasterId === vendorId) {
                        let finalVal = enteredVal;
                        if (fieldName !== 'commercialTerms') {
                            finalVal = enteredVal === '' ? null : Number(enteredVal);
                        }
                        return {
                            ...ven,
                            [fieldName]: finalVal
                        };
                    }
                    return ven;
                });
                return { ...prod, vendorRates: updatedVendors };
            }
            return prod;
        });
    }

    handleVendorSelect(event) {
        const lineId = event.target.dataset.lineId;
        const vendorId = event.target.dataset.vendorId;
        const isChecked = event.target.checked;

        this.accordionData = this.accordionData.map(prod => {
            if (prod.prLineItemId === lineId) {
                const updatedRates = prod.vendorRates.map(ven => {
                    if (ven.vendorMasterId === vendorId) {
                        return {
                            ...ven,
                            isSelected: isChecked
                        };
                    }
                    return ven;
                });
                return {
                    ...prod,
                    vendorRates: updatedRates
                };
            }
            return prod;
        });
    }

    async handleSaveAndApprove() {
        // Validation: Ensure at least 1 vendor is selected per product (having vendors)
        for (let prod of this.accordionData) {
            const hasSelectedVendor = prod.vendorRates && prod.vendorRates.some(ven => ven.isSelected);
            if (prod.hasVendors && !hasSelectedVendor) {
                this.showToast('Validation Error', `Please select at least one vendor for ${prod.productName}.`, 'warning');
                return;
            }
        }

        const recordsToUpdate = [];
        this.accordionData.forEach(prod => {
            if (prod.vendorRates) {
                prod.vendorRates.forEach(ven => {
                    recordsToUpdate.push({
                        Id: ven.ivrId || null,
                        Purchase_Request_Line_Item__c: prod.prLineItemId,
                        Product__c: prod.productId,
                        Vendor__c: ven.vendorMasterId,
                        Rate__c: ven.rate != null ? Number(ven.rate) : null,
                        Quantity__c: ven.quantity != null ? Number(ven.quantity) : Number(prod.requestedQty),
                        Discount__c: ven.discount != null ? Number(ven.discount) : null,
                        GST__c: ven.gst != null ? Number(ven.gst) : null,
                        Delivery_Transportation_Charges__c: ven.deliveryCharges != null ? Number(ven.deliveryCharges) : null,
                        Other_Applicable_Commercial_Terms__c: ven.commercialTerms || null,
                        Status__c: ven.isSelected ? 'Approved' : 'Rejected'
                    });
                });
            }
        });

        this.isLoading = true;
        try {
            await saveAndApprovePR({
                purchaseRequestId: this._recordId,
                ivrListToUpdate: recordsToUpdate
            });

            this.showToast('Success', 'Purchase Request approved and notification sent to Purchase Team.', 'success');
            await updateRecord({ fields: { Id: this._recordId } });
            this.handleCloseModal();
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}