trigger ToDoListTrigger on To_Do_List__c (before insert, before update, after insert, after update) {
    Trigger_Handler_Utilities.handleEvent(
        'To_Do_List__c',
        Trigger.operationType,
        Trigger.size,
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap
    );
}