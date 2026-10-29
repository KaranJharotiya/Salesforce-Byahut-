public interface Trigger_Handler_Interface {
    void beforeInsert(List<SObject> n, Map<Id, SObject> nldMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params, Boolean debug);
    void beforeUpdate(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params,Boolean debug);
    void beforeDelete(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params,Boolean debug);
    void afterInsert(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params,Boolean debug);
    void afterUpdate(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params,Boolean debug);
    void afterDelete(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params,Boolean debug);
    void afterUndelete(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params,Boolean debug);   
}