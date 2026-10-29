public class ContentDocumentTriggerHelper {
    
    
    public static void deletePublicUrlRecord(
        List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug){
            
            List<ContentDocument> contentDocumentList = [Select Id, LatestPublishedVersionId From ContentDocument Where Id IN :oMap.keySet()];
            
            Set<Id> contentVersionIdSet = new Set<Id>();
            for(ContentDocument cd : [Select Id, LatestPublishedVersionId From ContentDocument Where Id IN :oMap.keySet()]){
                contentVersionIdSet.add(cd.LatestPublishedVersionId);
            }
            
            if(!contentVersionIdSet.isEmpty()){
                List<Product_Public_Link__c> pplList = [Select Id, IsDefault__c, Ready_to_Delete__c From Product_Public_Link__c Where Content_Version__c IN :contentVersionIdSet];
                for(Product_Public_Link__c ppl : pplList){
                    if(ppl.IsDefault__c == true){
                        
                        break;
                    }
                    ppl.Ready_to_Delete__c = true;
                }
                
                
                if(!pplList.isEmpty()){
                    update pplList;
                    try{
                        delete pplList;
                    }catch(Exception e){
                        throw new AuraHandledException(e.getMessage());
                    }
                    
                }
            }
        }
    
}