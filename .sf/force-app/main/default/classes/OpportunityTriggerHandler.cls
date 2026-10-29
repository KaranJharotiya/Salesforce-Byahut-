public class OpportunityTriggerHandler extends Trigger_Handler_Utilities {
    
    public override void beforeInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            OpportunityTriggerHandlerHalper.assignDefaultBank(n, sot, params, debug);
        }
    
    
    public override void beforeUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            
            OpportunityTriggerHandlerHalper.assignApprover(
                (List<Opportunity__c>) n,
                (Map<Id, Opportunity__c>) oMap,
                sot,
                debug
            );
            OpportunityTriggerHandlerHalper.assignDefaultBank(n, sot, params, debug);
        }
    
    public override void beforeDelete(
        List<SObject> n, Map<Id, SObject> nldMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            
        }
    
    public override void afterInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            
        }
    
    public override void afterUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            /*
            OpportunityTriggerHandlerHalper.generateSalesOrderPdf(
                (List<Opportunity__c>) n,
                (Map<Id, Opportunity__c>) oMap,
                sot,
                debug
            );
            
            */
            
            
        }
    
    public override void afterDelete(
        List<SObject> n, Map<Id, SObject> nldMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            
        }
}