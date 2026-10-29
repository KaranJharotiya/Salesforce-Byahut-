public class PO_Trigger_Helper {
    
    public static void poGenerationAlert(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap,Schema.SObjectType sot, String params, Boolean debug){
        SendEmail.sendEmail(new List<String>{'karan@ibirdsservices.com'}, 'PO Generation', 'Hello Dear, \n\n New PO has been generated.');
    }
    
    
    public static void notifyToOperation(
        List<SObject> n,
        Map<Id, SObject> nMap,
        List<SObject> o,
        Map<Id, SObject> oMap,
        Schema.SObjectType sot,
        String params,
        Boolean debug
    ) {
        if (n == null || n.isEmpty()) {
            return;
        }
        
        if (sot != Purchase_Order__c.SObjectType) {
            return;
        }
        
        Set<Id> poIds = new Set<Id>();
        
        for (SObject sob : n) {
            Purchase_Order__c newPO = (Purchase_Order__c) sob;
            
            Purchase_Order__c oldPO =
                oMap != null && oMap.containsKey(newPO.Id)
                ? (Purchase_Order__c) oMap.get(newPO.Id)
                : null;
            
            if (newPO.Status__c == 'Fully Received' &&
                (oldPO == null || oldPO.Status__c != 'Fully Received')) {
                    poIds.add(newPO.Id);
                }
        }
        
        if (poIds.isEmpty()) {
            return;
        }
        
        // Get Purchase Requests linked to the Purchase Orders
        Set<Id> purchaseRequestIds = new Set<Id>();
        
        for (Purchase_Order__c po : [
            SELECT Id, Purchase_Request__c
            FROM Purchase_Order__c
            WHERE Id IN :poIds
            AND Purchase_Request__c != null
        ]) {
            purchaseRequestIds.add(po.Purchase_Request__c);
        }
        
        if (purchaseRequestIds.isEmpty()) {
            return;
        }
        
        // Check Challan on the parent Purchase Request
        Set<Id> challanIds = new Set<Id>();
        
        for (Purchase_Request__c pr : [
            SELECT Id, Challan__c
            FROM Purchase_Request__c
            WHERE Id IN :purchaseRequestIds
            AND Challan__c != null
        ]) {
            challanIds.add(pr.Challan__c);
        }
        
        if (challanIds.isEmpty()) {
            return;
        }
        
        List<Group> operationQueues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = 'Operations_Queues'
            LIMIT 1
        ];
        
        if (operationQueues.isEmpty()) {
            return;
        }
        
        List<CustomNotificationType> notificationTypes = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName =
            'Notify_To_Operation_for_Create_Sales_Order'
            LIMIT 1
        ];
        
        if (notificationTypes.isEmpty()) {
            return;
        }
        
        for (Id challanId : challanIds) {
            Messaging.CustomNotification notification =
                new Messaging.CustomNotification();
            
            notification.setTitle('Purchase Order Fully Received');
            notification.setBody(
                'This Challan Linked Purchase Order is fully received. ' +
                'You can now create another Sales Order to proceed with the sales process.'
            );
            
            notification.setNotificationTypeId(notificationTypes[0].Id);
            notification.setTargetId(challanId);
            
            notification.send(
                new Set<String>{
                    String.valueOf(operationQueues[0].Id)
                        }
            );
        }
    }
    
    
    
}