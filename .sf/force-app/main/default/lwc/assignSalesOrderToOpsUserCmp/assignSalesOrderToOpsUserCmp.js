import { LightningElement, api } from 'lwc';
import assignSalesOrder from '@salesforce/apex/AssignSalesOrderToOpsUserController.assignSalesOrder';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const OPS_PROFILES = ['Operations Team', 'Operations Executive'];

export default class AssignSalesOrderToOpsUserCmp extends LightningElement {
    @api recordId;
    selectedUserId;
    isSaving = false;

    displayInfo = {
        primaryField: 'Name'
    };

    // Record Picker me sirf active Operations Team users dikhenge
    activeFilter = {
        criteria: [
            {
                fieldPath: 'IsActive',
                operator: 'eq',
                value: true
            },
            {
                fieldPath: 'Profile.Name',
                operator: 'in',
                value: OPS_PROFILES
            }
        ],
        logic: '1 AND 2'
    };

    handleUserChange(event) {
        this.selectedUserId = event.detail.recordId;
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
    }

    async handleFooterSave() {
        const allValid = [...this.template.querySelectorAll('.validate')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (!allValid) {
            return;
        }

        this.isSaving = true;
        try {
            await assignSalesOrder({
                selectedUserId: this.selectedUserId,
                recordId: this.recordId
            });

            this.dispatchEvent(new CloseActionScreenEvent());
            this.showToast('Success', 'Sales Order Assigned Successfully', 'success');
            setTimeout(() => {
                window.location.reload();
            }, 800);
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            console.log('Error', error);
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}