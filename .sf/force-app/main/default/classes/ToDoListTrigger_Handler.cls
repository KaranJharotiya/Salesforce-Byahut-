public without sharing class ToDoListTrigger_Handler extends Trigger_Handler_Utilities {
    
    public override void beforeInsert(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params, Boolean debug) {
        
        ToDoListTrigger_Halper.checkRecordAllreadyCreatedOrNot(n);
    }
    
    public override void beforeUpdate(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params, Boolean debug) {
        
        ToDoListTrigger_Halper.updateToDoRecord((List<To_Do_List__c>)n);
    }
    
}