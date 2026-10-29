import { LightningElement, api } from 'lwc';

const RECORD_LINK_COLUMN = {
    fieldName: 'recordUrl',
    type: 'url',
    initialWidth: 150,
    typeAttributes: { label: { fieldName: 'orderNumber' }, target: '_self' }
};

const BASE_COLUMNS = [
    { ...RECORD_LINK_COLUMN, label: 'Order #' },
    { label: 'Order Date', fieldName: 'orderDate', type: 'date', initialWidth: 200, typeAttributes: { year: "numeric", month: "long", day: "2-digit", hour: "2-digit", minute: "2-digit" } },
    { label: 'Amount', fieldName: 'amount', type: 'currency', initialWidth: 130 },
    { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 140 }
];

const CHALLAN_COLUMNS = [
    { ...RECORD_LINK_COLUMN, label: 'Challan #' },
    { label: 'Challan Date', fieldName: 'orderDate', type: 'date', initialWidth: 200, typeAttributes: { year: "numeric", month: "long", day: "2-digit", hour: "2-digit", minute: "2-digit" } },
    { label: 'Total Items', fieldName: 'totalItems', type: 'text', initialWidth: 130 },
    { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 140 }
];

const QUOTATION_COLUMNS = [
    { ...RECORD_LINK_COLUMN, label: 'Quotation #' },
    { label: 'Quotation Date', fieldName: 'orderDate', type: 'date', initialWidth: 200, typeAttributes: { year: "numeric", month: "long", day: "2-digit", hour: "2-digit", minute: "2-digit" } },
    { label: 'Amount', fieldName: 'amount', type: 'currency', initialWidth: 130 },
    { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 140 }
];

const DELIVERY_DETAILS_COLUMNS = [
    { ...RECORD_LINK_COLUMN, label: 'DN #' },
    { label: 'Expected Delivery Date', fieldName: 'expectedDeliveryDate', type: 'date', initialWidth: 180, typeAttributes: { year: "numeric", month: "long", day: "2-digit" } },
    { label: 'Delivery Date', fieldName: 'deliveryDate', type: 'date', initialWidth: 180, typeAttributes: { year: "numeric", month: "long", day: "2-digit" } },
    { label: 'Total Items', fieldName: 'amount', type: 'text', initialWidth: 130 },
    { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 140 }
];

const DATE_TYPE_ATTRIBUTES = { year: "numeric", month: "long", day: "2-digit", hour: "2-digit", minute: "2-digit" };

const PURCHASE_REQUEST_COLUMNS = [
    { ...RECORD_LINK_COLUMN, label: 'PR #' },
    { label: 'Created Date', fieldName: 'orderDate', type: 'date', initialWidth: 200, typeAttributes: DATE_TYPE_ATTRIBUTES },
    { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 180 }
];

const PURCHASE_ORDER_COLUMNS = [
    { ...RECORD_LINK_COLUMN, label: 'PO #' },
    { label: 'Created Date', fieldName: 'orderDate', type: 'date', initialWidth: 200, typeAttributes: DATE_TYPE_ATTRIBUTES },
    { label: 'Amount', fieldName: 'amount', type: 'currency', initialWidth: 130 },
    { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 160 }
];

const VENDOR_RATE_COLUMNS = [
    { ...RECORD_LINK_COLUMN, label: 'Rate #' },
    { label: 'Created Date', fieldName: 'orderDate', type: 'date', initialWidth: 200, typeAttributes: DATE_TYPE_ATTRIBUTES },
    { label: 'Amount', fieldName: 'amount', type: 'currency', initialWidth: 130 },
    { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 140 }
];

const COLUMNS_BY_MODULE = {
    SalesOrder: BASE_COLUMNS,
    Quotation: QUOTATION_COLUMNS,
    DeliveryDetail: DELIVERY_DETAILS_COLUMNS,
    PurchaseRequest: PURCHASE_REQUEST_COLUMNS,
    PurchaseOrder: PURCHASE_ORDER_COLUMNS,
    ItemVendorRate: VENDOR_RATE_COLUMNS
};

const OWNER_COLUMN = { label: 'Owner', fieldName: 'ownerName', type: 'text', initialWidth: 160 };

// Scrollbar buffer only (checkbox column is hidden).
const NON_DATA_COLUMN_WIDTH = 40;

