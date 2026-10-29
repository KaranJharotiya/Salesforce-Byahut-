public without sharing class AssignSalesOrderToOpsUserController {
    
    @AuraEnabled
    public static Id assignSalesOrder(String selectedUserId, String recordId) {
        try {

            Sales_Order__c salesOrder = [
                SELECT Id, Name, OwnerId, CreatedBy.Name
                FROM Sales_Order__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            salesOrder.OwnerId = selectedUserId;
            update salesOrder;

            // Task Create
            Task t = new Task();
            t.Subject = 'Sales Order Assignment - Action Required';
            t.OwnerId = selectedUserId;
            t.WhatId = recordId;
            t.Description = 'Sales Order ' + salesOrder.Name + ' has been assigned to you by ' + UserInfo.getName() +
                '. Please review and take necessary action.';
            insert t;

            // Custom Notification
            List<CustomNotificationType> cnTypes = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = 'Sales_Order_Created_Operations_Team'
                LIMIT 1
            ];

            if (!cnTypes.isEmpty()) {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle('Sales Order Assigned: ' + salesOrder.Name);
                notification.setBody(
                    'Sales Order ' + salesOrder.Name + ' created by ' + salesOrder.CreatedBy.Name +
                    ' has been assigned to you by ' + UserInfo.getName() + '. Please take further action.'
                );
                notification.setNotificationTypeId(cnTypes[0].Id);
                notification.setSenderId(UserInfo.getUserId());
                notification.setTargetId(recordId);

                try {
                    notification.send(new Set<String>{ selectedUserId });
                } catch (Exception e) {
                    System.debug('Problem sending Sales Order assignment notification: ' + e.getMessage());
                }
            }

            return t.Id;
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
}