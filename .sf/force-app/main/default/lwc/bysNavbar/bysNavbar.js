import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';

import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import EMAIL_FIELD from '@salesforce/schema/User.Email';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';

import basePath from "@salesforce/community/basePath";

// Static resource
import BYAHUT_LOGO from '@salesforce/resourceUrl/ByahutPdfLogo';

// Apex Controller Imports
import getNotifications from '@salesforce/apex/BysNavbarController.getNotifications';
import getOlderNotifications from '@salesforce/apex/BysNavbarController.getOlderNotifications';
import markNotificationRead from '@salesforce/apex/BysNavbarController.markNotificationRead';
import markAllRead from '@salesforce/apex/BysNavbarController.markAllRead';

const USER_FIELDS = [NAME_FIELD, EMAIL_FIELD, PROFILE_NAME_FIELD];

const NAV_CONFIG = [
    { id: 'home', label: 'Home', navType: 'url', url: '/',
        visibleFor: ['Sales Executive', 'Station Staff', 'Operations Executive', 'Purchase Executive','Accounts Executive'] },

    { id: 'lead', label: 'Lead', navType: 'url', url: '/lead/Lead__c/Default',
        visibleFor: ['Sales Executive'] },

    { id: 'account', label: 'Account', navType: 'standard', objectApiName: 'Account',
        visibleFor: ['Sales Executive'] },

    { id: 'contacts', label: 'Contacts', navType: 'standard', objectApiName: 'Contact',
        visibleFor: ['Sales Executive'] },

    { id: 'opportunity', label: 'Opportunity', navType: 'url', url: '/opportunity/Opportunity__c/Default',
        visibleFor: ['Sales Executive', 'Operations Executive'] },

    { id: 'salesorder', label: 'Sales Order', navType: 'url', url: '/sales-order/Sales_Order__c/Default',
        visibleFor: ['Sales Executive', 'Operations Executive'] },

    { id: 'challan', label: 'Challan', navType: 'url', url: '/challan',
        visibleFor: ['Station Staff']
    },

    { id: 'challanobject', label: 'Challan', navType: 'url', url: '/challan/Challan__c/Default',
        visibleFor: ['Operations Executive','Accounts Executive']
    },

    { id: 'purchaserequest', label: 'Purchase Request', navType: 'url', url: '/purchase-request/Purchase_Request__c/Default',
        visibleFor: ['Purchase Executive'] },
    
    { id: 'itemvendorrate', label: 'Item Vendor Rate', navType: 'url', url: '/item-vendor-rate/Item_Vendor_Rate__c/Default',
        visibleFor: ['Purchase Executive'] },

    {
        id: 'purchaseorder', label: 'Purchase Order', navType: 'url', url: '/purchase-order/Purchase_Order__c/Default',
        visibleFor: ['Purchase Executive'] },

    {
        id: 'product', label: 'Product', navType: 'url', url: '/product/Product__c/Default',
        visibleFor: ['Operations Executive']
    },

    {
        id: 'todo', label: 'To-Do List', navType: 'url', url: '/to-do-list/To_Do_List__c/Default',
        visibleFor: ['Sales Executive', 'Operations Executive', 'Purchase Executive', 'Station Staff', 'Accounts Executive']
    }
];

export default class BysNavbar extends NavigationMixin(LightningElement) {

    logoUrl = BYAHUT_LOGO;

    @api activeId;

    @track userMenuOpen = false;
    @track notifOpen = false;

    userName = '';
    userEmail = '';
    userProfileName = '';

    // Dynamic Notifications State
    @track notifications = [];
    @track notificationCount = 0;
    @track notificationLoading = false;
    lastNotificationDate = null;
    isLoadingMore = false;

    @wire(getRecord, { recordId: USER_ID, fields: USER_FIELDS })
    wiredUser({ data, error }) {
        if (data) {
            this.userName = data.fields.Name.value;
            this.userEmail = data.fields.Email.value;
            this.userProfileName = data.fields.Profile?.value?.fields?.Name?.value || data.fields.Profile?.displayValue || '';
        } else if (error) {
            console.error('byahutNavbar: unable to load current user', error);
        }
    }

    get userInitials() {
        if (!this.userName) return '';
        return this.userName
            .split(' ')
            .filter(Boolean)
            .map((w) => w[0])
            .join('')
            .substring(0, 2)
            .toUpperCase();
    }

    get visibleNavItems() {
        return NAV_CONFIG
            .filter((item) => item.visibleFor.includes(this.userProfileName))
            .map((item) => ({
                ...item,
                cssClass: 'nav-item' + (item.id === this.activeId ? ' active' : '')
            }));
    }

    get hasNotifications() {
        return this.notificationCount > 0;
    }

