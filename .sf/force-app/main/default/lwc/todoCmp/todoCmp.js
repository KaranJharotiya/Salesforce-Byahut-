import { LightningElement, wire, track } from 'lwc';
import getTodayToDoListTask from '@salesforce/apex/ToDoListCmpController.getTodayToDoListTask';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

export default class TodoCmp extends NavigationMixin(LightningElement) {

    @track todayTasklst = [];
    @track recordId;
    wiredTaskResult;

    @wire(getTodayToDoListTask)
    wiredgetTodayToDoListTask(result) {

        this.wiredTaskResult = result;

        const { data, error } = result;

        if (data) {

            this.todayTasklst = data.tasks;
            this.recordId = data.recordId;

            console.log('OUTPUT :getTodayToDoListTask Data ', data);

        } else if (error) {

            console.log('OUTPUT :getTodayToDoListTask Error', error);
        }
    }

    get checkTodayTaskLength() {

        return this.todayTasklst && this.todayTasklst.length > 0;
    }

    handleNewRecord() {

        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'To_Do_List__c',
                actionName: 'new'
            }
        });
    }

    handleRefresh() {

        refreshApex(this.wiredTaskResult);
    }


    handleEditRecord() {

        if (this.todayTasklst && this.todayTasklst.length > 0) {

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'To_Do_List__c',
                    actionName: 'edit'
                }
            });
        }
    }
}