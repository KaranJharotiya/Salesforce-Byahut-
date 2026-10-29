import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getSalesOrders from '@salesforce/apex/HomeCreateChallanController.getSalesOrders';
const DT = { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' };

const COLUMNS = [
    {
        label: 'Sales Order Name',
        fieldName: 'recordUrl',
        type: 'url',
        sortable: true,
        initialWidth: 160,
        wrapText: true,
        typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }
    },
    {
        label: 'Opportunity',
        fieldName: 'opportunityUrl',
        type: 'url',
        sortable: true,
        initialWidth: 225,
        wrapText: true,
        typeAttributes: { label: { fieldName: 'opportunityName' }, target: '_blank' }
    },
    {
        label: 'Status',
        fieldName: 'Status__c',
        sortable: true,
        initialWidth: 120
    },
    {
        label: 'Sales Order Date',
        fieldName: 'Sales_Order_Date__c',
        type: 'date',
        typeAttributes: DT,
        sortable: true,
        initialWidth: 190
    },
    {
        label: 'Owner Name',
        fieldName: 'ownerName',
        sortable: true,
        initialWidth: 160
    },
    {
        label: 'Created By',
        fieldName: 'createdByName',
        sortable: true,
        initialWidth: 160
    },
    {
        label: 'Created Date',
        fieldName: 'CreatedDate',
        type: 'date',
        typeAttributes: DT,
        sortable: true,
        initialWidth: 180
    }
];

// Checkbox (32) + row-number (52) columns, plus a small buffer so the
// vertical scrollbar does not force a horizontal scrollbar.
const NON_DATA_COLUMN_WIDTH = 100;
const BASE_TABLE_WIDTH = COLUMNS.reduce((sum, column) => sum + column.initialWidth, 0);

