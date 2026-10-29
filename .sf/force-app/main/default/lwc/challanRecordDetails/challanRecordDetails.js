import { LightningElement, api, wire, track } from 'lwc';

import getChallanHierarchy from '@salesforce/apex/ChallanDetailController.getChallanHierarchy';
import updateLineItemQuantities from '@salesforce/apex/ChallanDetailController.updateLineItemQuantities';
import savePickerPackerDetail from '@salesforce/apex/ChallanDetailController.savePickerPackerDetail';
import createPurchaseRequestWithItems from '@salesforce/apex/ChallanDetailController.createPurchaseRequestWithItems';
import toUpdateSalesOrderStatus from '@salesforce/apex/ChallanDetailController.toUpdateSalesOrderStatus';
import assignChallanToStation from '@salesforce/apex/ChallanDetailController.assignChallanToStation';
import updateInvoiceReadyforDispatch from '@salesforce/apex/ChallanDetailController.updateInvoiceReadyforDispatch';
import fetchLogisticsUser from '@salesforce/apex/ChallanDetailController.fetchLogisticsUser';
import fetchDeliveryRecord from '@salesforce/apex/ChallanDetailController.fetchDeliveryRecord';
import notifyAccountsForInvoice from '@salesforce/apex/ChallanDetailController.notifyAccountsForInvoice';

import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import USER_ID from '@salesforce/user/Id';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';
import ID_FIELD from '@salesforce/schema/Challan__c.Id';
import STATUS_FIELD from '@salesforce/schema/Challan__c.Status__c';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import DELIVERY_DETAIL_OBJECT from '@salesforce/schema/Delivery_Detail__c';

export default class ChallanRecordDetails extends NavigationMixin(LightningElement) {
    @api recordId;
    @track challanData;
    @track error;
    @track isLoading = true;
    @track isWarehouseUser = false;
    @track isStationUser = false;
    @track hasQuantityChanged = false;
    // PR Modal & Form Tracking
    @track isPRModalOpen = false;
    @track modalPRLineItems = [];

    // Form and record tracking for Picker & Packer Detail
    @track existingDetailId = null;
    @track selectedPickerId = null;
    @track selectedPackerId = null;
    @track selectedStationUserId = null;
    @track instructions = '';
    @track isEditingPickerDetail = true;
    @track userProfileName = '';

    @track logisticsUserId;
    salesDetailRecordTypeId;

    // Change Data Capture - notifies when Challan__c Status__c changes to 'Dispatched'
    challanChangeEventChannel = '/data/Challan__ChangeEvent';
    challanChangeEventSubscription = null;

    // Status mapping with custom button labels and target statuses
    statusFlowConfig = {
        'New': { label: 'Ready for Picker', targetStatus: 'Ready for Picker' },
        'Open': { label: 'Ready for Picker', targetStatus: 'Ready for Picker' },
        'Ready for Picker': { label: 'Start Picking', targetStatus: 'Picking In Progress' },
        'Picking In Progress': { label: 'Complete Picking', targetStatus: 'Ready for Packer' },
        'Ready for Packer': { label: 'Start Packing', targetStatus: 'Packing In Progress' },
        'Packing In Progress': { label: 'Complete Packing', targetStatus: 'Packing Completed/Invoice Pending' },
        'Invoiced/Ready For Dispatch': { label: 'Dispatch', targetStatus: 'Dispatched' },
        'Dispatched': { label: 'Update Delivery Details', targetStatus: 'Dispatched' },
        'Delivered/Payment Pending': { label: 'Update Delivery Details', targetStatus: 'Delivered/Payment Pending' },
        'Delivered/Payment Received': { label: 'Update Delivery Details', targetStatus: 'Delivered/Payment Received' }
    };

    // Filter to display Active Masters with Type = 'Picker'
    pickerFilter = {
        criteria: [
            {
                fieldPath: 'IsActive__c',
                operator: 'eq',
                value: true
            },
            {
                fieldPath: 'Type__c',
                operator: 'eq',
                value: 'Picker'
            }
        ]
    };

