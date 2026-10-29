trigger SalesOrderTrigger on Sales_Order__c (after insert) {
    Trigger_Handler_Utilities.handleEvent(
        'Sales_Order__c',
        Trigger.operationType,
        Trigger.size,
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap
    );
}