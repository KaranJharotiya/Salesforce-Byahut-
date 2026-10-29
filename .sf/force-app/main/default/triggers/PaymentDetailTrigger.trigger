trigger PaymentDetailTrigger on Payment_Details__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    Trigger_Handler_Utilities.handleEvent(
        'Payment_Details__c',
        Trigger.operationType,
        Trigger.size,
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap
    );
}