trigger ContentVersionTrigger on ContentVersion (after insert) {
    
        system.debug('ContentVersion after insert!!');
    
        system.debug('ContentVersion after delete!!');
    
    
    Trigger_Handler_Utilities.handleEvent(
        'ContentVersion',
        Trigger.operationType,
        Trigger.size,
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap
    );
}