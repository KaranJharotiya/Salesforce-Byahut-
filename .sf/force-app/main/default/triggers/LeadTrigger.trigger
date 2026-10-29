trigger LeadTrigger on Lead__c (before insert, before update, before delete, after insert, after update, after delete) {
    Trigger_Handler_Utilities.handleEvent(
        'Lead__c',
        Trigger.operationType,
        Trigger.size,
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap
    );
}