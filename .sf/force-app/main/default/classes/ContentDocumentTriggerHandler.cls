public class ContentDocumentTriggerHandler  extends Trigger_Handler_Utilities {
    
    public override void beforeDelete(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug) {
            ContentDocumentTriggerHelper.deletePublicUrlRecord(o, oMap, sot, params, debug);
        }
}