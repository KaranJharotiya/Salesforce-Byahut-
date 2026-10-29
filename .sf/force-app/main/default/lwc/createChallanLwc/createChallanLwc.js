import { LightningElement, api, wire, track } from 'lwc';
import getInitialData from '@salesforce/apex/CreateChallanController.getInitialData';
import saveChallan from '@salesforce/apex/CreateChallanController.saveChallan';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import CHALLAN_OBJECT from '@salesforce/schema/Challan__c';
import WAY_OF_TRANSIT_FIELD from '@salesforce/schema/Challan__c.Way_of_Transit__c';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import { CloseActionScreenEvent } from 'lightning/actions';
import QuickActionModalSize from '@salesforce/resourceUrl/QuickActionModalSize';

export default class CreateChallanLwc extends NavigationMixin(LightningElement) {
    @api recordIds = [];
    @api recordId;
    @api challanFromHome;
    @track salesOrders = [];
    @track lineItems = [];
    @track selectedLineItemIds = [];
    @track opportunityId;
    @track opportunityName;
    @track errorMessage;
    @track selectedTransit = '';
    @track address = '';
    @track specialInstructions = '';
    @track transitOptions = [];
    @track isLoading = false;
    @track lineItemError = '';
    @track IsCommunity = false;
    @track isAllLineItemsCreated = false;

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef) {
            const pageRecordId = pageRef?.state?.recordId || pageRef?.attributes?.recordId;
            if (pageRecordId) {
                this.recordId = pageRecordId;
            }
        }
    }

    @wire(getObjectInfo, { objectApiName: CHALLAN_OBJECT })
    challanMetadata;

    @wire(getPicklistValues, {
        recordTypeId: '$challanMetadata.data.defaultRecordTypeId',
        fieldApiName: WAY_OF_TRANSIT_FIELD
    })
    wiredPicklistValues({ data, error }) {
        if (data) {
            this.transitOptions = data.values.map(item => ({ label: item.label, value: item.value }));
        } else if (error) {
            console.log('Error wiredPicklistValues', error);
        }
    }

    async connectedCallback() {
        this.isLoading = true;
        this.IsCommunity = window.location.pathname.startsWith('/s/');

        if (this.IsCommunity) {
            await loadStyle(this, QuickActionModalSize);
        }

        let ids = this.recordIds ? [...this.recordIds] : [];
        if (this.recordId && !ids.includes(this.recordId)) {
            ids.push(this.recordId);
        }
        this.recordIds = ids;
        await this.loadInitialData();
        this.isLoading = false;
    }

    disconnectedCallback() {
        const cssLinks = document.querySelectorAll('link');
        if (cssLinks) {
            cssLinks.forEach((link) => {
                if (link.href && link.href.includes('QuickActionModalSize')) {
                    link.remove();
                }
            });
        }
    }

    async loadInitialData() {
        this.isLoading = true;
        await getInitialData({ salesOrderIds: this.recordIds })
            .then(result => {
                this.isLoading = true;
                if (result.errorMessage) {
                    this.isLoading = false;
                    this.errorMessage = result.errorMessage;
                    if (this.recordId && result.errorMessage.toLowerCase().includes('already have challans created')) {
                        this.isAllLineItemsCreated = true;
                    }
                } else {
                    this.salesOrders = result.salesOrders;
                    this.opportunityId = result.opportunityId;
                    this.opportunityName = result.opportunityName;
                    this.lineItems = result.lineItems;
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.errorMessage = error.body ? error.body.message : error.message;
                console.log('getInitialData Error', error.body ? error.body.message : error.message);
            });
        this.isLoading = false;
    }

    get isValid() {
        return !this.errorMessage && this.salesOrders.length > 0;
    }

    get isErrorState() {
        return !!this.errorMessage;
    }

    get isBackDisabled() {
        return this.challanFromHome || this.isAllLineItemsCreated;
    }

    get isAllSelected() {
        return this.lineItems.length > 0 && this.selectedLineItemIds.length === this.lineItems.length;
    }

    handleSelectAll(event) {
        const isChecked = event.target.checked;
        if (isChecked) {
            this.selectedLineItemIds = this.lineItems.map(item => item.Id);
        } else {
            this.selectedLineItemIds = [];
        }
        this.lineItems = this.lineItems.map(item => ({
            ...item,
            selected: isChecked
        }));
    }

    handleItemSelect(event) {
        const itemId = event.target.dataset.id;
        const isChecked = event.target.checked;

        if (isChecked) {
            this.selectedLineItemIds = [...this.selectedLineItemIds, itemId];
        } else {
            this.selectedLineItemIds = this.selectedLineItemIds.filter(id => id !== itemId);
        }

        this.lineItems = this.lineItems.map(item => {
            if (item.Id === itemId) {
                return { ...item, selected: isChecked };
            }
            return item;
        });
    }

    handleTransitChange(event) {
        this.selectedTransit = event.detail.value;
    }

    handleAddressChange(event) {
        this.address = event.detail.value;
    }

    handleSpecialInstructionsChange(event) {
        this.specialInstructions = event.detail.value;
    }

    handleSave() {
        const combobox = this.template.querySelector('lightning-combobox');
        if (!this.selectedTransit) {
            if (combobox) {
                combobox.reportValidity();
            }
            return;
        }

        if (this.selectedLineItemIds.length === 0) {
            this.lineItemError = 'Please select at least one Line Item to create a Challan.';
            setTimeout(() => {
                this.lineItemError = '';
            }, 2000);
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        saveChallan({
            salesOrderIds: this.recordIds,
            selectedLineItemIds: this.selectedLineItemIds,
            opportunityId: this.opportunityId,
            wayOfTransit: this.selectedTransit,
            address: this.address,
            specialInstructions: this.specialInstructions
        }).then(newChallanId => {
            this.isLoading = false;
            window.location.href = '/' + newChallanId;
        }).catch(error => {
            this.isLoading = false;
            console.log('saveChallan Error', error.body ? error.body.message : error.message);
        });
    }

    handleCancel() {
        if (this.recordId) {
            if (this.IsCommunity) {
                window.location.href = '/s/sales-order/' + this.recordId;
            } else {
                window.location.href = '/lightning/r/Sales_Order__c/' + this.recordId + '/view';
            }
        } else {
            window.location.href = '/lightning/o/Sales_Order__c/list?filterName=All';
        }
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
    }
}