export default class SalesOrderSelectionCmp extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    rows = [];
    challanFromHome = true;
    isLoading = false;
    showChallan = false;

    pageSize = 10;
    pageNumber = 1;
    totalRecords = 0;

    // Sorting properties
    sortedBy;
    sortedDirection = 'asc';

    selectedSet = new Set();

    pageSizeOptions = [
        { label: '10', value: '10' },
        { label: '25', value: '25' },
        { label: '50', value: '50' },
        { label: '100', value: '100' }
    ];

    connectedCallback() {
        this.loadData();
    }

    renderedCallback() {
        this.observeTableContainer();
        this.fitColumnsToContainer();
    }

    disconnectedCallback() {
        if (this._tableResizeObserver) {
            this._tableResizeObserver.disconnect();
            this._tableResizeObserver = null;
        }
    }

    // initialWidth locks every column, so on a wide screen the grid stops
    // at the sum of those widths and leaves an empty gap. Scale the same
    // proportions to the container when there is room; keep the original
    // widths (and horizontal scroll) when there is not.
    observeTableContainer() {
        const container = this.template.querySelector('.datatable-container');
        if (!container || this._observedContainer === container) {
            return;
        }
        if (this._tableResizeObserver) {
            this._tableResizeObserver.disconnect();
        }
        this._observedContainer = container;
        this._tableResizeObserver = new ResizeObserver(() => {
            this.fitColumnsToContainer();
        });
        this._tableResizeObserver.observe(container);
    }

    fitColumnsToContainer() {
        const container = this.template.querySelector('.datatable-container');
        if (!container) {
            return;
        }

        const available = container.clientWidth - NON_DATA_COLUMN_WIDTH;
        if (available < 200) {
            return;
        }

        const originalKey = COLUMNS.map((column) => column.initialWidth).join(',');
        if (available <= BASE_TABLE_WIDTH) {
            if (this._appliedWidthKey && this._appliedWidthKey !== originalKey) {
                this._appliedWidthKey = originalKey;
                this.columns = COLUMNS;
            }
            return;
        }

        const scale = available / BASE_TABLE_WIDTH;
        const widths = COLUMNS.map((column) => Math.floor(column.initialWidth * scale));
        const used = widths.reduce((sum, width) => sum + width, 0);
        widths[widths.length - 1] += available - used;

        const key = widths.join(',');
        if (key === this._appliedWidthKey) {
            return;
        }

        this._appliedWidthKey = key;
        this.columns = COLUMNS.map((column, index) => ({
            ...column,
            initialWidth: widths[index]
        }));
    }

    loadData() {
        this.isLoading = true;
        getSalesOrders({ pageSize: this.pageSize, pageNumber: this.pageNumber })
            .then(result => {
                this.totalRecords = result.totalRecords || 0;
                this.rows = (result.records || []).map(r => ({
                    ...r,
                    recordUrl: '/' + r.Id,
                    opportunityName: r.Opportunity__r ? r.Opportunity__r.Name : '',
                    opportunityUrl: r.Opportunity__c ? '/' + r.Opportunity__c : '',
                    ownerName: r.Owner ? r.Owner.Name : '',
                    createdByName: r.CreatedBy ? r.CreatedBy.Name : ''
                }));

                // Retain current sorting on new page data
                if (this.sortedBy) {
                    this.sortData(this.sortedBy, this.sortedDirection);
                }
            })
            .catch(error => {
                this.toast('Error', error?.body?.message || 'Something went wrong', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleBackToHome() {
        const isCommunity = window.location.pathname.startsWith('/s/') || window.location.pathname.includes('/s');
        const isMobileOrTablet = window.innerWidth <= 1024 || /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
        if (isMobileOrTablet) {
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: {
                    apiName: 'Home'
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'home'
                }
            });
        }
        /*  if (isCommunity) {
             this[NavigationMixin.Navigate]({
                 type: 'standard__namedPage',
                 attributes: {
                     pageName: 'home'
                 }
             });
         } else {
             this[NavigationMixin.Navigate]({
                 type: 'standard__namedPage',
                 attributes: {
                     pageName: 'home'
                 }
             });
         } */
    }

    // ---------- Sorting Logic ----------
    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortedDirection);
    }

    sortData(fieldname, direction) {
        let sortField = fieldname;
        if (fieldname === 'recordUrl') {
            sortField = 'Name';
        } else if (fieldname === 'opportunityUrl') {
            sortField = 'opportunityName';
        }

        const isReverse = direction === 'desc' ? 1 : -1;
        const parseData = [...this.rows];

        parseData.sort((x, y) => {
            let valX = x[sortField] ? x[sortField] : '';
            let valY = y[sortField] ? y[sortField] : '';

            if (typeof valX === 'string') valX = valX.toLowerCase();
            if (typeof valY === 'string') valY = valY.toLowerCase();

            return isReverse * ((valX > valY) - (valY > valX));
        });

        this.rows = parseData;
    }

    // ---------- Selection Logic ----------
    get currentPageSelected() {
        return this.rows.filter(r => this.selectedSet.has(r.Id)).map(r => r.Id);
    }

    get selectedIds() {
        return Array.from(this.selectedSet);
    }

    get selectedCountBadge() {
        return `${this.selectedSet.size} Selected`;
    }

    handleRowSelection(event) {
        const selectedOnPage = new Set(event.detail.selectedRows.map(r => r.Id));
        this.rows.forEach(r => {
            if (selectedOnPage.has(r.Id)) {
                this.selectedSet.add(r.Id);
            } else {
                this.selectedSet.delete(r.Id);
            }
        });
        this.selectedSet = new Set(this.selectedSet);
    }

    // ---------- Pagination Logic ----------
    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }

    get isFirst() {
        return this.pageNumber <= 1;
    }

    get isLast() {
        return this.pageNumber >= this.totalPages;
    }

    get pageSizeStr() {
        return String(this.pageSize);
    }

    handleFirst() { this.goTo(1); }
    handlePrev() { this.goTo(this.pageNumber - 1); }
    handleNext() { this.goTo(this.pageNumber + 1); }
    handleLast() { this.goTo(this.totalPages); }

    goTo(page) {
        this.pageNumber = page;
        this.loadData();
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value, 10);
        this.pageNumber = 1;
        this.loadData();
    }

    // ---------- Validation & Next Step ----------
    handleProcessChallan() {
        if (!this.selectedSet || this.selectedSet.size === 0) {
            this.toast('Required Error', 'Please select at least one Sales Order to process Challan.', 'error');
            return;
        }
        this.showChallan = true;
    }

    handleBack() {
        this.showChallan = false;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}