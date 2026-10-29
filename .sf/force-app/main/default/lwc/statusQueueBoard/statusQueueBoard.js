import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { publish, subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import RECORD_STATUS_CHANGE_CHANNEL from '@salesforce/messageChannel/recordStatusChange__c';

import getRecordsByStatus from '@salesforce/apex/StatusQueueBoardController.getRecordsByStatus';

export default class StatusQueueBoard extends LightningElement {
    // ---- Configured per instance, e.g. in Experience Builder ----
    @api columnTitle = 'Queue';       
    @api objectApiName = 'Challan__c';
    @api statusValue;                 
    @api emptyMessage = 'No records in this stage.';

    @track loaded = false;

    @track wiredRecordsResult;

    subscription = null;

    @wire(MessageContext)
    messageContext;

    @wire(getRecordsByStatus, { objectApiName: '$objectApiName', statusValue: '$statusValue' })
    wiredRecords(result) {
        this.wiredRecordsResult = result;
        this.loaded = true;
        if (result.error) {
            // eslint-disable-next-line no-console
            console.error('statusQueueBoard: unable to load records', result.error);
        }
    }

    connectedCallback() {
        this.subscription = subscribe(
            this.messageContext,
            RECORD_STATUS_CHANGE_CHANNEL,
            (message) => this.handleStatusChangeMessage(message)
        );
    }

    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    // Any board on the page that changed a record of the same object type
    // might affect what belongs in THIS column, so just refresh.
    handleStatusChangeMessage(message) {
        if (message.objectApiName === this.objectApiName) {
            refreshApex(this.wiredRecordsResult);
        }
    }

    // Tell every board on the page that a record moved to a new status.
    publishStatusChange(event) {
        const payload = {
            objectApiName: event.detail.objectApiName
        };
        publish(this.messageContext, RECORD_STATUS_CHANGE_CHANNEL, payload);
    }

    get rawRecords() {
        return (this.wiredRecordsResult && this.wiredRecordsResult.data) || [];
    }

    get records() {
        return this.rawRecords.map((r) => ({
            ...r,
            summaryLabel: this.buildSummaryLabel(r)
        }));
    }

    buildSummaryLabel(r) {
        const parts = [r.name];
        if (r.recordDate) {
            parts.push(new Date(r.recordDate).toLocaleString());
        }

        parts.push(r.totalItems);
        return parts.join(' • ');
    }

    get hasRecords() {
        return this.rawRecords.length > 0;
    }

    get countLabel() {
        return String(this.rawRecords.length);
    }
}