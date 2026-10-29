import { LightningElement, api, track } from 'lwc';
import getPRLineItemsWithVendors from '@salesforce/apex/PurchaseRequestRateController.getPRLineItemsWithVendors';
import saveItemVendorRates from '@salesforce/apex/PurchaseRequestRateController.saveItemVendorRates';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { updateRecord } from 'lightning/uiRecordApi';

export default class PurchaseRequestRateManager extends LightningElement {
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
        console.log('isCommunity', this.isCommunity);

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
            const result = await getPRLineItemsWithVendors({ purchaseRequestId: this._recordId });
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

    async handleSaveRates() {
        const recordsToSave = [];

        this.accordionData.forEach(prod => {
            if (prod.vendorRates) {
                prod.vendorRates.forEach(ven => {
                    if (
                        ven.rate != null ||
                        ven.discount != null ||
                        ven.gst != null ||
                        ven.deliveryCharges != null ||
                        (ven.commercialTerms && ven.commercialTerms.trim() !== '')
                    ) {
                        recordsToSave.push({
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
                            Status__c: ven.status || 'Pending'
                        });
                    }
                });
            }
        });

        if (recordsToSave.length === 0) {
            this.showToast('Warning', 'Please enter Rate, Discount, GST, Delivery Charges, or Commercial Terms for at least one vendor.', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            const result = await saveItemVendorRates({
                purchaseRequestId: this._recordId,
                ivrRecordList: recordsToSave
            });

            if (result.status === 'success') {
                this.showToast('Success', result.message, 'success');
                await updateRecord({ fields: { Id: this._recordId } });
                this.handleCloseModal();
            } else {
                this.showToast('Error', result.message, 'error');
            }
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