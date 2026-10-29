import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from 'lightning/actions';
import sendEmail from '@salesforce/apex/QuotationPdfController.sendEmail';
import hasQuotationLineItem from '@salesforce/apex/QuotationPdfController.hasQuotationLineItem';
import getQuotationsByLead from '@salesforce/apex/QuotationPdfController.getQuotationsByLead';
import generateQuotationPdfFile from '@salesforce/apex/QuotationPdfController.generateQuotationPdfFile';

export default class GenerateQuotation extends NavigationMixin(LightningElement) {

    @api recordId;
    isLoading = true;
    hasQuotationLineItemBoolean = false;

    selectedQuotation = '';
    quotationOptions = [];

    value = [];

    get options() {
        return [
            { label: 'CAS Number', value: 'CAS_Number__c' },
            { label: 'Code', value: 'Code__c' },
            { label: 'Brand', value: 'Brand__c' },
            { label: 'Grade', value: 'Grade__c' }
        ];
    }

    get isQuotationSelected() {
        return Boolean(this.selectedQuotation);
    }

    get isPreviewDisabled() {
        return !this.selectedQuotation;
    }

    handleChange(e) {
        this.value = e.detail.value;
    }

    async handleQuotationChange(e) {
        this.selectedQuotation = e.detail.value;
        try {
            this.hasQuotationLineItemBoolean = await hasQuotationLineItem({
                recordId: this.recordId,
                quotationId: this.selectedQuotation
            });
        } catch (error) {
            console.error('Error checking quotation line items >> ', error);
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            // Aura wrapper (mobile quick action) se aaya recordId pageRef me na mile to wahi rakhein
            this.recordId = currentPageReference.state?.recordId || currentPageReference.attributes?.recordId || this.recordId;
            this.onLoadActions();
        }
    }

    async onLoadActions() {
        try {
            this.isLoading = true;

            // Fetch quotations related to Lead
            const quotations = await getQuotationsByLead({ recordId: this.recordId });
            console.log('quotations', quotations);

            if (quotations && quotations.length > 0) {
                this.quotationOptions = quotations.map(item => ({
                    label: item.Name,
                    value: item.Id
                }));
            } else {
                this.quotationOptions = [];
            }

            // Check if items exist initially
            const res = await hasQuotationLineItem({ recordId: this.recordId, quotationId: null });
            this.hasQuotationLineItemBoolean = res;

        } catch (error) {
            console.error('Error during init >> ', error);
        } finally {
            this.isLoading = false;
        }
    }

    // PDF ko File me save karke native file preview me kholte hain (desktop aur mobile dono me)
    async handlePreviewQuotation() {
        if (!this.selectedQuotation) {
            this.showErrorNotification('Please select a Quotation first.');
            return;
        }

        try {
            this.isLoading = true;
            const contentDocumentId = await generateQuotationPdfFile({
                recordId: this.recordId,
                quotationId: this.selectedQuotation,
                columns: this.value.join(',')
            });

            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: { pageName: 'filePreview' },
                state: { selectedRecordId: contentDocumentId }
            });
            this.handleClose();
        } catch (error) {
            this.showErrorNotification(error?.body?.message || error?.message);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSendEmail() {
        try {
            this.isLoading = true;
            const result = await sendEmail({ recordId: this.recordId });
            if (result) {
                this.showSuccessNotification(result);
            }
        } catch (error) {
            this.showErrorNotification(error?.body?.message);
        } finally {
            this.isLoading = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
        // Aura quick action wrapper (mobile) ke liye
        this.dispatchEvent(new CustomEvent('close'));
    }

    showSuccessNotification(messageText) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: messageText,
            variant: 'success'
        }));
    }

    showErrorNotification(messageText) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: messageText,
            variant: 'error'
        }));
    }

    get hasQuotations() {
        return this.quotationOptions && this.quotationOptions.length > 0;
    }
}