public class DeliveryDetailTriggerHandler extends Trigger_Handler_Utilities {
    
    public override void beforeInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            
        }
     
    public override void beforeUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            DeliveryDetailTriggerHelper.assignPOtoWareHouse((List<Delivery_Detail__c>) n);
        }
    
    public override void beforeDelete(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
          //  DeliveryDetailTriggerHelper.manageProductQuantity((List<Delivery_Detail__c>) O, (Map<Id,Delivery_Detail__c>) oMap, 'BEFORE_DELETE');
        }
    
    public override void afterInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap,
        Schema.SObjectType sot, String params, Boolean debug) {
            DeliveryDetailTriggerHelper.manageProductQuantity((List<Delivery_Detail__c>) n, (Map<Id,Delivery_Detail__c>) oMap, 'AFTER_INSERT');
            DeliveryDetailTriggerHelper.notifyLogisticsManagerOnDispatch((List<Delivery_Detail__c>) n);
            DeliveryDetailTriggerHelper.createSalesPaymentWhenDelivered((List<Delivery_Detail__c>) n, null);
        }
    
    public override void afterUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap,
        Schema.SObjectType sot, String params, Boolean debug) {
           // DeliveryDetailTriggerHelper.manageProductQuantity((List<Delivery_Detail__c>) n, (Map<Id,Delivery_Detail__c>) oMap, 'AFTER_UPDATE');
            DeliveryDetailTriggerHelper.notifyOwnerOnWarehouseUpdate((List<Delivery_Detail__c>) n);
            DeliveryDetailTriggerHelper.createSalesPaymentWhenDelivered(
                (List<Delivery_Detail__c>) n,
                (Map<Id, Delivery_Detail__c>) oMap
            );
        }
    
    public override void afterDelete(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            DeliveryDetailTriggerHelper.refreshCartLineItem();
        }
    
}