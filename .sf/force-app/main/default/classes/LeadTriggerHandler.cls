public without sharing class LeadTriggerHandler extends Trigger_Handler_Utilities {
    
    public override void beforeInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            if(debug == true){
                system.debug('before => n :: '+n);
                system.debug('before => nMap :: '+nMap);
                system.debug('before => o :: '+o);
                system.debug('before => oMap :: '+oMap);
                system.debug('before => sot :: '+sot);
            }
            
            LeadTriggerHandlerHalper.assignDefaultBank(n, sot, params, debug);
            LeadTriggerHandlerHalper.generateLeadId(n, sot, params, debug);
         //   LeadTriggerHandlerHalper.copyShippingIntoBillingAddress((List<Lead__c>) n, (Map<Id, Lead__c>)oMap, sot, params, debug);
            LeadTriggerHandlerHalper.copyBillingAddressIntoShipping((List<Lead__c>) n, (Map<Id, Lead__c>)oMap, sot, params, debug);
            LeadTriggerHandlerHalper.assignDecisionMaker((List<Lead__c>) n, (Map<Id, Lead__c>)oMap, sot, params, debug);
        }
    
 
    public override void beforeUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            if(debug == true){
                      
            }
            LeadTriggerHandlerHalper.assignDefaultBank(n, sot, params, debug);
     //       LeadTriggerHandlerHalper.copyShippingIntoBillingAddress((List<Lead__c>) n, (Map<Id, Lead__c>)oMap, sot, params, debug);
            LeadTriggerHandlerHalper.copyBillingAddressIntoShipping((List<Lead__c>) n, (Map<Id, Lead__c>)oMap, sot, params, debug);
            LeadTriggerHandlerHalper.assignDecisionMaker((List<Lead__c>) n, (Map<Id, Lead__c>)oMap, sot, params, debug);
        }
    
    public override void beforeDelete(
        List<SObject> n, Map<Id, SObject> nldMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            
        }
    
    public override void afterInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            if(debug == true){
     
            }
            
        }
    
    public override void afterUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            if(debug == true){
        
            }
            
        }
    
    public override void afterDelete(
        List<SObject> n, Map<Id, SObject> nldMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
             
        }

}