trigger PO_Trigger on Purchase_Order__c (before insert, before update, before delete, after insert, after update, after delete) {
    Trigger_Handler_Utilities.handleEvent(
        'Purchase_Order__c',
        Trigger.operationType,
        Trigger.size,
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap
    );
}