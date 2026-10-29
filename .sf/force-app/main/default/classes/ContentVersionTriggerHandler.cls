public class ContentVersionTriggerHandler extends Trigger_Handler_Utilities {
    
    public override void afterInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            if(debug == true){
     
            }
         ContentVersionTriggerHelper.generatePreviousImagePublicUrl(n, nMap, sot, params, debug);
        }
}