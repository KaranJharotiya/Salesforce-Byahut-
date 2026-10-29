// deliveryScheduleModal.js
import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import getDeliveryData from '@salesforce/apex/SalesRecordPageModalCmpController.getDeliveryData';

export default class SalesRecordPageModalCmp extends LightningElement {

    @api recordId;

    @track childRecords = [];
    deliveryType;
    specialInstructions;
    isModalOpen = false;

    // 1. RecordId se object ka exact API name check karega
    @wire(getRecord, { recordId: '$recordId', fields: ['Sales_Order__c.Id'] })
    wiredRecord({ data, error }) {
        if (data && data.apiName === 'Sales_Order__c') {
            this.isModalOpen = true;
        } else {
            this.isModalOpen = false;
        }
    }

    // 2. Apex method tabhi call hoga jab modal open ho
    @wire(getDeliveryData, { recordId: '$recordId' })
    wiredData({ data, error }) {
        if (data) {
            this.deliveryType = data.deliveryType;
            this.specialInstructions = data.specialInstructions;

            this.childRecords = data.childRecords.map(item => {
                return {
                    ...item,
                    priorityClass:
                        item.Priority__c === 'High'
                            ? 'priority high'
                            : item.Priority__c === 'Medium'
                                ? 'priority medium'
                                : 'priority low',
                    productName: item?.Product__r?.Name
                };
            });

        } else if (error) {
            console.error(error);
        }
    }

    get deliveryTypeLabel() {
        if (this.deliveryType === 'Full') {
            return 'Complete Shipment Dispatch';
        }

        if (this.deliveryType === 'Partial') {
            return 'Split / Partial Shipment Dispatch';
        }

        return 'Standard Dispatch';
    }

    get deliveryClass() {
        return this.deliveryType === 'Full'
            ? 'delivery-badge full'
            : 'delivery-badge partial';
    }

    closeModal() {
        this.isModalOpen = false;
    }
}