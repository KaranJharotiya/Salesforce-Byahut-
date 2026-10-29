public class PO_Trigger_Handler extends Trigger_Handler_Utilities {
    
    public override void afterInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            PO_Trigger_Helper.poGenerationAlert(n, nMap, o, oMap, sot, params, debug);
        }
    
    public override void beforeUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            
            PO_Trigger_Helper.notifyToOperation(n, nMap, o, oMap, sot, params, debug);
        }
    
    public override void afterUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
           // PO_Trigger_Helper.sendNotifyToWareHouse(n, nMap, o, oMap, sot, params, debug);
        }
}