import { LightningElement, api } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { RefreshEvent } from 'lightning/refresh';

export default class RefreshPage extends LightningElement {

    channelName = '/event/Refresh_Event__e';
    subscription = null;

    @api recordId;

    connectedCallback() {
        this.registerErrorListener();
        this.handleSubscribe();
    }

    handleSubscribe() {
        subscribe(this.channelName, -1, (message) => {
            console.log('Event received: ', message);

            this.dispatchEvent(new RefreshEvent());

        }).then(response => {
            this.subscription = response;
        });
    }

    handleUnsubscribe() {
        unsubscribe(this.subscription, () => {
            console.log('Unsubscribed');
        });
    }

    registerErrorListener() {
        onError(error => {
            console.error('EMP API error: ', error);
        });
    }
}