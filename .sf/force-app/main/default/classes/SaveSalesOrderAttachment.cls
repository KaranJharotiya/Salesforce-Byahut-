public class SaveSalesOrderAttachment {
    
    @AuraEnabled
    public static void saveVFAsFile(Id recordId, Id salesOrderId) {
        
        PageReference pageRef = Page.salesOrderQuotationPdf;
        System.debug('pageRef' + pageRef);
        pageRef.getParameters().put('id', recordId);
        pageRef.getParameters().put('salesOrderId', salesOrderId);
        Blob fileBody;
        try {
            if (!Test.isRunningTest()) {
                fileBody = pageRef.getContent();
            } else {
                fileBody = Blob.valueOf('Test File');
            }
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
            System.debug('STACK: ' + e.getStackTraceString());
            throw new AuraHandledException('File generation failed.');
        }
        
        // File Name Sales Order ke Name ke according dynamic set kiya gaya hai
        String fileName = 'SalesOrder';
        if (salesOrderId != null) {
            List<Sales_Order__c> soList = [SELECT Id, Name FROM Sales_Order__c WHERE Id = :salesOrderId LIMIT 1];
            if (!soList.isEmpty() && String.isNotBlank(soList[0].Name)) {
                fileName += ' ' + soList[0].Name;
            }
        }
        
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName + '.pdf';
        cv.VersionData = fileBody;
        insert cv;
        
        Id contentDocId = [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id
        ].ContentDocumentId;
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocId;
        cdl.LinkedEntityId = recordId;
        cdl.ShareType = 'V';
        insert cdl;
        
        ContentDocumentLink cdl1 = new ContentDocumentLink();
        cdl1.ContentDocumentId = contentDocId;
        cdl1.LinkedEntityId = salesOrderId;
        cdl1.ShareType = 'V';
        insert cdl1;
    }
}