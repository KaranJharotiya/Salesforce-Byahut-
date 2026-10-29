trigger AccountTrigger on Account (before insert, before update, after insert, after update) {
    Trigger_Handler_Utilities.handleEvent(
        'Account',
        Trigger.operationType,
        Trigger.size,
        Trigger.new,
        Trigger.newMap,
        Trigger.old,
        Trigger.oldMap
    );
}