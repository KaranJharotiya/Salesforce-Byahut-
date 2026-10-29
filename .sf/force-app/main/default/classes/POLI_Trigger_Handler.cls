public class POLI_Trigger_Handler extends Trigger_Handler_Utilities {
    
    public override void beforeUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            
           // POLI_Trigger_Helper.putReceivedDate(n, nMap, o, oMap, sot, params, debug);
        }
    
    public override void afterUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            
          //  POLI_Trigger_Helper.completePO(n, nMap, o, oMap, sot, params, debug);
           // POLI_Trigger_Helper.updateProQuantityAndPO(n, nMap, o, oMap, sot, params, debug);
            POLI_Trigger_Helper.updatePOStatusIfAllOrderReceived(n, nMap, o, oMap, sot, params, debug);
        }
    
    
}