export default class SalesOrderList extends LightningElement {
    @api orders = [];
    @api statusSteps = [];
    @api showOwnerColumn = false;
    @api moduleKey = '';
    @api moduleLabel = '';
    @api selectedUserTitle;
    @api isCommunity;
    selectedStatus;

    columns = [];
    _baseColumns = [];
    _baseColumnsKey;
    _appliedWidthKey;
    _tableResizeObserver;
    _observedContainer;

    renderedCallback() {
        this.syncBaseColumnsIfNeeded();
        this.observeTableContainer();
        this.fitColumnsToContainer();
    }

    disconnectedCallback() {
        if (this._tableResizeObserver) {
            this._tableResizeObserver.disconnect();
            this._tableResizeObserver = null;
        }
    }

    getBaseColumns() {
        const columnsSet = COLUMNS_BY_MODULE[this.moduleKey] || CHALLAN_COLUMNS;
        return this.showOwnerColumn ? [...columnsSet, OWNER_COLUMN] : [...columnsSet];
    }

    syncBaseColumnsIfNeeded() {
        const base = this.getBaseColumns();
        const key = `${this.moduleKey}|${!!this.showOwnerColumn}|${base.map((c) => c.initialWidth).join(',')}`;
        if (key === this._baseColumnsKey) {
            return;
        }
        this._baseColumnsKey = key;
        this._baseColumns = base;
        this._appliedWidthKey = null;
        this.columns = base;
    }

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
        const base = this._baseColumns;
        if (!container || !base.length) {
            return;
        }

        const available = container.clientWidth - NON_DATA_COLUMN_WIDTH;
        if (available < 200) {
            return;
        }

        const baseWidth = base.reduce((sum, column) => sum + column.initialWidth, 0);
        const originalKey = base.map((column) => column.initialWidth).join(',');

        // Narrow / mobile: keep base widths so the table scrolls horizontally
        // instead of crushing columns.
        if (available <= baseWidth) {
            if (this._appliedWidthKey !== originalKey) {
                this._appliedWidthKey = originalKey;
                this.columns = base;
            }
            return;
        }

        const scale = available / baseWidth;
        const widths = base.map((column) => Math.floor(column.initialWidth * scale));
        const used = widths.reduce((sum, width) => sum + width, 0);
        widths[widths.length - 1] += available - used;

        const key = widths.join(',');
        if (key === this._appliedWidthKey) {
            return;
        }

        this._appliedWidthKey = key;
        this.columns = base.map((column, index) => ({
            ...column,
            initialWidth: widths[index]
        }));
    }

    get hasOrders() {
        return this.filteredOrders && this.filteredOrders.length > 0;
    }

    get hasActiveFilter() {
        return !!this.selectedStatus;
    }

    get filterBadgeLabel() {
        return `Showing: ${this.selectedStatus}`;
    }

    get filteredOrders() {
        const source = this.selectedStatus
            ? this.orders.filter((o) => o.status === this.selectedStatus)
            : this.orders;
        // lightning-datatable's 'url' column type needs the href on the row itself;
        // record Ids resolve to the correct detail page regardless of object type.
        return source.map((o) => ({
            ...o,
            recordUrl: this.isCommunity ? `/s/detail/${o.id}` : `/${o.id}`
        }));
    }

    // One progress bar per status: how many of this user's/team's orders
    // are currently sitting in that status, as a percentage of the total.
    get statusSummary() {
        const total = this.orders.length;
        return this.statusSteps.map((status) => {
            const count = this.orders.filter((o) => o.status === status).length;
            const percent = total === 0 ? 0 : Math.round((count / total) * 100);
            const isActive = status === this.selectedStatus;
            return {
                status,
                percent,
                countLabel: `${count} ${this.moduleLabel.substr(0, this.moduleLabel.length - 1)}${count === 1 ? '' : 's'} (${percent}%)`,
                rowClass:
                    'slds-var-p-bottom_small slds-var-p-around_x-small slds-is-clickable' +
                    (isActive ? ' slds-theme_shade slds-theme_alert-texture' : '')
            };
        });
    }

    get cardTitle() {
        return `${this.moduleLabel} By Status${this.selectedUserTitle ? ` (${this.selectedUserTitle})` : ''}`
    }

    handleStatusClick(event) {
        const status = event.currentTarget.dataset.status;
        this.selectedStatus = this.selectedStatus === status ? undefined : status;
    }

    clearFilter() {
        this.selectedStatus = undefined;
    }
}