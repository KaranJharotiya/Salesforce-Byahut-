import { LightningElement, api, track } from 'lwc';
import getApprovedVendorsForPO from '@salesforce/apex/PurchaseRequestGeneratePOController.getApprovedVendorsForPO';
import createPurchaseOrders from '@salesforce/apex/PurchaseRequestGeneratePOController.createPurchaseOrders';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { RefreshEvent } from 'lightning/refresh';

export default class PurchaseRequestGeneratePOModal extends LightningElement {
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
    @track vendorGroups = [];
    @track activeSections = [];

    connectedCallback() {
        if (this._recordId) {
            this.loadData();
        }
    }

    get hasVendorGroups() {
        return this.vendorGroups && this.vendorGroups.length > 0;
    }

    get isGenerateDisabled() {
        return !this.hasVendorGroups;
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
            const result = await getApprovedVendorsForPO({ purchaseRequestId: this._recordId });
            if (result) {
                // Initialize delivery fields if undefined
                this.vendorGroups = result.map(vg => ({
                    ...vg,
                    expectedDeliveryDate: vg.expectedDeliveryDate || null,
                    trackingNumber: vg.trackingNumber || '',
                    trackingUrl: vg.trackingUrl || ''
                }));
                this.activeSections = result.map(vg => vg.vendorId);
            }
        } catch (error) {
            let errorMsg = error.body ? error.body.message : error.message;
            this.showToast('Error', errorMsg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleDeliveryFieldChange(event) {
        const vendorId = event.target.dataset.vendorId;
        const field = event.target.dataset.field;
        const value = event.target.value;

        this.vendorGroups = this.vendorGroups.map(vg => {
            if (vg.vendorId === vendorId) {
                return { ...vg, [field]: value };
            }
            return vg;
        });
    }

    validateInputs() {
        let allValid = true;
        const inputFields = this.template.querySelectorAll('lightning-input');
        inputFields.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                allValid = false;
            }
        });
        return allValid;
    }

    async handleGeneratePO() {
        if (!this.validateInputs()) {
            this.showToast('Error', 'Please fill all required delivery details before generating PO.', 'error');
            return;
        }
        // Clean & format tracking URLs before sending to Apex
        const formattedVendorGroups = this.vendorGroups.map(vg => {
            let rawUrl = (vg.trackingUrl || '').trim();
            if (rawUrl && !rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
                rawUrl = 'https://' + rawUrl;
            }
            return {
                ...vg,
                trackingUrl: rawUrl
            };
        });

        this.isLoading = true;
        try {
            await createPurchaseOrders({
                purchaseRequestId: this._recordId,
                vendorGroupsData: this.vendorGroups
            });

            this.showToast('Success', 'Purchase Orders, Line Items, and Delivery Details generated successfully.', 'success');
            await notifyRecordUpdateAvailable([{ recordId: this._recordId }]);
            this.dispatchEvent(new RefreshEvent());
            this.handleCloseModal();
        } catch (error) {
            let errorMsg = error.body ? error.body.message : error.message;
            this.showToast('Error', errorMsg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}