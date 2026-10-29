import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from "lightning/actions";
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LeadConvertedLogo from "@salesforce/resourceUrl/LeadConvertedLogo";
import leadConversion from './leadConversion.html';
import convertedPage from './convertedPage.html';
import convertLead from '@salesforce/apex/LeadConversionController.convertLead';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import LEAD_ID from '@salesforce/schema/Lead__c.Id';
import LEAD_STATUS from '@salesforce/schema/Lead__c.Status__c';
import LEAD_GST_NUMBER from '@salesforce/schema/Lead__c.GST_Number__c';
import LEAD_COMPANY_TYPE from '@salesforce/schema/Lead__c.Company_Type__c';

export default class LeadConversion extends NavigationMixin(LightningElement) {

    LeadLogo = LeadConvertedLogo;
    page = 'main';
    @api recordId;
    isLoading = false;
    responsePayload;
    isLeadConverted = false;

    gstNumber = '';
    existingGstNumber = '';
    companyType = '';

    render() {
        switch (this.page) {
            case 'converted':
                return convertedPage;

            case 'main':
                return leadConversion;

            default:
                return leadConversion;
        }
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [LEAD_STATUS, LEAD_GST_NUMBER, LEAD_COMPANY_TYPE]
    })
    wiredRecord({ data, error }) {

        if (data) {
            console.log('data data >> ', data?.fields?.Status__c);
            const gstNumber = data?.fields?.GST_Number__c?.value;
            this.existingGstNumber = gstNumber || '';
            this.companyType = data?.fields?.Company_Type__c?.value || '';
            console.log('existingGstNumber', this.existingGstNumber);

            if (data?.fields?.Status__c?.value == 'Converted') {
                this.isLeadConverted = true;
            }
        }
        else if (error) {
            console.error('Error:', error);
        }
    }

    get isGstMissing() {
        return this.companyType === 'Dealer' && !this.existingGstNumber;
    }

    handleGstChange(event) {
        this.gstNumber = event.target.value;
    }

    handleConvertCancel() {
        this.closeAction();
    }

    async handleConvert() {
        try {
            this.isLoading = true;

            if (!this.recordId) {
                return;
            }

            if (this.companyType === 'Dealer' && !this.existingGstNumber) {

                if (!this.gstNumber || !this.gstNumber.trim()) {

                    this.showErrorNotification(
                        'Please enter GST Number before converting the Lead.'
                    );

                    this.isLoading = false;
                    return;
                }
                const fields = {};

                fields[LEAD_ID.fieldApiName] = this.recordId;
                fields[LEAD_GST_NUMBER.fieldApiName] = this.gstNumber.trim();

                const recordInput = { fields };

                await updateRecord(recordInput);

                this.existingGstNumber = this.gstNumber.trim();
            }

            if (this.recordId) {

                const response = await convertLead({ leadId: this.recordId });
                this.responsePayload = response;

                const fields = {};
                fields[LEAD_ID.fieldApiName] = this.recordId;
                fields[LEAD_STATUS.fieldApiName] = 'Converted';

                const recordInput = { fields };

                await updateRecord(recordInput);

                console.log('response => ', response);
                await this.stringShort();
                this.showSuccessNotification('Lead converted successfully!');

                this.page = 'converted';
            }

        } catch (error) {
            console.log('error >> ', JSON.stringify(error));
            this.showErrorNotification(error?.body?.message);
        } finally {
            this.isLoading = false;
        }

    }

    handleConverted() {
        this.page = 'main';
    }

    // Done button click handler
    handleClose() {
        this.closeAction();
    }

    // Closes the action for both LWC quick action (desktop) and Aura wrapper (mobile)
    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new CustomEvent('close'));
    }

    disconnectedCallback() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleNavigate(event) {
        const objectName = event.target.dataset.id;
        let id = '';

        switch (objectName) {
            case 'account':
                id = this.responsePayload.acc.Id;
                break;

            case 'contact':
                id = this.responsePayload.con.Id;
                break;

            case 'opportunity':
                id = this.responsePayload.opp.Id;
                break;

            default:

        }

        console.log('id id => ', id);
        if (id) {
            this.NavigateToDetailPage(id);
        }

    }

    showSuccessNotification(messageText) {
        const evt = new ShowToastEvent({
            title: 'Success',
            message: messageText,
            variant: 'success',
        });
        this.dispatchEvent(evt);
    }
    showErrorNotification(messageText) {
        const evt = new ShowToastEvent({
            title: 'Error',
            message: messageText,
            variant: 'error',
        });
        this.dispatchEvent(evt);
    }

    NavigateToDetailPage(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    async stringShort() {

        this.responsePayload.acc.Name = this.responsePayload.acc.Name && this.responsePayload.acc.Name.length > 30 ? this.responsePayload.acc.Name.substring(0, 30) + '...' : this.responsePayload.acc.Name;
        this.responsePayload.acc.Type = this.responsePayload.acc.Type && this.responsePayload.acc.Type.length > 13 ? this.responsePayload.acc.Type.substring(0, 13) + '...' : this.responsePayload.acc.Type;
        this.responsePayload.acc.Phone = this.responsePayload.acc.Phone && this.responsePayload.acc.Phone.length > 13 ? this.responsePayload.acc.Phone.substring(0, 13) + '...' : this.responsePayload.acc.Phone;
        this.responsePayload.acc.website = this.responsePayload.acc.website && this.responsePayload.acc.website.length > 13 ? this.responsePayload.acc.website.substring(0, 13) + '...' : this.responsePayload.acc.website;
        this.responsePayload.acc.Owner.Name = this.responsePayload.acc.Owner.Name && this.responsePayload.acc.Owner.Name.length > 13 ? this.responsePayload.acc.Owner.Name.substring(0, 13) + '...' : this.responsePayload.acc.Owner.Name;
        this.responsePayload.acc.Site = this.responsePayload.acc.Site && this.responsePayload.acc.Site.length > 13 ? this.responsePayload.acc.Site.substring(0, 13) + '...' : this.responsePayload.acc.Site;

        this.responsePayload.con.contactName = this.responsePayload.con.LastName;
        this.responsePayload.con.contactName = this.responsePayload.con.contactName && this.responsePayload.con.contactName.length > 30 ? this.responsePayload.con.contactName.substring(0, 30) + '..' : this.responsePayload.con.contactName;
        this.responsePayload.con.Title = this.responsePayload.con.Title && this.responsePayload.con.Title.length > 13 ? this.responsePayload.con.Title.substring(0, 13) + '..' : this.responsePayload.con.Title;
        this.responsePayload.con.Account.Name = this.responsePayload.con.Account.Name && this.responsePayload.con.Account.Name.length > 13 ? this.responsePayload.con.Account.Name.substring(0, 13) + '..' : this.responsePayload.con.Account.Name;
        this.responsePayload.con.Phone = this.responsePayload.con.Phone && this.responsePayload.con.Phone.length > 13 ? this.responsePayload.con.Phone.substring(0, 13) + '..' : this.responsePayload.con.Phone;
        this.responsePayload.con.Email = this.responsePayload.con.Email && this.responsePayload.con.Email.length > 13 ? this.responsePayload.con.Email.substring(0, 13) + '..' : this.responsePayload.con.Email;
        this.responsePayload.con.MobilePhone = this.responsePayload.con.MobilePhone && this.responsePayload.con.MobilePhone.length > 13 ? this.responsePayload.con.MobilePhone.substring(0, 13) + '..' : this.responsePayload.con.MobilePhone;

        this.responsePayload.opp.Name = this.responsePayload.opp.Name && this.responsePayload.opp.Name.length > 30 ? this.responsePayload.opp.Name.substring(0, 30) : this.responsePayload.opp.Name;
        this.responsePayload.opp.Account_Name__r.Name = this.responsePayload.opp.Account_Name__r.Name && this.responsePayload.opp.Account_Name__r.Name.length > 13 ? this.responsePayload.opp.Account_Name__r.Name.substring(0, 13) : this.responsePayload.opp.Account_Name__r.Name;
        this.responsePayload.opp.Close_Date__c = this.responsePayload.opp.Close_Date__c && this.responsePayload.opp.Close_Date__c.length > 13 ? this.responsePayload.opp.Close_Date__c.substring(0, 13) : this.responsePayload.opp.Close_Date__c;
        this.responsePayload.opp.Amount__c = this.responsePayload.opp.Amount__c && this.responsePayload.opp.Amount__c.length > 13 ? this.responsePayload.opp.Amount__c.substring(0, 13) : this.responsePayload.opp.Amount__c;
        this.responsePayload.opp.Owner.Name = this.responsePayload.opp.Owner.Name && this.responsePayload.opp.Owner.Name.length > 13 ? this.responsePayload.opp.Owner.Name.substring(0, 13) : this.responsePayload.opp.Owner.Name;

    }
}