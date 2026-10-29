public class DeliveryDetailTriggerHelper {
    
    public static void refreshCartLineItem(){
        RefreshEvent.publishEvent();
    }

    public static void notifyOwnerOnWarehouseUpdate(List<Delivery_Detail__c> updatedDeliveryDetails) {
        User runningUser = [SELECT Id, Name, Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (runningUser.Profile.Name != 'Warehouse Team') {
            return;
        }

        List<CustomNotificationType> notifTypes = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = 'Challan_Dispatched_Logistics_Manager'
            LIMIT 1
        ];
        if (notifTypes.isEmpty()) {
            return;
        }

        for (Delivery_Detail__c dd : updatedDeliveryDetails) {
            if (dd.OwnerId == null || dd.OwnerId == runningUser.Id) {
                continue;
            }

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Delivery Detail Updated: ' + dd.Name);
            notification.setBody(dd.Name + ' was updated by ' + runningUser.Name + '.');
            notification.setNotificationTypeId(notifTypes[0].Id);
            notification.setTargetId(dd.Id);

            try {
                notification.send(new Set<String>{ String.valueOf(dd.OwnerId) });
            } catch (Exception ex) {
                System.debug('Error sending custom notification: ' + ex.getMessage());
            }
        }
    }

    public static void notifyLogisticsManagerOnDispatch(List<Delivery_Detail__c> newDeliveryDetails) {
        Set<Id> challanIds = new Set<Id>();
        Map<Id, Id> challanIdToDeliveryDetailId = new Map<Id, Id>();
        for (Delivery_Detail__c dd : newDeliveryDetails) {
            if (dd.Challan__c != null) {
                challanIds.add(dd.Challan__c);
                challanIdToDeliveryDetailId.put(dd.Challan__c, dd.Id);
            }
        }
        if (challanIds.isEmpty()) {
            return;
        }

        List<Challan__c> challansToDispatch = [
            SELECT Id, Name, Status__c
            FROM Challan__c
            WHERE Id IN :challanIds AND Status__c != 'Dispatched'
        ];
        if (challansToDispatch.isEmpty()) {
            return;
        }

        for (Challan__c ch : challansToDispatch) {
            ch.Status__c = 'Dispatched';
        }
        update challansToDispatch;

        List<User> logisticsManagers = [
            SELECT Id FROM User
            WHERE Profile.Name = 'Logistics Team Manager' AND IsActive = true
        ];
        List<CustomNotificationType> notifTypes = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = 'Challan_Dispatched_Logistics_Manager'
            LIMIT 1
        ];
        if (logisticsManagers.isEmpty() || notifTypes.isEmpty()) {
            return;
        }

        Set<String> recipientIds = new Set<String>();
        for (User u : logisticsManagers) {
            recipientIds.add(u.Id);
        }

        for (Challan__c ch : challansToDispatch) {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Challan Dispatched: ' + ch.Name);
            notification.setBody('Challan ' + ch.Name + ' has been dispatched and is ready for logistics handling.');
            notification.setNotificationTypeId(notifTypes[0].Id);
            notification.setTargetId(challanIdToDeliveryDetailId.get(ch.Id));

            try {
                notification.send(recipientIds);
            } catch (Exception ex) {
                System.debug('Error sending custom notification: ' + ex.getMessage());
            }
        }
    }
    
    public static void manageProductQuantity(List<Delivery_Detail__c> n, Map<Id,Delivery_Detail__c> oMap, String opType){
        
        Set<Id> challanIds = new Set<Id>();
        for(Delivery_Detail__c dd : n){
            if(dd.Challan__c != null && (opType == 'AFTER_INSERT')){
                challanIds.add(dd.Challan__c);
            }
        }
        if(!challanIds.IsEmpty()){
            List<Cart_Line_Item__c> chllanRelatedSOItems = [
                SELECT Id,Product__c,Product__r.Stock__c,Total_Dispatch_Quantity__c FROM Cart_Line_Item__c 
                WHERE Challan__c IN: challanIds AND Total_Dispatch_Quantity__c != null AND Product__c != null
            ];   
           
            if(!chllanRelatedSOItems.IsEmpty() && opType == 'AFTER_INSERT'){
                List<Product__c> toUpdateProductlst = new List<Product__c>();
                
                for(Cart_Line_Item__c salesOrderItem : chllanRelatedSOItems){
					Product__c toUpdateProductStock = new Product__c(
                    	Id = salesOrderItem.Product__c,
                        Stock__c = salesOrderItem.Product__r.Stock__c -= salesOrderItem.Total_Dispatch_Quantity__c
                    );
                    toUpdateProductlst.add(toUpdateProductStock);
                }
                
                if(!toUpdateProductlst.IsEmpty()){
                    update toUpdateProductlst;
                }
            }
        }       
    }

    public static void createSalesPaymentWhenDelivered(
        List<Delivery_Detail__c> deliveries,
        Map<Id, Delivery_Detail__c> oldMap
    ) {
        if (deliveries == null || deliveries.isEmpty()) {
            return;
        }

        Schema.RecordTypeInfo salesDetailType = Schema.SObjectType.Delivery_Detail__c
            .getRecordTypeInfosByDeveloperName()
            .get('Sales_Detail');
        Schema.RecordTypeInfo salesPaymentType = Schema.SObjectType.Payment_Details__c
            .getRecordTypeInfosByDeveloperName()
            .get('Sales_Payment_Details');
        if (salesDetailType == null || salesPaymentType == null) {
            return;
        }

        Id salesDetailRtId = salesDetailType.getRecordTypeId();
        List<Delivery_Detail__c> delivered = new List<Delivery_Detail__c>();
        Set<Id> challanIds = new Set<Id>();
        for (Delivery_Detail__c delivery : deliveries) {
            if (delivery.RecordTypeId != salesDetailRtId || delivery.Challan__c == null) {
                continue;
            }
            if (delivery.Delivery_Status__c != 'Delivered') {
                continue;
            }
            if (oldMap != null) {
                Delivery_Detail__c previous = oldMap.get(delivery.Id);
                if (previous != null && previous.Delivery_Status__c == 'Delivered') {
                    continue;
                }
            }
            delivered.add(delivery);
            challanIds.add(delivery.Challan__c);
        }
        if (delivered.isEmpty()) {
            return;
        }

        Set<Id> deliveryIds = new Map<Id, Delivery_Detail__c>(delivered).keySet();
        Set<Id> alreadyLinked = new Set<Id>();
        for (Payment_Details__c existing : [
            SELECT Delivery_Detail__c
            FROM Payment_Details__c
            WHERE Delivery_Detail__c IN :deliveryIds
        ]) {
            alreadyLinked.add(existing.Delivery_Detail__c);
        }

        Map<Id, Challan__c> challans = new Map<Id, Challan__c>([
            SELECT Id, Name, Total_Actual_Amount__c
            FROM Challan__c
            WHERE Id IN :challanIds
        ]);

        AccountsTeam accountsTeam = accountsTeam();
        if (accountsTeam.queueId == null || accountsTeam.userIds.isEmpty()) {
            syncChallanDeliveryPaymentStatus(challanIds);
            return;
        }

        List<Payment_Details__c> payments = new List<Payment_Details__c>();
        for (Delivery_Detail__c delivery : delivered) {
            if (alreadyLinked.contains(delivery.Id)) {
                continue;
            }
            Challan__c challan = challans.get(delivery.Challan__c);
            payments.add(new Payment_Details__c(
                RecordTypeId = salesPaymentType.getRecordTypeId(),
                Challan__c = delivery.Challan__c,
                Delivery_Detail__c = delivery.Id,
                Payment_Date__c = Date.today(),
                Payment_Status__c = 'Pending',
                Payment_Type__c = 'Invoice Payment',
                Amount__c = challan == null ? null : challan.Total_Actual_Amount__c,
                OwnerId = accountsTeam.queueId,
                Remarks__c = 'Created when the sales delivery was marked Delivered. Follow up with the customer for payment.'
            ));
        }
        if (!payments.isEmpty()) {
            insert payments;
            notifyAccountsOfDeliveredOrder(payments, challans, accountsTeam.userIds);
        }
        syncChallanDeliveryPaymentStatus(challanIds);
    }

    public static void createPurchasePaymentsForOrders(Set<Id> purchaseOrderIds) {
        if (purchaseOrderIds == null || purchaseOrderIds.isEmpty()) {
            return;
        }

        Schema.RecordTypeInfo purchasePaymentType = Schema.SObjectType.Payment_Details__c
            .getRecordTypeInfosByDeveloperName()
            .get('Purchase_Payment_Details');
        if (purchasePaymentType == null) {
            return;
        }

        Set<Id> alreadyLinked = new Set<Id>();
        for (Payment_Details__c existing : [
            SELECT Purchase_Order__c
            FROM Payment_Details__c
            WHERE Purchase_Order__c IN :purchaseOrderIds
        ]) {
            alreadyLinked.add(existing.Purchase_Order__c);
        }

        Map<Id, Purchase_Order__c> purchaseOrders = new Map<Id, Purchase_Order__c>([
            SELECT Id, Name, Total_Amount__c
            FROM Purchase_Order__c
            WHERE Id IN :purchaseOrderIds
        ]);

        AccountsTeam accountsTeam = accountsTeam();
        if (accountsTeam.queueId == null || accountsTeam.userIds.isEmpty()) {
            return;
        }

        List<Payment_Details__c> payments = new List<Payment_Details__c>();
        for (Purchase_Order__c purchaseOrder : purchaseOrders.values()) {
            if (alreadyLinked.contains(purchaseOrder.Id)) {
                continue;
            }
            payments.add(new Payment_Details__c(
                RecordTypeId = purchasePaymentType.getRecordTypeId(),
                Purchase_Order__c = purchaseOrder.Id,
                Payment_Date__c = Date.today(),
                Payment_Status__c = 'Pending',
                Payment_Type__c = 'Invoice Payment',
                Amount__c = purchaseOrder.Total_Amount__c,
                OwnerId = accountsTeam.queueId,
                Remarks__c = 'Created when the purchase order was generated. Add or update the payment details for the payment made to the vendor.'
            ));
        }
        if (payments.isEmpty()) {
            return;
        }
        insert payments;
        notifyAccountsOfGeneratedPurchaseOrder(payments, purchaseOrders, accountsTeam.userIds);
    }

    public static void syncChallanDeliveryPaymentStatus(Set<Id> challanIds) {
        if (challanIds == null || challanIds.isEmpty()) {
            return;
        }

        Set<Id> deliveredChallanIds = new Set<Id>();
        for (Delivery_Detail__c delivery : [
            SELECT Challan__c
            FROM Delivery_Detail__c
            WHERE Challan__c IN :challanIds
            AND Delivery_Status__c = 'Delivered'
            AND RecordType.DeveloperName = 'Sales_Detail'
        ]) {
            if (delivery.Challan__c != null) {
                deliveredChallanIds.add(delivery.Challan__c);
            }
        }
        if (deliveredChallanIds.isEmpty()) {
            return;
        }

        List<Challan__c> updates = new List<Challan__c>();
        for (Challan__c challan : [
            SELECT Id, Status__c, Pending_Amount__c
            FROM Challan__c
            WHERE Id IN :deliveredChallanIds
        ]) {
            String nextStatus = (challan.Pending_Amount__c == null || challan.Pending_Amount__c <= 0)
                ? 'Delivered/Payment Received'
                : 'Delivered/Payment Pending';
            if (challan.Status__c != nextStatus) {
                updates.add(new Challan__c(
                    Id = challan.Id,
                    Status__c = nextStatus
                ));
            }
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private class AccountsTeam {
        Id queueId;
        Set<String> userIds = new Set<String>();
    }

    private static AccountsTeam accountsTeam() {
        AccountsTeam team = new AccountsTeam();
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName = 'Accounts_Team'
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            return team;
        }
        team.queueId = queues[0].Id;

        Set<Id> memberIds = new Set<Id>();
        for (GroupMember member : [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId = :team.queueId
        ]) {
            if (member.UserOrGroupId != null && member.UserOrGroupId.getSObjectType() == User.SObjectType) {
                memberIds.add(member.UserOrGroupId);
            }
        }
        if (memberIds.isEmpty()) {
            return team;
        }
        for (User accountsUser : [
            SELECT Id
            FROM User
            WHERE Id IN :memberIds AND IsActive = true
        ]) {
            team.userIds.add(accountsUser.Id);
        }
        return team;
    }

    private static void notifyAccountsOfDeliveredOrder(
        List<Payment_Details__c> payments,
        Map<Id, Challan__c> challans,
        Set<String> recipientIds
    ) {
        List<CustomNotificationType> notificationTypes = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Payment_Follow_Up'
            LIMIT 1
        ];
        if (recipientIds.isEmpty() || notificationTypes.isEmpty()) {
            return;
        }

        for (Payment_Details__c payment : payments) {
            Challan__c challan = challans.get(payment.Challan__c);
            String challanName = challan == null ? 'the order' : challan.Name;
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Order delivered: ' + challanName);
            notification.setBody(
                challanName + ' was delivered successfully. Follow up with the customer for payment.'
            );
            notification.setNotificationTypeId(notificationTypes[0].Id);
            notification.setTargetId(payment.Id);
            try {
                notification.send(recipientIds);
            } catch (Exception ex) {
                System.debug('Error sending payment follow-up notification: ' + ex.getMessage());
            }
        }
    }

    private static void notifyAccountsOfGeneratedPurchaseOrder(
        List<Payment_Details__c> payments,
        Map<Id, Purchase_Order__c> purchaseOrders,
        Set<String> recipientIds
    ) {
        List<CustomNotificationType> notificationTypes = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Payment_Follow_Up'
            LIMIT 1
        ];
        if (recipientIds.isEmpty() || notificationTypes.isEmpty()) {
            return;
        }

        for (Payment_Details__c payment : payments) {
            Purchase_Order__c purchaseOrder = purchaseOrders.get(payment.Purchase_Order__c);
            String purchaseOrderName = purchaseOrder == null ? 'the purchase order' : purchaseOrder.Name;
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Purchase order generated: ' + purchaseOrderName);
            notification.setBody(
                purchaseOrderName + ' was generated. This is a purchase from the vendor. Add or update the payment details for the payment made to the vendor.'
            );
            notification.setNotificationTypeId(notificationTypes[0].Id);
            notification.setTargetId(payment.Id);
            try {
                notification.send(recipientIds);
            } catch (Exception ex) {
                System.debug('Error sending purchase payment follow-up notification: ' + ex.getMessage());
            }
        }
    }

    public static void assignPOtoWareHouse(List<Delivery_Detail__c> newDeliveryDetails){
        Set<Id> deliveredPOIds = new Set<Id>();
        for(Delivery_Detail__c deliveryDetail : newDeliveryDetails){
            if(deliveryDetail.Delivery_Status__c == 'Delivered' && deliveryDetail.Purchase_Order__c != null){
                deliveredPOIds.add(deliveryDetail.Purchase_Order__c);
            }
        }
        if(!deliveredPOIds.IsEmpty()){
            List<User> wereHouseTeamUserlst = [SELECT Id FROM User WHERE User_Profile_Name__c = 'Warehouse Team' AND IsActive = true LIMIT 1];
            List<Purchase_Order__c> purchaseOrderLst = [SELECT Id,Name,OwnerId FROM Purchase_Order__c WHERE Id IN :deliveredPOIds];
            if(!wereHouseTeamUserlst.IsEmpty()){
                for(Purchase_Order__c POrder : purchaseOrderLst){
                    POrder.OwnerId = wereHouseTeamUserlst[0].Id;
                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    notification.setTitle('Action Required: Purchase Order Assigned (' + POrder.Name + ')');
                    notification.setBody(
                        'Purchase Order: ' + POrder.Name + 
                        '\n\nThis Purchase Order has been assigned to you as the delivery details have been delivered. ' +
                        'Please review the record and take the necessary next actions.'
                    );
                    notification.setNotificationTypeId(label.PO_AssignTo_WareHouse);
                    notification.setTargetId(POrder.Id);
                    
                    try {
                        notification.send(new Set<String>{ wereHouseTeamUserlst[0].Id });
                    } catch (Exception e) {
                        System.debug('Warehouse Problem sending notification: ' + e.getMessage());
                    }
                }
                if(!purchaseOrderLst.IsEmpty()){
                    update purchaseOrderLst;
                }
            }
            
        }
        
    }
}