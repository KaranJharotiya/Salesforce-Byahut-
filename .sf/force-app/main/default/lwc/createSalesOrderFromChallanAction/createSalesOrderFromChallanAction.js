import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_TYPE_FIELD from '@salesforce/schema/User.UserType';
import getEligibleProducts from '@salesforce/apex/CreateSalesOrderFromChallanController.getEligibleProducts';

export default class CreateSalesOrderFromChallanAction extends NavigationMixin(LightningElement) {
    @api recordId;
    // Set by the Aura mobile quick action. The desktop action stays headless and calls invoke().
    @api autoStart = false;

    isLoading = true;
    errorMessage;
    started = false;

    userTypePromise = new Promise((resolve) => {
        this.resolveUserType = resolve;
    });

    @wire(getRecord, { recordId: USER_ID, fields: [USER_TYPE_FIELD] })
    wiredUser({ data, error }) {
        if (data) {
            this.resolveUserType(getFieldValue(data, USER_TYPE_FIELD));
        } else if (error) {
            this.resolveUserType('Standard');
        }
    }

    get showPanel() {
        return this.autoStart === true || this.autoStart === 'true';
    }

    renderedCallback() {
        if (!this.showPanel || this.started || !this.recordId) {
            return;
        }
        this.started = true;
        this.run(true);
    }

    @api async invoke() {
        await this.run(false);
    }

    async run(fromMobile) {
        if (!this.recordId) {
            this.fail('Error', 'Challan record not found.', fromMobile);
            return;
        }

        this.isLoading = true;
        this.errorMessage = undefined;

        let eligibility;
        try {
            eligibility = await getEligibleProducts({ challanId: this.recordId });
        } catch (error) {
            this.fail('Error', error?.body?.message || error?.message || 'Access could not be verified.', fromMobile);
            return;
        }

        if (!eligibility?.isAuthorized) {
            this.fail(
                'Access Denied',
                eligibility?.message || 'You do not have access to create a Sales Order. This action is available to Operations users and System Administrators only.',
                fromMobile
            );
            return;
        }
        if (!eligibility.canProceed) {
            this.fail('Error', eligibility.message || 'A Sales Order cannot be created for this Challan.', fromMobile);
            return;
        }

        const userType = await this.userTypePromise;
        const isCommunityUser = userType !== 'Standard';
        const pageReference = isCommunityUser
            ? {
                type: 'standard__webPage',
                attributes: {
                    url: `${this.getCommunityBasePath()}/generate-sales-order?c__recordId=${eligibility.opportunityId}&c__challanId=${this.recordId}`
                }
            }
            : {
                type: 'standard__navItemPage',
                attributes: {
                    apiName: 'Generate_Sales_Order'
                },
                state: {
                    c__recordId: eligibility.opportunityId,
                    c__challanId: this.recordId
                }
            };

        if (fromMobile) {
            // window.open is blocked in the Salesforce mobile app. Navigate inside the app, then close the action.
            this[NavigationMixin.Navigate](pageReference);
            window.setTimeout(() => {
                this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
            }, 400);
            return;
        }

        this[NavigationMixin.GenerateUrl](pageReference)
            .then((url) => {
                window.open(url, '_self');
            })
            .catch((error) => {
                this.showToast('Error', error?.body?.message || error?.message || 'The Sales Order page could not be opened.', 'error');
            });
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
    }

    fail(title, message, fromMobile) {
        this.isLoading = false;
        if (fromMobile) {
            this.errorMessage = message;
        }
        this.showToast(title, message, 'error');
    }

    getCommunityBasePath() {
        const path = window.location.pathname;
        const index = path.indexOf('/s/');
        return index >= 0 ? path.substring(0, index + 2) : '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}