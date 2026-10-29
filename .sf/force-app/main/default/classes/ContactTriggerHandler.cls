public without sharing class ContactTriggerHandler extends Trigger_Handler_Utilities {
    
    public override void beforeInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            if(debug == true){
       
            }
            ContactTriggerHandlerHalper.copyShippingIntoBillingAddress((List<Contact>) n, (Map<Id, Contact>)oMap, sot, params, debug);
            
        }
    
 
    public override void beforeUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            if(debug == true){
                      
            }
            ContactTriggerHandlerHalper.copyShippingIntoBillingAddress((List<Contact>) n, (Map<Id, Contact>)oMap, sot, params, debug);
        }
    /*
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
*/
}