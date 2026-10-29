import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, deleteRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

// Fields Import (Custom Lead Object Lead__c ke hisab se)
import NAME_FIELD from '@salesforce/schema/Lead__c.Name';
import STATUS_FIELD from '@salesforce/schema/Lead__c.Status__c';

const FIELDS = [NAME_FIELD, STATUS_FIELD];

export default class CustomHighlightPanelLead extends NavigationMixin(LightningElement) {
    @api recordId;

    // Modal Visibility Flags
    @track isVoucherOpen = false;
    @track isConvertOpen = false;
    @track isAssignOpen = false;

    // Fetch Lead Record Details
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    leadRecord;

    get recordName() {
        return getFieldValue(this.leadRecord.data, NAME_FIELD);
    }

    get status() {
        return getFieldValue(this.leadRecord.data, STATUS_FIELD);
    }

    // Convert or Not Converted hone par buttons hide honge
    get showCustomActions() {
        const currentStatus = this.status;
        return currentStatus !== 'Converted' && currentStatus !== 'Not Converted';
    }

    // --- Action Handlers ---

    // 1. Generate Quote (Headless Action trigger)
    async handleGenerateQuote() {
        const quoteAction = this.template.querySelector('.generate-quote-action');
        if (quoteAction && typeof quoteAction.invoke === 'function') {
            await quoteAction.invoke();
        }
    }

    // 2. Generate Voucher Modal Open
    handleGenerateVoucher() {
        this.isVoucherOpen = true;
    }

    // 3. Convert Lead Modal Open
    handleConvertLead() {
        this.isConvertOpen = true;
    }

    // 4. Assign Lead Modal Open
    handleAssignLead() {
        this.isAssignOpen = true;
    }

    // 5. Standard Edit Modal
    handleEdit() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'edit'
            }
        });
    }

    // 6. Standard Delete Record
    handleDelete() {
        deleteRecord(this.recordId)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Lead record deleted successfully',
                        variant: 'success'
                    })
                );
                // Redirect back to Lead List View
                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: {
                        objectApiName: 'Lead__c',
                        actionName: 'list'
                    },
                    state: {
                        filterName: 'Recent'
                    }
                });
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error deleting record',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    })
                );
            });
    }

    // Modal Handlers
    closeModal() {
        this.isVoucherOpen = false;
        this.isConvertOpen = false;
        this.isAssignOpen = false;
    }

    async handleModalCloseEvent() {
        this.closeModal();
        // UI refresh so any status change updates immediately
        await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
    }
}