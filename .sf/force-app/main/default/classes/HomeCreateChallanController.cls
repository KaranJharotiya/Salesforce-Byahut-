public with sharing class HomeCreateChallanController {

    public class PageResult {
        @AuraEnabled public List<Sales_Order__c> records;
        @AuraEnabled public Integer totalRecords;
    }

    @AuraEnabled
    public static PageResult getSalesOrders(Integer pageSize, Integer pageNumber) {
        Integer size   = (pageSize == null || pageSize < 1) ? 10 : pageSize;
        Integer pageNo = (pageNumber == null || pageNumber < 1) ? 1 : pageNumber;
        Integer offset = (pageNo - 1) * size;   // SOQL OFFSET max = 2000

        PageResult res = new PageResult();
        res.totalRecords = [SELECT COUNT() FROM Sales_Order__c WHERE Status__c = 'New'];
        res.records = [
            SELECT Id, Name, Status__c, Sales_Order_Date__c, CreatedDate,
            Opportunity__c, Opportunity__r.Name, 
            OwnerId, Owner.Name, 
            CreatedById, CreatedBy.Name
            FROM Sales_Order__c
            WHERE Status__c = 'New'
            ORDER BY CreatedDate DESC
            LIMIT :size OFFSET :offset
        ];
        return res;
    }
}