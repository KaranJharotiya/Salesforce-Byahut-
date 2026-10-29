public virtual class Trigger_Handler_Utilities implements Trigger_Handler_Interface {
    
    public static Map<String, Schema.SObjectType> globalDescribeMap = Schema.getGlobalDescribe();
    
    private static String objName;
    private static Schema.SObjectType sObjType {
        
        get {
            
            return globalDescribeMap.get(objName);
        }
        private set;
    }  
    
    public virtual void beforeInsert(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params, Boolean debug) 
    {
        throw new TriggerHandlerException('A class has subscribed to the beforeInsert event without providing an implementation of the beforeInsert method');
    }
    public virtual void beforeUpdate(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params, Boolean debug)
    {
        throw new TriggerHandlerException('A class has subscribed to the beforeUpdate event without providing an implementation of the beforeUpdate method');
    }
    public virtual void beforeDelete(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params, Boolean debug) 
    {
        throw new TriggerHandlerException('A class has subscribed to the beforeDelete event without providing an implementation of the beforeDelete method');
    }
    public virtual void afterInsert(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params, Boolean debug) 
    {
        throw new TriggerHandlerException('A class has subscribed to the afterInsert event without providing an implementation of the afterInsert method');
    } 
    public virtual void afterUpdate(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params, Boolean debug) 
    {
        throw new TriggerHandlerException('A class has subscribed to the afterUpdate event without providing an implementation of the afterUpdate method');
    } 
    public virtual void afterDelete(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params, Boolean debug) 
    {
        throw new TriggerHandlerException('A class has subscribed to the afterDelete event without providing an implementation of the afterDelete method');
    }
    public virtual void afterUndelete(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, Schema.SObjectType sot, String params, Boolean debug) 
    {
        throw new TriggerHandlerException('A class has subscribed to the afterUndelete event without providing an implementation of the afterUndelete method');
    } 
    
    
    public static void handleEvent(String objAPIName, System.TriggerOperation operationType, Integer size, List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap) {   
        
        //populate static variable with current object API name
        objName = objAPIName;
        
        List<Trigger_Registration__mdt> metadataList = [Select Id, Class_Name__c, Trigger_Parameters__c, Debug__c,
                                                        Before_Insert__c, Before_Update__c, Before_Delete__c,
                                                        After_Insert__c, After_Update__c, After_Delete__c, After_Undelete__c
                                                        From Trigger_Registration__mdt
                                                        Where Object_API_Name__c = :objAPIName 
                                                        and Active__c = true];
        
        if(metadataList.isEmpty() || isTriggerOperationDisabled(metadataList[0] ,operationType)){
            return;
        }
     
        
        Type triggerHandlerClass = Type.forName(metadataList[0].Class_Name__c);
        
        executeTriggerHandler(triggerHandlerClass, metadataList[0], operationType, n, nMap, o, oMap);
    }
    
    public static void executeTriggerHandler(Type triggerHandlerClass, Trigger_Registration__mdt objectMdt, System.TriggerOperation operationType, List<sObject> n, Map<Id, SObject> nMap, List<sObject> o, Map<Id, SObject> oMap) {
        
        Trigger_Handler_Interface triggerHandlerClassInstance = (Trigger_Handler_Interface)triggerHandlerClass.newInstance();
        switch on operationType {
            
            when BEFORE_INSERT { 
                triggerHandlerClassInstance.beforeInsert(n, nMap, o, oMap, sObjType, objectMdt.Trigger_Parameters__c, objectMdt.Debug__c); 
            }
            when BEFORE_UPDATE { 
                triggerHandlerClassInstance.beforeUpdate(n, nMap, o, oMap, sObjType, objectMdt.Trigger_Parameters__c, objectMdt.Debug__c); 
            }
            when BEFORE_DELETE { 
                triggerHandlerClassInstance.beforeDelete(n, nMap, o, oMap, sObjType, objectMdt.Trigger_Parameters__c, objectMdt.Debug__c); 
            }
            when AFTER_INSERT { 
                triggerHandlerClassInstance.afterInsert(n, nMap, o, oMap, sObjType, objectMdt.Trigger_Parameters__c, objectMdt.Debug__c); 
            }
            when AFTER_UPDATE { 
                triggerHandlerClassInstance.afterUpdate(n, nMap, o, oMap, sObjType, objectMdt.Trigger_Parameters__c, objectMdt.Debug__c); 
            }
            when AFTER_DELETE { 
                triggerHandlerClassInstance.afterDelete(n, nMap, o, oMap, sObjType, objectMdt.Trigger_Parameters__c, objectMdt.Debug__c); 
            }
            when AFTER_UNDELETE { 
                triggerHandlerClassInstance.afterUndelete(n, nMap, o, oMap, sObjType, objectMdt.Trigger_Parameters__c, objectMdt.Debug__c); 
            }
        } 
    }

    private static Boolean isTriggerOperationDisabled(Trigger_Registration__mdt objectMdt, System.TriggerOperation operationType) {
        
        return (operationType == System.TriggerOperation.BEFORE_INSERT && !objectMdt.Before_Insert__c ||
                operationType == System.TriggerOperation.BEFORE_UPDATE && !objectMdt.Before_Update__c ||
                operationType == System.TriggerOperation.BEFORE_DELETE && !objectMdt.Before_Delete__c ||
                operationType == System.TriggerOperation.AFTER_INSERT && !objectMdt.After_Insert__c ||
                operationType == System.TriggerOperation.AFTER_UPDATE && !objectMdt.After_Update__c ||
                operationType == System.TriggerOperation.AFTER_DELETE && !objectMdt.After_Delete__c ||
                operationType == System.TriggerOperation.AFTER_UNDELETE && !objectMdt.After_Undelete__c
               );
    }
    
    public class TriggerHandlerException extends Exception {}
}