import { LightningElement, wire,api } from 'lwc';
import getMyAccess from '@salesforce/apex/BusinessProgressController.getMyAccess';

export default class BusinessProgressHub extends LightningElement {
    @api IsCommunity = false;
    profileName;
    modules = [];   // [{ key, label, closedStatusLabel }, ...] - only what this profile can see
    loaded = false;
    
    @wire(getMyAccess)
    wiredAccess({ data, error }) {
        this.loaded = true;
        if (data) {
            this.profileName = data.profileName;
            this.modules = data.modules || [];
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('businessProgressHub: unable to load access info', error);
        }
    }

    connectedCallback(){
        this.IsCommunity = window.location.pathname.startsWith('/s/');
    }
    get isLoading() {
        return !this.loaded;
    }

    get hasNoAccess() {
        return this.loaded && this.modules.length === 0;
    }
}