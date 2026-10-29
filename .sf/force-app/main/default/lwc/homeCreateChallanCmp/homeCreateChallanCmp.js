import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class HomeCreateChallanCmp extends NavigationMixin(LightningElement) {

    navigateToChallanPage() {
        const isCommunity = window.location.pathname.startsWith('/s/') || window.location.pathname.includes('/s');

        if (isCommunity) {
            // Experience Cloud / Community Page Navigation
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/create-challan-home'
                }
            });
        } else {
            // Standard Lightning App Tab Navigation
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: {
                    apiName: 'Create_Challan_Home'
                }
            });
        }
    }
}