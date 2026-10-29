public class AssignReocrdToUserCmpController {
    
    @AuraEnabled
    public static Id updateRecordOwner(String selectedUserId, String recordId) {
        String objectType = '';
        String sObjectName = ((Id) recordId).getSObjectType().getDescribe().getName();
        if (sObjectName == 'Lead__c' || sObjectName == 'Lead') {
            objectType = 'Lead';
            Lead__c leadRec = [SELECT Id, OwnerId FROM Lead__c WHERE Id = :recordId LIMIT 1];
            leadRec.OwnerId = selectedUserId;
            update leadRec;
        } else if (sObjectName == 'Opportunity__c' || sObjectName == 'Opportunity') {
            objectType = 'Opportunity';
            Opportunity__c oppRec = [SELECT Id, OwnerId FROM Opportunity__c WHERE Id = :recordId LIMIT 1];
            oppRec.OwnerId = selectedUserId;
            update oppRec;
        }
        
        // Task Create
        Task t = new Task();
        t.Subject = objectType + ' Assignment - Action Required';
        t.OwnerId = selectedUserId;
        t.WhatId = recordId;
        t.Description = 'A ' + objectType + ' record has been assigned to you. Please review and take necessary action.';
        insert t;
        
        // Custom Notification
        List<CustomNotificationType> cnTypes = [
            SELECT Id FROM CustomNotificationType 
            WHERE DeveloperName = 'Lead_Or_Opportunity_Assignment' 
            LIMIT 1
        ];
        
        if (!cnTypes.isEmpty()) {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(objectType + ' Assigned: Action Required');
            notification.setBody('You have been assigned a new ' + objectType + '. Please take prompt action.');
            notification.setNotificationTypeId(cnTypes[0].Id);
            notification.setSenderId(UserInfo.getUserId());
            notification.setTargetId(recordId);
            
            notification.send(new Set<String>{ selectedUserId });
        }
        
        return t.Id;
    }
}