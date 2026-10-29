import { LightningElement, api, track, wire } from 'lwc';
import updateRecordOwner from '@salesforce/apex/AssignReocrdToUserCmpController.updateRecordOwner';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import USER_ID from '@salesforce/user/Id';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';

const SALES_PROFILES = ['Sales Team', 'Sales Executive'];
const OPS_PROFILES = ['Operations Team','Operations Executive'];

export default class AssignReocrdToUserCmp extends LightningElement {
    @api recordId;
    @api objectApiName;
    currentUserId = USER_ID;
    @track selectedUserId;
    @track selectedTeam = 'Operations';

    displayInfo = {
        primaryField: 'Name'
    };

    teamOptions = [
        { label: 'Sales Team', value: 'Sales' },
        { label: 'Operations Team', value: 'Operations' }
    ];

    @wire(getRecord, {
        recordId: '$currentUserId',
        fields: [PROFILE_NAME_FIELD]
    }) wiredUser;

    /*   get isLead() {
          return this.recordId && this.recordId.startsWith('a01');
      }
  
      get isOpportunity() {
          return this.recordId && this.recordId.startsWith('a07');
      } */

    get isLead() {
        return this.recordId && this.objectApiName === 'Lead__c';
    }

    get isOpportunity() {
        return this.recordId && this.objectApiName === 'Opportunity__c';
    }

    // Dynamic Header based on record type
    get header() {
        if (this.isLead) {
            return 'Assign Lead';
        } else if (this.isOpportunity) {
            return 'Assign Opportunity';
        }
        return 'Assign Record';
    }

    get userProfileName() {
        return getFieldValue(this.wiredUser.data, PROFILE_NAME_FIELD);
    }

    // Team Selection sirf Opportunity par hi dikhega (Lead par nahi)
    get showTeamSelection() {
        if (this.isLead) {
            return false;
        }
        const profile = this.userProfileName;
        return profile === 'System Administrator' || SALES_PROFILES.includes(profile);
    }

    // Dynamic Record Picker Filter
    get activeFilter() {
        let profileList = [];
        const currentProfile = this.userProfileName;

        // Lead par strictly sirf Sales Team profiles dikhenge
        if (this.isLead) {
            profileList = SALES_PROFILES;
        } else {
            // Opportunity ke case me selectedTeam ya profile check hoga
            if (currentProfile === 'System Administrator' || SALES_PROFILES.includes(currentProfile)) {
                profileList = this.selectedTeam === 'Sales' ? SALES_PROFILES : OPS_PROFILES;
            } else if (OPS_PROFILES.includes(currentProfile)) {
                profileList = OPS_PROFILES;
            }
        }

        return {
            criteria: [
                {
                    fieldPath: 'IsActive',
                    operator: 'eq',
                    value: true
                },
                {
                    fieldPath: 'Profile.Name',
                    operator: 'in',
                    value: profileList
                }
            ],
            logic: '1 AND 2'
        };
    }

    handleTeamChange(event) {
        this.selectedTeam = event.detail.value;
        this.selectedUserId = null;
        const recordPickers = this.template.querySelectorAll('lightning-record-picker');
        if (recordPickers) {
            recordPickers.forEach(picker => {
                picker.value = null;
                if (typeof picker.clearSelection === 'function') {
                    picker.clearSelection();
                }
            });
        }
    }

    handleUserChange(event) {
        this.selectedUserId = event.detail.recordId;
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
    }

    async handleFooterSave() {
        const allValid = [...this.template.querySelectorAll('.validate')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (!allValid) {
            return;
        }

        try {
            await updateRecordOwner({
                selectedUserId: this.selectedUserId,
                recordId: this.recordId
            });

            this.dispatchEvent(new CloseActionScreenEvent());
            this.showToast('Success', 'Record Assigned Successfully', 'success');
            setTimeout(() => {
                window.location.reload();
            }, 800);
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            console.log('Error', error);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}