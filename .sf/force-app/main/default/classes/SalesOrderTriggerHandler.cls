public class SalesOrderTriggerHandler extends Trigger_Handler_Utilities {
    
    public override void afterInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            SalesOrderTriggerHelper.assignSalesOrderToCartItem(n, nMap, o, oMap, sot, params, debug);
        }   
}