    // Filter to display Active Masters with Type = 'Packer'
    packerFilter = {
        criteria: [
            {
                fieldPath: 'IsActive__c',
                operator: 'eq',
                value: true
            },
            {
                fieldPath: 'Type__c',
                operator: 'eq',
                value: 'Packer'
            }
        ]
    };

    // Filter to display Active Station Masters
    stationUserFilter = {
        criteria: [
            {
                fieldPath: 'IsActive',
                operator: 'eq',
                value: true
            },
            {
                fieldPath: 'Profile.Name',
                operator: 'eq',
                value: 'Station Staff'
            }
        ]
    };

    wiredResult;

    @wire(getRecord, { recordId: USER_ID, fields: [PROFILE_NAME_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            const profileName = (data.fields.Profile.displayValue || data.fields.Profile.value.fields.Name.value || '').toLowerCase();
            this.userProfileName = profileName;
            this.isWarehouseUser = profileName.includes('system administrator') || profileName.includes('warehouse team');
            this.isStationUser = profileName.includes('station staff');
            this.isStationUserOrAdminOrWereHouse = profileName.includes('station staff') || profileName.includes('system administrator') || profileName.includes('warehouse team') || profileName.includes('accounts') || profileName.includes('accounts executive');

            if (this.isStationUser) {
                this.isEditingPickerDetail = false;
            }
        } else if (error) {
            this.isWarehouseUser = false;
            this.isStationUser = false;
        }
    }

    @wire(getChallanHierarchy, { challanId: '$recordId' })
    wiredHierarchy(result) {
        this.wiredResult = result;
        this.isLoading = true;
        if (result.data) {
            this.challanData = JSON.parse(JSON.stringify(result.data));

            // Default checkboxes state initialization for line items
            if (this.challanData && this.challanData.salesOrders) {
                this.challanData.salesOrders.forEach(soWrap => {
                    soWrap.isAllSelected = false;
                    if (soWrap.lineItems) {
                        soWrap.lineItems.forEach(item => {
                            item.isChecked = false;
                        });
                    }
                });
            }

            this.error = undefined;

            if (this.challanData.pickerPackerDetail) {
                const detail = this.challanData.pickerPackerDetail;
                this.existingDetailId = detail.Id;
                this.selectedPickerId = detail.Picker__c;
                this.selectedPackerId = detail.Packer__c;
                this.selectedStationUserId = detail.Station_User__c;
                this.instructions = detail.Instructions__c || '';
                this.isEditingPickerDetail = false;
            } else {
                this.existingDetailId = null;
                this.isEditingPickerDetail = !this.isStationUser;
            }

            this.hasQuantityChanged = false;
            this.isLoading = false;
        } else if (result.error) {
            console.log('result.error : error :', result.error);
            this.error = result.error.body ? result.error.body.message : result.error.message;
            this.challanData = undefined;
            this.isLoading = false;
        }
    }

    @wire(fetchLogisticsUser)
    wiredWarehouseUser({ data, error }) {
        if (data) {
            this.logisticsUserId = data[0].Id;
        } else if (error) {
            console.log('fetchLogisticsUser : error :', error);
        }
    }

    connectedCallback() {
        this.registerChallanChangeEventErrorListener();
        this.subscribeToChallanChangeEvent();
    }

    disconnectedCallback() {
        if (this.challanChangeEventSubscription) {
            unsubscribe(this.challanChangeEventSubscription, () => {
                this.challanChangeEventSubscription = null;
            });
        }
    }

    subscribeToChallanChangeEvent() {
        subscribe(this.challanChangeEventChannel, -1, (message) => {
            this.handleChallanChangeEvent(message);
        }).then((response) => {
            this.challanChangeEventSubscription = response;
        });
    }

    registerChallanChangeEventErrorListener() {
        onError((error) => {
            console.error('Challan__ChangeEvent EMP API error: ', error);
        });
    }

    handleChallanChangeEvent(message) {
        const payload = message?.data?.payload;
        const header = payload?.ChangeEventHeader;

        if (!header || header.entityName !== 'Challan__c') {
            return;
        }

        const isThisRecord = header.recordIds?.includes(this.recordId);
        const statusChangedToDispatched = header.changedFields?.includes('Status__c') && payload.Status__c === 'Dispatched';

        if (isThisRecord && statusChangedToDispatched) {
            this.onChallanDispatched(payload);
        }
    }

    onChallanDispatched(payload) {
        return refreshApex(this.wiredResult);
    }

    get isStationOrAdmin() {
        return this.userProfileName.includes('system administrator') || this.userProfileName.includes('station staff');
    }

    get currentStatus() {
        return this.challanData?.challan?.Status__c || null;
    }

    get canEditPickerDetail() {
        return !this.isStationUser;
    }

    get canRaisePR() {
        return this.isWarehouseUser && !this.challanData?.hasExistingPR;
    }

    get hasExistingPR() {
        return Boolean(this.challanData?.hasExistingPR);
    }

    get deliveryLinks() {
        return this.challanData?.deliveries || [];
    }

    get hasDelivery() {
        return this.deliveryLinks.length > 0;
    }

    get isAllPRSelected() {
        return this.modalPRLineItems.length > 0 && this.modalPRLineItems.every(item => item.selected);
    }

    // Dynamic Status Action Button Getters
    get currentStatusConfig() {
        const status = this.challanData?.challan?.Status__c || 'New';
        return this.statusFlowConfig[status] || null;
    }

    get nextStatusLabel() {
        return this.currentStatusConfig?.label || null;
    }

    get showStatusActionButton() {
        return Boolean(this.nextStatusLabel);
    }

    get showSaveQuantitiesButton() {
        return this.isWarehouseUser && this.hasQuantityChanged;
    }

    get totalSalesOrders() {
        return this.challanData && this.challanData.salesOrders ? this.challanData.salesOrders.length : 0;
    }

    get hasSalesOrders() {
        return this.totalSalesOrders > 0;
    }

    get saveButtonLabel() {
        return this.existingDetailId ? 'Update Detail' : 'Save Detail';
    }

    get pickerName() {
        return this.challanData?.pickerPackerDetail?.Picker__r?.Name || '-';
    }

    get packerName() {
        return this.challanData?.pickerPackerDetail?.Packer__r?.Name || '-';
    }

    get stationUserName() {
        return this.challanData?.pickerPackerDetail?.Station_User__r?.Name || '-';
    }

    get instructionsDisplay() {
        return this.challanData?.pickerPackerDetail?.Instructions__c || '-';
    }

    get isWarehouseUserButtonDisable() {
        return (this.userProfileName.includes('warehouse team') && (this.challanData?.challan?.Status__c == 'New' || this.challanData?.challan?.Status__c == 'Open' || this.challanData?.challan?.Status__c == 'Invoiced/Ready For Dispatch' || this.isAfterDispatch(this.challanData?.challan?.Status__c)) || this.userProfileName.includes('system administrator') || this.userProfileName.includes('station staff'));
    }

    get createdPickerPackerDetail() {
        return this.challanData?.pickerPackerDetail;
    }

    get totalItems() {
        return this.challanData?.salesOrders ? this.challanData.salesOrders.reduce((accumulator, currentObject) => {
            return Number(accumulator) + Number(currentObject.totalLineItems);
        }, 0) : 0;
    }

    // Line Items Checkbox Handlers (System Admin & Station Staff)
    handleSelectAllLineItems(event) {
        const soId = event.target.dataset.soid;
        const isChecked = event.target.checked;
        if (this.challanData && this.challanData.salesOrders) {
            const targetSO = this.challanData.salesOrders.find(so => so.salesOrder.Id === soId);
            if (targetSO) {
                targetSO.isAllSelected = isChecked;
                if (targetSO.lineItems) {
                    targetSO.lineItems.forEach(item => {
                        item.isChecked = isChecked;
                    });
                }
            }
        }
    }

    handleLineItemCheck(event) {
        const lineItemId = event.target.dataset.id;
        const soId = event.target.dataset.soid;
        const isChecked = event.target.checked;

        if (this.challanData && this.challanData.salesOrders) {
            const targetSO = this.challanData.salesOrders.find(so => so.salesOrder.Id === soId);
            if (targetSO && targetSO.lineItems) {
                const item = targetSO.lineItems.find(li => li.Id === lineItemId);
                if (item) {
                    item.isChecked = isChecked;
                }
                targetSO.isAllSelected = targetSO.lineItems.length > 0 && targetSO.lineItems.every(li => li.isChecked);
            }
        }
    }

    // Input Handlers
    handlePickerChange(event) {
        this.selectedPickerId = event.detail.recordId;
    }

    handlePackerChange(event) {
        this.selectedPackerId = event.detail.recordId;
    }

    handleStationUserChange(event) {
        this.selectedStationUserId = event.detail.recordId;
    }

    handleInstructionsChange(event) {
        this.instructions = event.target.value;
    }

    handleEnableEditPickerDetail() {
        if (!this.isStationUser) {
            this.isEditingPickerDetail = true;
        }
    }

    handleSavePickerDetail() {
        if (!this.selectedPickerId || !this.selectedPackerId || !this.selectedStationUserId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Required Fields Missing',
                    message: 'Please select Picker, Packer, and Station User before saving.',
                    variant: 'warning'
                })
            );
            return;
        }

        this.isLoading = true;
        savePickerPackerDetail({
            detailId: this.existingDetailId,
            challanId: this.recordId,
            pickerId: this.selectedPickerId,
            packerId: this.selectedPackerId,
            stationUserId: this.selectedStationUserId,
            instructions: this.instructions
        }).then(() => {
            const currentStatus = this.challanData?.challan?.Status__c;
            if (!currentStatus || currentStatus === 'New') {
                const fields = {};
                fields[ID_FIELD.fieldApiName] = this.recordId;
                fields[STATUS_FIELD.fieldApiName] = 'Open';
                return updateRecord({ fields });
            }
            return Promise.resolve();
        }).then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Picker & Packer Detail saved successfully.',
                    variant: 'success'
                })
            );
            this.isEditingPickerDetail = false;

            return refreshApex(this.wiredResult);
        })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error saving detail',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    async handleStatusProgression() {
        const config = this.currentStatusConfig;
        if (!config || !config.targetStatus) {
            return;
        }

        // Validation for Complete Picking & Complete Packing: Sabhi line items select hone chahiye
        const isCompletePickingAction = this.currentStatus === 'Picking In Progress';
        const isCompletePackingAction = this.currentStatus === 'Packing In Progress';

        if (isCompletePickingAction || isCompletePackingAction) {
            let totalItemsCount = 0;
            let checkedItemsCount = 0;

            if (this.challanData && this.challanData.salesOrders) {
                this.challanData.salesOrders.forEach(soWrap => {
                    if (soWrap.lineItems) {
                        soWrap.lineItems.forEach(item => {
                            totalItemsCount++;
                            if (item.isChecked) {
                                checkedItemsCount++;
                            }
                        });
                    }
                });
            }

            if (totalItemsCount > 0 && checkedItemsCount < totalItemsCount) {
                const actionName = isCompletePickingAction ? 'Complete Picking' : 'Complete Packing';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Validation Error',
                        message: `Please select all line items before proceeding with ${actionName}.`,
                        variant: 'error'
                    })
                );
                return;
            }
        }

        if (this.currentStatus != 'Invoiced/Ready For Dispatch' && !this.isAfterDispatch(this.currentStatus)) {
            const nextStatus = config.targetStatus;
            this.isLoading = true;
            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.recordId;
            fields[STATUS_FIELD.fieldApiName] = nextStatus;

            const recordInput = { fields };

            updateRecord(recordInput)
                .then(() => {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: `Status updated to ${nextStatus}.`,
                            variant: 'success'
                        })
                    );
                    if (this.currentStatusConfig.targetStatus === 'Picking In Progress' || this.currentStatusConfig.targetStatus === 'Packing Completed/Invoice Pending') {
                        toUpdateSalesOrderStatus({
                            challanId: this.recordId
                        }).then((result) => {
                        }).catch((error) => {
                            console.log('OUTPUT : toUpdateSalesOrderStatus Error', error);
                        });
                    }

                    if (nextStatus === 'Ready for Picker') {
                        assignChallanToStation({
                            challanId: this.recordId,
                            stationUserId: this.challanData?.pickerPackerDetail?.Station_User__c
                        }).then((result) => {
                            console.log('Notify Station Successfully!!!');
                        }).catch((error) => {
                            console.log('assignChallanToStation', error);
                        });
                    }

                    if (nextStatus == 'Packing Completed/Invoice Pending') {
                        notifyAccountsForInvoice({ challanId: this.recordId }).then((result) => {

                        }).catch((error) => {
                            console.log('notifyAccountsForInvoice : error :', error);
                        });
                    }

                    this.dispatchEvent(new CustomEvent('statusupdate', {
                        detail: { objectApiName: 'Challan__c' }
                    }));

                    return refreshApex(this.wiredResult);
                })
                .catch(error => {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error updating status',
                            message: error.body ? error.body.message : error.message,
                            variant: 'error'
                        })
                    );
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } else if (this.currentStatus == 'Invoiced/Ready For Dispatch') {
            if (!this.salesDetailRecordTypeId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Sales Detail record type was not found.',
                        variant: 'error'
                    })
                );
                return;
            }

            const defaultValues = encodeDefaultFieldValues({
                Challan__c: this.recordId,
                Promised_Items__c: this.totalItems,
                OwnerId: this.logisticsUserId,
                Delivery_Status__c: 'Dispatched'
            });

            this[NavigationMixin.Navigate]({
                type: "standard__objectPage",
                attributes: {
                    objectApiName: "Delivery_Detail__c",
                    actionName: "new",
                },
                state: {
                    recordTypeId: this.salesDetailRecordTypeId,
                    defaultFieldValues: defaultValues,
                    nooverride: '1',
                    navigationLocation: 'RELATED_LIST',
                    backgroundContext: `/lightning/r/Challan__c/${this.recordId}/view`
                },
            }).then(() => {
                window.location.reload();
            });
        } else if (this.isAfterDispatch(this.currentStatus)) {

            var deliveryRecordId;
            await fetchDeliveryRecord({ challanId: this.recordId }).then((result) => {
                if (result) {
                    deliveryRecordId = result[0].Id;
                }
            });

            this[NavigationMixin.Navigate]({
                type: "standard__objectPage",
                attributes: {
                    recordId: deliveryRecordId,
                    objectApiName: "Delivery_Detail__c",
                    actionName: "edit",
                },
                state: {
                    nooverride: '1',
                    navigationLocation: 'RELATED_LIST',
                    backgroundContext: `/lightning/r/Challan__c/${this.recordId}/view`
                },
            });
        }
    }

    handleDispatchedQtyChange(event) {
        const itemId = event.target.dataset.id;
        const enteredVal = event.target.value;
        let dispatchedQty = enteredVal === '' ? 0 : Number(enteredVal);

        if (this.challanData && this.challanData.salesOrders) {
            for (let soWrap of this.challanData.salesOrders) {
                for (let item of soWrap.lineItems) {
                    if (item.Id === itemId) {
                        const totalQty = Number(item.Quantity__c) || 0;

                        if (dispatchedQty > totalQty) {
                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'Validation Error',
                                    message: `Dispatched quantity cannot be greater than total quantity (${totalQty}).`,
                                    variant: 'error'
                                })
                            );
                            dispatchedQty = totalQty;
                            event.target.value = totalQty;
                        } else if (dispatchedQty < 0) {
                            dispatchedQty = 0;
                            event.target.value = 0;
                        }

                        item.Total_Dispatch_Quantity__c = dispatchedQty;
                        item.Total_Pending_Quantity__c = Math.max(0, totalQty - dispatchedQty);
                        break;
                    }
                }
            }
        }
        this.hasQuantityChanged = true;
    }

    handleSaveQuantities() {
        this.isLoading = true;
        let itemsToUpdate = [];

        if (this.challanData && this.challanData.salesOrders) {
            for (let soWrap of this.challanData.salesOrders) {
                for (let item of soWrap.lineItems) {
                    itemsToUpdate.push({
                        Id: item.Id,
                        Total_Dispatch_Quantity__c: Number(item.Total_Dispatch_Quantity__c) || 0,
                        Total_Pending_Quantity__c: Number(item.Total_Pending_Quantity__c) || 0
                    });
                }
            }
        }

        updateLineItemQuantities({ lineItemsToUpdate: itemsToUpdate })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Quantities updated successfully.',
                        variant: 'success'
                    })
                );
                this.hasQuantityChanged = false;
                return refreshApex(this.wiredResult);
            })
            .catch(err => {
                console.log('updateLineItemQuantities : error :', err);
                this.error = err.body ? err.body.message : err.message;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating records',
                        message: this.error,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Purchase Request (PR) Methods
    handleOpenPRModal() {
        let items = [];
        if (this.challanData && this.challanData.salesOrders) {
            this.challanData.salesOrders.forEach(soWrap => {
                if (soWrap.lineItems) {
                    soWrap.lineItems.forEach(lineItem => {
                        const pending = lineItem.Total_Pending_Quantity__c != null ? Number(lineItem.Total_Pending_Quantity__c) : (Number(lineItem.Quantity__c) || 0);
                        items.push({
                            Id: lineItem.Id,
                            Name: lineItem.Name,
                            productId: lineItem.Product__c,
                            productName: lineItem.Product__r?.Name || '-',
                            pendingQty: pending,
                            requestedQty: pending,
                            selected: false,
                            isQtyDisabled: true
                        });
                    });
                }
            });
        }
        this.modalPRLineItems = items;
        this.isPRModalOpen = true;
    }

    handleClosePRModal() {
        this.isPRModalOpen = false;
    }

    handleSelectAllPRItems(event) {
        const isChecked = event.target.checked;
        this.modalPRLineItems = this.modalPRLineItems.map(item => ({
            ...item,
            selected: isChecked,
            isQtyDisabled: !isChecked
        }));
    }

    handlePRCheckboxChange(event) {
        const lineId = event.target.dataset.id;
        const isChecked = event.target.checked;
        this.modalPRLineItems = this.modalPRLineItems.map(item => {
            if (item.Id === lineId) {
                return {
                    ...item,
                    selected: isChecked,
                    isQtyDisabled: !isChecked
                };
            }
            return item;
        });
    }

    handlePRQtyChange(event) {
        const lineId = event.target.dataset.id;
        const enteredVal = event.target.value;
        this.modalPRLineItems = this.modalPRLineItems.map(item => {
            if (item.Id === lineId) {
                return {
                    ...item,
                    requestedQty: enteredVal === '' ? 0 : Number(enteredVal)
                };
            }
            return item;
        });
    }

    handleSubmitPR() {
        const selectedItems = this.modalPRLineItems.filter(item => item.selected);

        if (selectedItems.length === 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Selection Required',
                    message: 'Please select at least one line item to raise a Purchase Request.',
                    variant: 'warning'
                })
            );
            return;
        }

        for (let item of selectedItems) {
            if (!item.requestedQty || item.requestedQty <= 0) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Invalid Quantity',
                        message: `Requested quantity for ${item.Name} must be greater than 0.`,
                        variant: 'error'
                    })
                );
                return;
            }
        }

        const prPayload = selectedItems.map(item => ({
            lineItemId: item.Id,
            productId: item.productId,
            quantity: item.requestedQty
        }));

        this.isLoading = true;
        createPurchaseRequestWithItems({
            challanId: this.recordId,
            items: prPayload
        }).then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Purchase Request created and assigned to Purchase Team Queue.',
                    variant: 'success'
                })
            );
            this.isPRModalOpen = false;
            return refreshApex(this.wiredResult);
        })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error creating Purchase Request',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    @wire(getObjectInfo, { objectApiName: DELIVERY_DETAIL_OBJECT })
    wiredDeliveryObjectInfo({ data }) {
        if (!data) {
            return;
        }
        const salesDetail = Object.values(data.recordTypeInfos).find(
            (info) => info.name === 'Sales Detail'
        );
        this.salesDetailRecordTypeId = salesDetail ? salesDetail.recordTypeId : null;
    }

    handleClickDelivery(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                objectApiName: 'Delivery_Detail__c',
                actionName: 'view'
            }
        });
    }

    handleClickPrRaised(event) {
        event.preventDefault();

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.challanData.existingPRId,
                objectApiName: 'Purchase_Request__c',
                actionName: 'view'
            }
        });
    }

    get statusIsPackkingCompleted() {
        return (this.challanData?.challan?.Status__c === 'Packing Completed/Invoice Pending' ||
            this.challanData?.challan?.Status__c === 'Invoiced/Ready For Dispatch' || this.isAfterDispatch(this.challanData?.challan?.Status__c) || this.isStationUser
        );
    }

    get statusNotIsPackkingCompleted() {
        return !(this.challanData?.challan?.Status__c === 'Packing Completed/Invoice Pending' ||
            this.challanData?.challan?.Status__c === 'Invoiced/Ready For Dispatch' || this.isAfterDispatch(this.challanData?.challan?.Status__c)
        );
    }

    get acceptedFormats() {
        return [".pdf"];
    }

    async handleUploadFinished(event) {
        this.isLoading = true;
        const uploadedFiles = event.detail.files;

        if (!uploadedFiles || uploadedFiles.length === 0) {
            this.isLoading = false;
            return;
        }

        const latestFile = uploadedFiles[uploadedFiles.length - 1];

        try {
            await updateInvoiceReadyforDispatch({
                contentDocumentId: latestFile.documentId,
                challanId: this.recordId
            });

            getRecordNotifyChange([{ recordId: this.recordId }]);

            await refreshApex(this.wiredResult);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Invoice uploaded and Challan status updated successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error updating ContentVersion:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error updating invoice',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    get IsPackingCompletedAndAccountsAndSysAdmin() {
        return (this.challanData?.challan?.Status__c === 'Packing Completed/Invoice Pending' || this.challanData?.challan?.Status__c === 'Invoiced/Ready For Dispatch' || this.isAfterDispatch(this.challanData?.challan?.Status__c)) && (this.userProfileName.includes('system administrator') || this.userProfileName.includes('accounts') || this.userProfileName.includes('accounts executive'));
    }

    handleNavigateToRecordNewTab(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.id;
        const objectApiName = event.currentTarget.dataset.object;

        if (!recordId) return;

        // Mobile browser / Salesforce Mobile App detection
        const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);

        if (isMobile) {
            // Mobile ke liye native direct navigation (no popup blocker issues)
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: objectApiName,
                    actionName: 'view'
                }
            });
        } else {
            // Desktop ke liye standard new-tab behavior
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: objectApiName,
                    actionName: 'view'
                }
            }).then(url => {
                window.open(url, '_blank');
            }).catch(error => {
                console.error('Navigation error:', error);
            });
        }
    }

    get lineItemCheckboxHeader() {
        if (this.currentStatus === 'Picking In Progress') {
            return 'Picked';
        } else if (this.currentStatus === 'Packing In Progress') {
            return 'Packed';
        }
        return '';
    }

    get showLineItemCheckboxes() {
        return this.isStationOrAdmin && this.statusInPickingPackingProgress;
    }

    get statusInPickingPackingProgress() {
        return !(this.challanData?.challan?.Status__c === 'Packing Completed/Invoice Pending' ||
            this.challanData?.challan?.Status__c === 'Invoiced/Ready For Dispatch' || this.isAfterDispatch(this.challanData?.challan?.Status__c)
            || this.challanData?.challan?.Status__c === 'New' || this.challanData?.challan?.Status__c === 'Open'
            || this.challanData?.challan?.Status__c === 'Ready for Picker' || this.challanData?.challan?.Status__c === 'Ready for Packer'
        );
    }

    isAfterDispatch(status) {
        return status === 'Dispatched'
            || status === 'Delivered/Payment Pending'
            || status === 'Delivered/Payment Received';
    }
}