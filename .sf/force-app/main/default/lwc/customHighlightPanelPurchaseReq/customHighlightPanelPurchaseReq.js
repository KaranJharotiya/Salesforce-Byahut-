import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, deleteRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

// Fields Import
import NAME_FIELD from '@salesforce/schema/Purchase_Request__c.Name';
import STATUS_FIELD from '@salesforce/schema/Purchase_Request__c.Status__c';

// Current User Profile Check
import USER_ID from '@salesforce/user/Id';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';

const FIELDS = [NAME_FIELD, STATUS_FIELD];

export default class CustomHighlightPanelPurchaseReq extends NavigationMixin(LightningElement) {
    @api recordId;
    @track userProfileName;

    // Modal Control Flags
    @track isAddRatesOpen = false;
    @track isSubmitApprovalOpen = false;
    @track isApproveOpen = false;
    @track isGeneratePOOpen = false;

    // User Profile Fetch
    @wire(getRecord, { recordId: USER_ID, fields: [PROFILE_NAME_FIELD] })
    wiredUser({ data }) {
        if (data) {
            this.userProfileName = getFieldValue(data, PROFILE_NAME_FIELD);
        }
    }

    // Purchase Request Record Fetch
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    purchaseRequest;

    get recordName() {
        return getFieldValue(this.purchaseRequest.data, NAME_FIELD);
    }

    get status() {
        return getFieldValue(this.purchaseRequest.data, STATUS_FIELD);
    }

    // Visibility Getters
    get showAddUpdateRates() {
        return this.status === 'Draft';
    }

    get showSubmitForApproval() {
        return this.status === 'Vendor Rates Added';
    }

    get showApprove() {
        return this.status === 'Pending Approval' && this.userProfileName === 'System Administrator';
    }

    get showGeneratePO() {
        return this.status === 'Approved';
    }

    // Button Actions
    handleDelete() {
        deleteRecord(this.recordId)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Record deleted successfully',
                        variant: 'success'
                    })
                );
                // Redirect to List View
                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: {
                        objectApiName: 'Purchase_Request__c',
                        actionName: 'list'
                    },
                    state: {
                        filterName: 'Recent'
                    }
                });
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error deleting record',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    })
                );
            });
    }

    handleAddUpdateRates() {
        this.isAddRatesOpen = true;
    }

    handleSubmitForApproval() {
        this.isSubmitApprovalOpen = true;
    }

    handleApprove() {
        this.isApproveOpen = true;
    }

    handleGeneratePO() {
        this.isGeneratePOOpen = true;
    }

    // Modal Close Handlers
    closeModal() {
        this.isAddRatesOpen = false;
        this.isSubmitApprovalOpen = false;
        this.isApproveOpen = false;
        this.isGeneratePOOpen = false;
    }

    async handleModalCloseEvent() {
        this.closeModal();
        // UI refresh to sync status changes
        await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
    }
}