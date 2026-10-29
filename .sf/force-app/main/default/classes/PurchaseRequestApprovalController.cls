public with sharing class PurchaseRequestApprovalController {

    @AuraEnabled
    public static void submitPRForApproval(Id purchaseRequestId) {
        try {
            // 1. Fetch Purchase Request Details
            Purchase_Request__c pr = [
                SELECT Id, Name, Status__c, OwnerId 
                FROM Purchase_Request__c 
                WHERE Id = :purchaseRequestId 
                LIMIT 1
            ];

            if (pr.Status__c == 'Pending Approval') {
                AuraHandledException ex = new AuraHandledException('This Purchase Request is already submitted for approval.');
                ex.setMessage('This Purchase Request is already submitted for approval.');
                throw ex;
            }
            if (pr.Status__c == 'Approved' || pr.Status__c == 'PO Generated') {
                AuraHandledException ex = new AuraHandledException('This Purchase Request is already ' + pr.Status__c + '.');
                ex.setMessage('This Purchase Request is already ' + pr.Status__c + '.');
                throw ex;
            }

            // 2. Update Status to 'Pending Approval'
            pr.Status__c = 'Pending Approval';
            update pr;

            // 3. Send Bell / In-App Notification to Admins
            sendBellNotificationToAdmin(pr);

        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            AuraHandledException auraEx = new AuraHandledException(ex.getMessage());
            auraEx.setMessage(ex.getMessage());
            throw auraEx;
        }
    }

    private static void sendBellNotificationToAdmin(Purchase_Request__c pr) {
        try {
            // Fetch any custom notification type present in the org
            List<CustomNotificationType> notifTypes = [
                SELECT Id, DeveloperName 
                FROM CustomNotificationType 
                WHERE DeveloperName = 'PR_Submission_to_Admin' LIMIT 1
            ];

            if (notifTypes.isEmpty()) {
                System.debug('No CustomNotificationType exists in setup.');
                return;
            }

            // Fetch Active Admins (Standard & Custom System Administrator profiles)
            List<User> adminUsers = [
                SELECT Id 
                FROM User 
                WHERE IsActive = true AND Profile.Name = 'System Administrator'
                LIMIT 50
            ];

            Set<String> recipientIds = new Set<String>();
            for (User u : adminUsers) {
                recipientIds.add(u.Id);
            }
            System.debug('recipientIds' + recipientIds);
            if (recipientIds.isEmpty()) {
                return;
            }
            
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Purchase Request Submitted');
            notification.setBody('Purchase Request ' + pr.Name + ' has been submitted for approval. Please take action.');
            notification.setNotificationTypeId(notifTypes[0].Id);
            notification.setTargetId(pr.Id);
            notification.send(recipientIds);

        } catch (Exception notifEx) {
            System.debug('Error sending notification: ' + notifEx.getMessage());
        }
    }
}