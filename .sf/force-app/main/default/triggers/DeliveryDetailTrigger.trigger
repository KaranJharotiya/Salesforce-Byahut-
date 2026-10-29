trigger DeliveryDetailTrigger on Delivery_Detail__c (before insert, before update, before delete, after insert, after update, after delete) {
    Trigger_Handler_Utilities.handleEvent(
        'Delivery_Detail__c',
        Trigger.operationType,
        Trigger.size,	
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap
    );
}