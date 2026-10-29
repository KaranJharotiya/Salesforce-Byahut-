import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_TYPE_FIELD from '@salesforce/schema/User.UserType';

export default class GenerateQuote extends NavigationMixin(LightningElement) {
    @api recordId;

    // Resolves with the running user's UserType once the wire below returns,
    // since invoke() can fire before the wire has data.
    userTypePromise = new Promise((resolve) => {
        this.resolveUserType = resolve;
    });

    @wire(getRecord, { recordId: USER_ID, fields: [USER_TYPE_FIELD] })
    wiredUser({ data, error }) {
        if (data) {
            this.resolveUserType(getFieldValue(data, USER_TYPE_FIELD));
        } else if (error) {
            console.error('Error loading user type:', error);
            this.resolveUserType('Standard');
        }
    }

    @api async invoke() {
        const userType = await this.userTypePromise;
        // Internal (enterprise) users have UserType 'Standard'; community users
        // are PowerPartner, CspLitePortal, CustomerSuccess, PowerCustomerSuccess, etc.
        const isCommunityUser = userType !== 'Standard';

        const pageReference = isCommunityUser
            ? {
                type: 'standard__webPage',
                attributes: {
                    url: `${this.getCommunityBasePath()}/generate-quote?c__recordId=${this.recordId}`
                }
            }
            : {
                type: 'standard__navItemPage',
                attributes: {
                    apiName: 'Generate_Quote'
                },
                state: {
                    c__recordId: this.recordId,
                }
            };

        this[NavigationMixin.GenerateUrl](pageReference).then((url) => {
            window.open(url, '_self');
        }).catch((error) => {
            console.error('Error generating URL:', error);
        });
    }

    // Site prefix from the current URL, e.g. '/partners/s' out of '/partners/s/lead/00Q...'
    getCommunityBasePath() {
        const path = window.location.pathname;
        const index = path.indexOf('/s/');
        return index >= 0 ? path.substring(0, index + 2) : '';
    }

}