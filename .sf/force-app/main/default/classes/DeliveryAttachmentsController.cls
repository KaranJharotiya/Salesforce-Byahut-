public with sharing class DeliveryAttachmentsController {

    public class FileWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String fileType { get; set; }
        @AuraEnabled public String category { get; set; }
    }

    public class PendingFileWrapper {
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String base64Data { get; set; }
        @AuraEnabled public String category { get; set; }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, List<FileWrapper>> getCategorizedAttachments(Id recordId) {
        Map<String, List<FileWrapper>> result = new Map<String, List<FileWrapper>>{
            'Docket Copy' => new List<FileWrapper>(),
            'Transporter POD' => new List<FileWrapper>(),
            'Customer POD' => new List<FileWrapper>()
        };

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }

        if (docIds.isEmpty()) return result;

        for (ContentVersion cv : [
            SELECT ContentDocumentId, Title, FileExtension, Description 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :docIds AND IsLatest = true
        ]) {
            FileWrapper fw = new FileWrapper();
            fw.id = cv.ContentDocumentId;
            fw.title = cv.Title + '.' + cv.FileExtension;
            fw.fileType = cv.FileExtension;
            fw.category = cv.Description;

            if (result.containsKey(cv.Description)) {
                result.get(cv.Description).add(fw);
            }
        }
        return result;
    }

    @AuraEnabled
    public static void saveAllAttachments(Id recordId, String filesJson) {
        if (String.isBlank(filesJson)) return;

        List<PendingFileWrapper> filesToUpload = (List<PendingFileWrapper>) JSON.deserialize(filesJson, List<PendingFileWrapper>.class);
        if (filesToUpload.isEmpty()) return;

        List<ContentVersion> cvList = new List<ContentVersion>();
        for (PendingFileWrapper file : filesToUpload) {
            ContentVersion cv = new ContentVersion();
            cv.Title = file.fileName;
            cv.PathOnClient = file.fileName;
            cv.VersionData = EncodingUtil.base64Decode(file.base64Data);
            cv.Description = file.category; 
            cv.FirstPublishLocationId = recordId; 
            cvList.add(cv);
        }

        insert cvList;
    }

    @AuraEnabled
    public static void deleteAttachment(Id documentId) {
        delete [SELECT Id FROM ContentDocument WHERE Id = :documentId];
    }
}