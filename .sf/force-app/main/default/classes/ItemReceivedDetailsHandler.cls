public class ItemReceivedDetailsHandler extends Trigger_Handler_Utilities {
    
    public override void beforeInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            ItemReceivedDetailsHelper.validateReceivedQuantity((List<Item_Received_Details__c>) n, (Map<Id, Item_Received_Details__c>) oMap);
        }

    public override void beforeUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            ItemReceivedDetailsHelper.validateReceivedQuantity((List<Item_Received_Details__c>) n, (Map<Id, Item_Received_Details__c>) oMap);
        }
    
    public override void beforeDelete(
        List<SObject> n, Map<Id, SObject> nldMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            ItemReceivedDetailsHelper.manageProductQuantity((List<Item_Received_Details__c>) o, (Map<Id, Item_Received_Details__c>) oMap, 'BEFORE_DELETE');
        }
    
    public override void afterInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            ItemReceivedDetailsHelper.manageProductQuantity((List<Item_Received_Details__c>) n, (Map<Id, Item_Received_Details__c>) oMap, 'AFTER_INSERT'); 
        }
    
    public override void afterUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            ItemReceivedDetailsHelper.manageProductQuantity((List<Item_Received_Details__c>) n, (Map<Id, Item_Received_Details__c>) oMap, 'AFTER_UPDATE');
        }
    
    public override void afterDelete(
        List<SObject> n, Map<Id, SObject> nldMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            
        }
    
}