public class ContentVersionTriggerHelper {
    
    
    public static void generatePreviousImagePublicUrl(List<SObject> n, Map<Id,SObject> nMap, Schema.SObjectType sot, String params, Boolean debug){
        Set<Id> documentIds = new Set<Id>();
        for(SObject obj : n){
            if((string)obj.get('FileExtension') != 'pdf'){
                documentIds.add((Id)obj.get('ContentDocumentId'));
            }
            
        }
        
        List<ContentDocumentLink> cdlList = [Select Id, LinkedEntityId,  ContentDocumentId, ContentDocument.LatestPublishedVersionId 
                                             From ContentDocumentLink 
                                             Where ContentDocumentId IN :documentIds ORDER BY 
                                             ContentDocument.LatestPublishedVersion.LastModifiedDate ASC];
        
        
        
        system.debug('cdlList >> '+cdlList);
        
        if(cdlList.size()>0){
            
            Map<Id,Id> contentVersionLinkedIdMap = new Map<Id,Id>();
            
            
            
            
            
            for(ContentDocumentLink cdl : cdlList){
                
                
                String objectName = cdl.LinkedEntityId.getSObjectType().getDescribe().getName();
                
                if(objectName == 'Product__c'){
                    contentVersionLinkedIdMap.put(cdl.ContentDocument.LatestPublishedVersionId, cdl.LinkedEntityId);
                }
                
            }
            
            system.debug('contentVersionLinkedIdMap >> '+contentVersionLinkedIdMap);
            
            List<ContentDistribution> distributions = new List<ContentDistribution>();
            for(Id versionId : contentVersionLinkedIdMap.KeySet()){
                distributions.add(new ContentDistribution(
                    Name='Public Link',
                    ContentVersionId=versionId,
                    PreferencesAllowViewInBrowser=true,
                    PreferencesLinkLatestVersion=true,
                    PreferencesAllowOriginalDownload=true
                ));
            }
            
            
            if(distributions.size()>0){
                Insert distributions;
                
                Set<Id> cdIdSet = new Set<Id>();
                for(ContentDistribution cd : distributions){
                    cdIdSet.add(cd.Id);
                }
                
                Map<Id,String> cvUrlMap = new Map<Id,string>();
                for(ContentDistribution cd : [Select Id, ContentVersionId, DistributionPublicUrl From ContentDistribution Where Id IN :cdIdSet]){
                    cvUrlMap.put(cd.ContentVersionId, cd.DistributionPublicUrl);
                }
                
                system.debug('cvUrlMap >> '+cvUrlMap);
                
                List<Product_Public_Link__c> pplList = new List<Product_Public_Link__c>();        
                for(Id contentVersion : contentVersionLinkedIdMap.keySet()){
                    String objectName = contentVersionLinkedIdMap.get(contentVersion).getSObjectType().getDescribe().getName();
                    
                    if(objectName == 'Product__c'){
                        pplList.add(new Product_Public_Link__c(
                            Name = String.valueOf(nMap.get(contentVersion).get('Title')),
                            Content_Version__c = contentVersion, Product__c = contentVersionLinkedIdMap.get(contentVersion),
                            Product_Link__c = cvUrlMap.get(contentVersion)
                        ));                    }
                    
                }
                
                if(!pplList.isEmpty()){
                    system.debug('pplList >> '+pplList);
                    Insert pplList;
                }
                
            }
        }
        
        RefreshEvent.publishEvent();
    
    }
    
}