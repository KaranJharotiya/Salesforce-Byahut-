trigger ProductPublicLinkTrigger on Product_Public_Link__c (before update, before delete) {
    
    Trigger_Handler_Utilities.handleEvent(
        'Product_Public_Link__c',
        Trigger.operationType,
        Trigger.size,
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap
    );
}