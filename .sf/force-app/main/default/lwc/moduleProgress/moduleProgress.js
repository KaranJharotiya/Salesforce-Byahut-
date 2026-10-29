import { LightningElement, api, wire } from 'lwc';
import isCurrentUserAdmin from '@salesforce/apex/BusinessProgressController.isCurrentUserAdmin';
import getStatusSteps from '@salesforce/apex/BusinessProgressController.getStatusSteps';
import getMyRecords from '@salesforce/apex/BusinessProgressController.getMyRecords';
import getTeamSummary from '@salesforce/apex/BusinessProgressController.getTeamSummary';
import getRecordsByOwner from '@salesforce/apex/BusinessProgressController.getRecordsByOwner';

const NON_DATA_COLUMN_WIDTH = 40;

export default class ModuleProgress extends LightningElement {
    // Set by the parent (businessProgressHub) for each module it renders.
    @api moduleKey;          // module key from BusinessProgressController
    @api moduleLabel;        // 'Sales Orders' | 'Quotations' | 'Challans'
    @api closedStatusLabel;  // 'Closed' | 'Accepted' | 'Delivered' - used as the team column header
    @api isCommunity;
    isAdmin = false;
    statusSteps = [];
    myRecords = [];
    teamSummary = [];
    teamColumns = [];

    selectedUserRecords = [];
    selectedUserName;

    adminLoaded = false;
    statusStepsLoaded = false;
    myRecordsLoaded = false;

    _baseTeamColumns = [];
    _baseTeamColumnsKey;
    _appliedTeamWidthKey;
    _tableResizeObserver;
    _observedContainer;

    getBaseTeamColumns() {
        return [
            { label: 'Team Member', fieldName: 'userName', type: 'text', initialWidth: 180 },
            { label: 'Total', fieldName: 'totalRecords', type: 'number', initialWidth: 120 },
            { label: this.closedStatusLabel || 'Completed', fieldName: 'closedRecords', type: 'number', initialWidth: 140 },
            { label: 'Completion %', fieldName: 'completionPercent', type: 'percent-fixed', initialWidth: 160 },
            {
                type: 'button',
                initialWidth: 120,
                typeAttributes: {
                    label: 'View',
                    name: 'view_records',
                    variant: 'brand-outline'
                }
            }
        ];
    }

    renderedCallback() {
        this.syncBaseTeamColumnsIfNeeded();
        this.observeTeamTableContainer();
        this.fitTeamColumnsToContainer();
    }

    disconnectedCallback() {
        if (this._tableResizeObserver) {
            this._tableResizeObserver.disconnect();
            this._tableResizeObserver = null;
        }
    }

    syncBaseTeamColumnsIfNeeded() {
        const base = this.getBaseTeamColumns();
        const key = `${this.closedStatusLabel || 'Completed'}|${base.map((c) => c.initialWidth).join(',')}`;
        if (key === this._baseTeamColumnsKey) {
            return;
        }
        this._baseTeamColumnsKey = key;
        this._baseTeamColumns = base;
        this._appliedTeamWidthKey = null;
        this.teamColumns = base;
    }

    observeTeamTableContainer() {
        const container = this.template.querySelector('.team-datatable-container');
        if (!container || this._observedContainer === container) {
            return;
        }
        if (this._tableResizeObserver) {
            this._tableResizeObserver.disconnect();
        }
        this._observedContainer = container;
        this._tableResizeObserver = new ResizeObserver(() => {
            this.fitTeamColumnsToContainer();
        });
        this._tableResizeObserver.observe(container);
    }

    fitTeamColumnsToContainer() {
        const container = this.template.querySelector('.team-datatable-container');
        const base = this._baseTeamColumns;
        if (!container || !base.length) {
            return;
        }

        const available = container.clientWidth - NON_DATA_COLUMN_WIDTH;
        if (available < 200) {
            return;
        }

        const baseWidth = base.reduce((sum, column) => sum + column.initialWidth, 0);
        const originalKey = base.map((column) => column.initialWidth).join(',');

        if (available <= baseWidth) {
            if (this._appliedTeamWidthKey !== originalKey) {
                this._appliedTeamWidthKey = originalKey;
                this.teamColumns = base;
            }
            return;
        }

        const scale = available / baseWidth;
        const widths = base.map((column) => Math.floor(column.initialWidth * scale));
        const used = widths.reduce((sum, width) => sum + width, 0);
        widths[widths.length - 1] += available - used;

        const key = widths.join(',');
        if (key === this._appliedTeamWidthKey) {
            return;
        }

        this._appliedTeamWidthKey = key;
        this.teamColumns = base.map((column, index) => ({
            ...column,
            initialWidth: widths[index]
        }));
    }

    @wire(getStatusSteps, { moduleKey: '$moduleKey' })
    wiredStatusSteps({ data, error }) {
        this.statusStepsLoaded = true;
        if (data) {
            this.statusSteps = data;
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error(`moduleProgress(${this.moduleKey}): unable to load status steps`, error);
        }
    }

    @wire(getMyRecords, { moduleKey: '$moduleKey' })
    wiredMyRecords({ data, error }) {
        this.myRecordsLoaded = true;
        if (data) {
            this.myRecords = data;
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error(`moduleProgress(${this.moduleKey}): unable to load my records`, error);
        }
    }

    @wire(isCurrentUserAdmin)
    wiredIsAdmin({ data, error }) {
        this.adminLoaded = true;
        if (data) {
            this.isAdmin = true;
            this.loadTeamSummary();
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error(`moduleProgress(${this.moduleKey}): unable to check admin status`, error);
        }
    }

    loadTeamSummary() {
        getTeamSummary({ moduleKey: this.moduleKey })
            .then((data) => {
                this.teamSummary = data;
            })
            .catch((error) => {
                // eslint-disable-next-line no-console
                console.error(`moduleProgress(${this.moduleKey}): unable to load team summary`, error);
            });
    }

    handleTeamRowAction(event) {
        const row = event.detail.row;
        this.selectedUserName = row.userName;
        getRecordsByOwner({ moduleKey: this.moduleKey, ownerId: row.userId })
            .then((data) => {
                this.selectedUserRecords = data;
            })
            .catch((error) => {
                // eslint-disable-next-line no-console
                console.error(`moduleProgress(${this.moduleKey}): unable to load records for user`, error);
            });
    }

    get isLoading() {
        return !(this.adminLoaded && this.statusStepsLoaded && this.myRecordsLoaded);
    }

    get cardTitle() {
        return `${this.moduleLabel} Progress`;
    }

    get myTabLabel() {
        return `My ${this.moduleLabel}`;
    }

    get emptyMessage() {
        return `You don't have any ${(this.moduleLabel || '').toLowerCase()} yet.`;
    }

    get hasMyRecords() {
        return this.myRecords && this.myRecords.length > 0;
    }

    get hasSelectedUser() {
        return !!this.selectedUserName;
    }

    get selectedUserTitle() {
        return this.selectedUserName ? `${this.selectedUserName}'s ${this.moduleLabel}` : '';
    }
}