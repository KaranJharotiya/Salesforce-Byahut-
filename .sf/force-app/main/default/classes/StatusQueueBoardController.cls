/**
 * StatusQueueBoardController
 * ------------------------------------------------------------------
 * Backend for the statusQueueBoard LWC - a reusable "queue by status"
 * list (Ready for Picker / Ready for Packer / etc.) with an expandable
 * detail view and an optional one-click status advance.
 *
 * Like BusinessProgressController, this is schema-driven: the status
 * field, date field, amount field, and the list of fields shown in the
 * expanded detail view are all resolved from the object's describe, not
 * hardcoded. You configure WHICH object and WHICH status values a given
 * instance of the component shows as properties on the component itself
 * (set in Experience Builder), not in this class - there's exactly one
 * place to set that per column, and it lives where you're already
 * placing the component.
 *
 * Two instances of the same component/class, pointed at different status
 * values, are how the two-column Picker/Packer board works - see the
 * accompanying README for the page layout.
 * ------------------------------------------------------------------
 */
public with sharing class StatusQueueBoardController {

    @AuraEnabled(cacheable=true)
    public static List<RecordSummary> getRecordsByStatus(String objectApiName, String statusValue) {
        Map<String, List<String>> depandendStatuses = new Map<String, List<String>>{'Ready For Picker'=> new List<String>{'Ready For Picker', 'Picking In Progress'}, 'Ready For Packer' => new List<String>{'Ready For Packer', 'Packing In Progress'}};
        
        List<RecordSummary> result = new List<RecordSummary>();
        for(Challan__c challanRec : [SELECT Id, CreatedDate, Name, Status__c, Total_Items__c FROM Challan__c WHERE OwnerId =: UserInfo.getUserId() AND Status__c IN: depandendStatuses.get(statusValue)]){
            RecordSummary rs = new RecordSummary();
            rs.id = challanRec.Id;
            rs.name = challanRec.Name;
            rs.status = challanRec.Status__c;
            rs.recordDate = challanRec.CreatedDate;
            rs.totalItems = challanRec.Total_Items__c;
            result.add(rs);
        }

        return result;
    }

    public class RecordSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime recordDate;
        @AuraEnabled public String totalItems;
    }
}