    get userWrapClass() {
        return 'user-wrap' + (this.userMenuOpen ? ' open' : '');
    }

    get notifWrapClass() {
        return 'notif-wrap' + (this.notifOpen ? ' open' : '');
    }

    connectedCallback() {
        this._handleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._handleOutsideClick);
        this.loadNotifications();
    }

    disconnectedCallback() {
        if (this._handleOutsideClick) {
            document.removeEventListener('click', this._handleOutsideClick);
        }
    }

    handleOutsideClick = (event) => {
        if (this.userMenuOpen && !this.template.querySelector('.user-wrap')?.contains(event.target)) {
            this.userMenuOpen = false;
        }
        if (this.notifOpen && !this.template.querySelector('.notif-wrap')?.contains(event.target)) {
            this.notifOpen = false;
        }
    };

    handleNavClick(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        const item = NAV_CONFIG.find((i) => i.id === id);
        this.activeId = id;
        
        if (!item) return;

        if (item.navType === 'standard' || item.navType === 'custom') {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: item.objectApiName,
                    actionName: 'list'
                }
            });
        } else if (item.navType === 'url') {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: item.url }
            });
        }
    }

    toggleUserMenu(event) {
        event.stopPropagation();
        this.notifOpen = false;
        this.userMenuOpen = !this.userMenuOpen;
    }

    async toggleNotif(event) {
        event.stopPropagation();
        this.userMenuOpen = false;
        this.notifOpen = !this.notifOpen;
        if (this.notifOpen) {
            await this.loadNotifications();
        }
    }

    formatDate(dateValue) {
        if (!dateValue) return '';
        return new Date(dateValue).toLocaleString();
    }

    async loadNotifications() {
        console.log('[DEBUG] loadNotifications START');
        try {
            this.notificationLoading = true;
            const result = await getNotifications();
            const unreadList = [];
            this.notificationCount = result.unreadCount || 0;

            if (result.notifications && result.notifications.length > 0) {
                result.notifications.filter(item => !item.read).forEach(item => {
                    unreadList.push({
                        id: item.id,
                        title: item.title,
                        description: item.body,
                        targetId: item.targetId,
                        read: item.read,
                        seen: item.seen,
                        timestamp: this.formatDate(item.activityDate),
                        rowClass: item.read ? 'notif-row read' : 'notif-row'
                    });
                });
                this.lastNotificationDate = result.notifications[result.notifications.length - 1].activityDate;
            }

            this.notifications = unreadList;
        } catch (error) {
            console.error('[DEBUG] loadNotifications Error:', error);
        } finally {
            this.notificationLoading = false;
        }
    }

    async handleMarkAllRead(event) {
        event.stopPropagation();
        try {
            await markAllRead();
            this.notifications = this.notifications.map((n) => ({
                ...n,
                read: true,
                rowClass: 'notif-row read'
            }));
            this.notificationCount = 0;
        } catch (error) {
            console.error('[DEBUG] markAllRead Error:', error);
        }
    }

    async handleNotificationClick(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.id;
        const notificationId = event.currentTarget.dataset.notificationid;

        try {
            await markNotificationRead({ notificationId: notificationId });
            this.notifications = this.notifications.filter(item => item.id !== notificationId);
            this.notificationCount = this.notifications.length;
        } catch (error) {
            console.error('[DEBUG] markNotificationRead Error:', error);
        }

        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            });
        }
        this.notifOpen = false;
    }

    async handleNotificationScroll(event) {
        const element = event.target;
        if (this.isLoadingMore || !this.lastNotificationDate) return;

        const reachedBottom = element.scrollTop + element.clientHeight >= element.scrollHeight - 20;
        if (!reachedBottom) return;

        try {
            this.isLoadingMore = true;
            const result = await getOlderNotifications({ before: this.lastNotificationDate });
            if (result.notifications && result.notifications.length) {
                result.notifications.forEach(item => {
                    this.notifications.push({
                        id: item.id,
                        title: item.title,
                        description: item.body,
                        targetId: item.targetId,
                        read: item.read,
                        seen: item.seen,
                        timestamp: this.formatDate(item.activityDate),
                        rowClass: item.read ? 'notif-row read' : 'notif-row'
                    });
                });
                this.lastNotificationDate = result.notifications[result.notifications.length - 1].activityDate;
                this.notifications = [...this.notifications];
            }
        } catch (error) {
            console.error('[DEBUG] handleNotificationScroll Error:', error);
        } finally {
            this.isLoadingMore = false;
        }
    }

    handleMyProfile() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'profile' }
        });
    }

    handleSettings() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/settings' }
        });
    }

    handleLogout() {
        this[NavigationMixin.Navigate]({
            type: "comm__loginPage",
            attributes: {
                actionName: "logout"
            }
        });
    }
}