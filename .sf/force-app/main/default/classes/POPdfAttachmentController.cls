public with sharing class POPdfAttachmentController {
    
    @AuraEnabled
    public static void attachPdfToRecord(Id recordId) {
        try {
            
			Purchase_Order__c purhaseOrder = [SELECT Id,Name FROM Purchase_Order__c WHERE Id =:recordId LIMIT 1];
            // 2. Date format define karein (e.g., 21-09-2026 ya 21-Sep-2026)
            String formattedDate = DateTime.now().format('dd-MM-yyyy_hh-mm-a');

            // 3. Visualforce Page se PDF generate karein
            PageReference pdfPage = Page.PoPdfVf;
            pdfPage.getParameters().put('id', recordId);
            
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF Content');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            // 4. File ka Naam: PO Name + Formatted Date
            String fileName = purhaseOrder.Name + '_' + formattedDate;

            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName + '.pdf';
            cv.VersionData = pdfBlob;
            cv.IsMajorVersion = true;
            insert cv;
            
            Id contentDocId = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :cv.Id 
                LIMIT 1
            ].ContentDocumentId;
            
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;
            
        } catch (Exception ex) {
            throw new AuraHandledException('PDF attach karne me error: ' + ex.getMessage());
        }
    }
}