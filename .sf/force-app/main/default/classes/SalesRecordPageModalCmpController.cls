// SalesRecordPageModalCmpController.cls
public with sharing class SalesRecordPageModalCmpController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDeliveryData(Id recordId) {

        Map<String, Object> result = new Map<String, Object>();

        Sales_Order__c parentRec = [
            SELECT Id, Delivery_Type__c, Special_Instructions__c
            FROM Sales_Order__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        List<Cart_Line_Item__c> childRecords = [
            SELECT Id,
                   Product__r.Name,
                   Priority__c,
                   Promise_Date__c
            FROM Cart_Line_Item__c
            WHERE Sales_Order__c = :recordId
            ORDER BY Promise_Date__c ASC
        ];

        result.put('deliveryType', parentRec.Delivery_Type__c);
        result.put('specialInstructions', parentRec.Special_Instructions__c);
        result.put('childRecords', childRecords);

        return result;
    }
}