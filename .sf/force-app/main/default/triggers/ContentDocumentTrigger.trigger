trigger ContentDocumentTrigger on ContentDocument (before delete) {
    system.debug('ContentDocumentTrigger ');
    Trigger_Handler_Utilities.handleEvent(
        'ContentDocument',
        Trigger.operationType,
        Trigger.size,
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap
    );
}