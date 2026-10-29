public class OpportunityTriggerHandlerHalper {
    
    public static void assignDefaultBank(
        List<SObject> n,
        Schema.SObjectType sot, 
        String params, 
        Boolean debug
    ){
        List<Bank_Detail__c> defaultBank = [Select Id from Bank_Detail__c Where Is_Default__c = true limit 1];
        for(SObject obj : n){
            if(obj.get('Bank__c') == null && !defaultBank.isEmpty()){
                obj.put('Bank__c', defaultBank[0].Id);
            }
        }
    }
    /*
    
    public static void generateSalesOrderPdf(List<Opportunity__c> n, Map<Id, Opportunity__c> oMap, Schema.SObjectType sot, Boolean debug){
        
        for(Opportunity__c opp : n){
            if(opp.Status__c == 'Sales Order' && opp.Status__c != oMap.get(opp.Id).Status__c){
                
                Id networkId = Network.getNetworkId();
                saveSalesOrderPdf(opp.Id, opp.Name, networkId);
                
                
                
            }
        }
    }
    */
    public static void assignApprover(List<Opportunity__c> n, Map<Id, Opportunity__c> oMap, Schema.SObjectType sot, Boolean debug){
        
        for(Opportunity__c opp : n){
            if(opp.Approval_Status__c == 'Approved' && opp.Approval_Status__c != oMap.get(opp.Id).Approval_Status__c){
                opp.Approved_By__c = UserInfo.getUserId();
            } else if(opp.Approval_Status__c == 'Rejected' && opp.Approval_Status__c != oMap.get(opp.Id).Approval_Status__c){
                opp.Rejected_By__c = UserInfo.getUserId();
            }
        }
    }
    
 /*
    @future(callout=true)
    private static void saveSalesOrderPdf(String oppId, String oppName, Id networkId){
        
        PageReference pdfPage = Page.QuotationPdf;
        pdfPage.getParameters().put('id', oppId);
        
        Blob pdfBlob;
        
        if(!Test.isRunningTest()){
            pdfBlob = pdfPage.getContentAsPDF();
        }else{
            pdfBlob = Blob.valueOf('Test PDF Content');
        }
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = oppName + '_Sales_Order';
        contentVersion.PathOnClient = oppName + '_Sales_Order.pdf';
        contentVersion.VersionData = pdfBlob;
        contentVersion.NetworkId = networkId;
        contentVersion.FirstPublishLocationId = oppId;
        
        if(!Test.isRunningTest()){
            insert contentVersion;
        }
        
        
        List<ContentDocumentLink> cdlList = [
            SELECT Id, Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :oppId
            AND ContentDocumentId = :contentVersion.ContentDocumentId
        ];
        
        for(ContentDocumentLink cdl : cdlList){
            cdl.Visibility = 'AllUsers';
        }
        
        update cdlList;
    }

*/
}