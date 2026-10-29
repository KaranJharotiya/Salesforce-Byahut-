import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCategorizedAttachments from '@salesforce/apex/DeliveryAttachmentsController.getCategorizedAttachments';
import saveAllAttachments from '@salesforce/apex/DeliveryAttachmentsController.saveAllAttachments';
import deleteAttachment from '@salesforce/apex/DeliveryAttachmentsController.deleteAttachment';

export default class DeliveryAttachmentsModal extends NavigationMixin(LightningElement) {
    @api recordId;
    @track isModalOpen = false;
    @track isLoading = false;
    @track isLoadingModal = false;

    // Server-stored files
    @track docketCopyFiles = [];
    @track transporterPodFiles = [];
    @track customerPodFiles = [];

    // Client-side pending files (Saved ONLY on clicking "Save & Done")
    @track pendingTransporterFiles = [];
    @track pendingCustomerFiles = [];
    @track pendingDocketFiles = [];

    connectedCallback() {
        this.fetchFiles();
    }

    get hasTransporterPodFiles() {
        return this.transporterPodFiles && this.transporterPodFiles.length > 0;
    }

    get hasCustomerPodFiles() {
        return this.customerPodFiles && this.customerPodFiles.length > 0;
    }

    get hasDocketCopyFiles() {
        return this.docketCopyFiles && this.docketCopyFiles.length > 0;
    }

    openModal() {
        this.resetPendingFiles();
        this.isModalOpen = true;
    }

    closeModal() {
        // Discard all pending uploads without touching server
        this.resetPendingFiles();
        this.isModalOpen = false;
    }

    resetPendingFiles() {
        this.pendingTransporterFiles = [];
        this.pendingCustomerFiles = [];
        this.pendingDocketFiles = [];
    }

    fetchFiles() {
        this.isLoading = true;
        getCategorizedAttachments({ recordId: this.recordId })
            .then(data => {
                this.docketCopyFiles = data['Docket Copy'] || [];
                this.transporterPodFiles = data['Transporter POD'] || [];
                this.customerPodFiles = data['Customer POD'] || [];
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Error loading files', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Read selected files client-side into base64
    handleFileSelect(event) {
        const files = event.target.files;
        const category = event.target.dataset.category;

        if (!files || files.length === 0) return;

        Array.from(files).forEach(file => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                const fileObj = {
                    fileName: file.name,
                    base64Data: base64,
                    category: category
                };

                if (category === 'Transporter POD') {
                    this.pendingTransporterFiles = [...this.pendingTransporterFiles, fileObj];
                } else if (category === 'Customer POD') {
                    this.pendingCustomerFiles = [...this.pendingCustomerFiles, fileObj];
                } else if (category === 'Docket Copy') {
                    this.pendingDocketFiles = [...this.pendingDocketFiles, fileObj];
                }
            };
            reader.readAsDataURL(file);
        });

        // Reset input element value so user can re-pick same filename if needed
        event.target.value = '';
    }

    // Remove pending file before save
    handleRemovePendingFile(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const category = event.currentTarget.dataset.category;

        if (category === 'Transporter POD') {
            this.pendingTransporterFiles.splice(index, 1);
            this.pendingTransporterFiles = [...this.pendingTransporterFiles];
        } else if (category === 'Customer POD') {
            this.pendingCustomerFiles.splice(index, 1);
            this.pendingCustomerFiles = [...this.pendingCustomerFiles];
        } else if (category === 'Docket Copy') {
            this.pendingDocketFiles.splice(index, 1);
            this.pendingDocketFiles = [...this.pendingDocketFiles];
        }
    }

    // Standard Salesforce preview
    handlePreview(event) {
        const docId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: docId
            }
        });
    }

    // Delete existing file from server
    handleExistingDelete(event) {
        const docId = event.currentTarget.dataset.id;
        this.isLoadingModal = true;
        deleteAttachment({ documentId: docId })
            .then(() => {
                this.showToast('Success', 'File deleted successfully', 'success');
                this.fetchFiles();
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Error deleting file', 'error');
            })
            .finally(() => {
                this.isLoadingModal = false;
            });
    }

    // Mandatory check & bulk save to Salesforce
    async handleSaveAndValidate() {
        const totalTransporter = this.transporterPodFiles.length + this.pendingTransporterFiles.length;
        const totalCustomer = this.customerPodFiles.length + this.pendingCustomerFiles.length;

        if (totalTransporter === 0 || totalCustomer === 0) {
            let missing = [];
            if (totalTransporter === 0) missing.push('Transporter POD');
            if (totalCustomer === 0) missing.push('Customer POD');

            this.showToast(
                'Validation Error',
                `Mandatory files missing: ${missing.join(', ')}. Please upload at least one file for each mandatory section.`,
                'error'
            );
            return;
        }

        const allPendingFiles = [
            ...this.pendingTransporterFiles,
            ...this.pendingCustomerFiles,
            ...this.pendingDocketFiles
        ];

        if (allPendingFiles.length === 0) {
            this.isModalOpen = false;
            return;
        }

        this.isLoadingModal = true;
        try {
            await saveAllAttachments({
                recordId: this.recordId,
                filesJson: JSON.stringify(allPendingFiles)
            });

            this.showToast('Success', 'Attachments uploaded and saved successfully!', 'success');
            this.resetPendingFiles();
            this.isModalOpen = false;
            this.fetchFiles();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error saving attachments', 'error');
        } finally {
            this.isLoadingModal = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}