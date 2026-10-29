import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import attachPdfToRecord from '@salesforce/apex/POPdfAttachmentController.attachPdfToRecord';

export default class OpenPdf extends NavigationMixin(LightningElement) {
    hasExecuted = false;
 
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && !this.hasExecuted) {
            const recordId = (currentPageReference?.attributes?.recordId) ? currentPageReference?.attributes?.recordId : currentPageReference?.state?.recordId;
   
            if (recordId) {
                this.hasExecuted = true;

                attachPdfToRecord({ recordId: recordId })
                    .then(() => {
                        this.showToast('Success', 'PO Generated Successfully!', 'success');
                        this.closeModal();

                        this[NavigationMixin.Navigate]({
                            type: 'standard__recordPage',
                            attributes: {
                                recordId: recordId,
                                actionName: 'view'
                            }
                        }, true); // 'true' = replace history
                    })
                    .catch((error) => {
                        console.log('Error attachPdfToRecord',error?.body?.message);
                        
                        this.showToast('Error', error.body?.message || 'Error occurred', 'error');
                        this.closeModal();
                    });
            }
        }
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}