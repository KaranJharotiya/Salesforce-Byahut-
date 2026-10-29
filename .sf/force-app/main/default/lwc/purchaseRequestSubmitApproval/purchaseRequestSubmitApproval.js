import { LightningElement, api } from 'lwc';
import submitPRForApproval from '@salesforce/apex/PurchaseRequestApprovalController.submitPRForApproval';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';


export default class PurchaseRequestSubmitApproval extends LightningElement {
    @api recordId;
    showPrompt = true;

    handleCancel() {
        this.showPrompt = false;
        this.dispatchEvent(new CloseActionScreenEvent());
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
    }

    async handleConfirm() {
        this.showPrompt = false;
        if (!this.recordId) {
            this.dispatchEvent(new CloseActionScreenEvent());
            return;
        }

        try {
            await submitPRForApproval({ purchaseRequestId: this.recordId });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Purchase Request submitted for approval and notification sent to Admin.',
                    variant: 'success'
                })
            );

            await updateRecord({ fields: { Id: this.recordId } });

        } catch (error) {
            let errorMessage = 'An error occurred';
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            } else if (error.message) {
                errorMessage = error.message;
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: errorMessage,
                    variant: 'error'
                })
            );
        } finally {
            this.dispatchEvent(new CloseActionScreenEvent());
            const closeEvent = new CustomEvent('close');
            this.dispatchEvent(closeEvent);
        }
    }
}