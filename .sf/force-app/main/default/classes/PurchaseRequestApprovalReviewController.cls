public class PurchaseRequestApprovalReviewController {
    
    public class ApprovalWrapper {
        @AuraEnabled public Id ivrId { get; set; }
        @AuraEnabled public Id prLineItemId { get; set; }
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public Id vendorMasterId { get; set; }
        @AuraEnabled public String vendorMasterName { get; set; }
        @AuraEnabled public Decimal rate { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal discount { get; set; }
        @AuraEnabled public Decimal gst { get; set; }
        @AuraEnabled public Decimal deliveryCharges { get; set; }
        @AuraEnabled public String commercialTerms { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean isSelected { get; set; }
    }
    
    public class ProductAccordionApprovalWrapper {
        @AuraEnabled public Id prLineItemId { get; set; }
        @AuraEnabled public String prLineItemNumber { get; set; }
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public Decimal requestedQty { get; set; }
        @AuraEnabled public Id selectedVendorMasterId { get; set; }
        @AuraEnabled public List<ApprovalWrapper> vendorRates { get; set; }
    }
    
    @AuraEnabled
    public static List<ProductAccordionApprovalWrapper> getPRLineItemsForApproval(Id purchaseRequestId) {
        try {
            List<ProductAccordionApprovalWrapper> responseList = new List<ProductAccordionApprovalWrapper>();
            
            List<Purchase_Request_Line_Item__c> prLineItems = [
                SELECT Id, Name, Product__c, Product__r.Name, Quantity__c
                FROM Purchase_Request_Line_Item__c
                WHERE Purchase_Request__c = :purchaseRequestId
                ORDER BY Name ASC
            ];
            
            if (prLineItems.isEmpty()) {
                return responseList;
            }
            
            Set<Id> prLineItemIds = new Set<Id>();
            for (Purchase_Request_Line_Item__c prli : prLineItems) {
                prLineItemIds.add(prli.Id);
            }
            
            List<Item_Vendor_Rate__c> ivrList = [
                SELECT Id, Product__c, Product__r.Name, Vendor__c, Vendor__r.Name, 
                Status__c, Discount__c, GST__c, Quantity__c, Rate__c, Purchase_Request_Line_Item__c,
                Delivery_Transportation_Charges__c, Other_Applicable_Commercial_Terms__c 
                FROM Item_Vendor_Rate__c 
                WHERE Purchase_Request_Line_Item__c IN :prLineItemIds
                ORDER BY Vendor__r.Name ASC
            ];
            
            Map<Id, List<Item_Vendor_Rate__c>> lineItemToIVRMap = new Map<Id, List<Item_Vendor_Rate__c>>();
            for (Item_Vendor_Rate__c ivr : ivrList) {
                if (!lineItemToIVRMap.containsKey(ivr.Purchase_Request_Line_Item__c)) {
                    lineItemToIVRMap.put(ivr.Purchase_Request_Line_Item__c, new List<Item_Vendor_Rate__c>());
                }
                lineItemToIVRMap.get(ivr.Purchase_Request_Line_Item__c).add(ivr);
            }
            
            for (Purchase_Request_Line_Item__c prli : prLineItems) {
                ProductAccordionApprovalWrapper pWrap = new ProductAccordionApprovalWrapper();
                pWrap.prLineItemId = prli.Id;
                pWrap.prLineItemNumber = prli.Name;
                pWrap.productId = prli.Product__c;
                pWrap.productName = prli.Product__r != null ? prli.Product__r.Name : 'No Product';
                pWrap.requestedQty = prli.Quantity__c;
                pWrap.vendorRates = new List<ApprovalWrapper>();
                pWrap.selectedVendorMasterId = null;
                
                if (lineItemToIVRMap.containsKey(prli.Id)) {
                    for (Item_Vendor_Rate__c ivr : lineItemToIVRMap.get(prli.Id)) {
                        ApprovalWrapper vWrap = new ApprovalWrapper();
                        vWrap.ivrId = ivr.Id;
                        vWrap.prLineItemId = prli.Id;
                        vWrap.productId = ivr.Product__c;
                        vWrap.productName = ivr.Product__r != null ? ivr.Product__r.Name : '';
                        vWrap.vendorMasterId = ivr.Vendor__c;
                        vWrap.vendorMasterName = ivr.Vendor__r != null ? ivr.Vendor__r.Name : '-';
                        vWrap.rate = ivr.Rate__c;
                        vWrap.quantity = ivr.Quantity__c;
                        vWrap.discount = ivr.Discount__c;
                        vWrap.gst = ivr.GST__c;
                        vWrap.deliveryCharges = ivr.Delivery_Transportation_Charges__c;
                        vWrap.commercialTerms = ivr.Other_Applicable_Commercial_Terms__c;
                        vWrap.status = ivr.Status__c;
                        vWrap.isSelected = (ivr.Status__c == 'Approved');
                        
                        if (vWrap.isSelected) {
                            pWrap.selectedVendorMasterId = ivr.Vendor__c;
                        }
                        
                        pWrap.vendorRates.add(vWrap);
                    }
                }
                
                responseList.add(pWrap);
            }
            
            return responseList;
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }
    
    @AuraEnabled
    public static void saveAndApprovePR(Id purchaseRequestId, List<Item_Vendor_Rate__c> ivrListToUpdate) {
        try {
            if (ivrListToUpdate != null && !ivrListToUpdate.isEmpty()) {
                upsert ivrListToUpdate;
            }
            
            Purchase_Request__c pr = [
                SELECT Id, Name, Status__c, OwnerId 
                FROM Purchase_Request__c 
                WHERE Id = :purchaseRequestId 
                LIMIT 1
            ];
            
            pr.Status__c = 'Approved';
            update pr;
            
            sendApprovalNotificationToPurchaseTeam(pr);
            
        } catch (Exception ex) {
            AuraHandledException auraEx = new AuraHandledException(ex.getMessage());
            auraEx.setMessage(ex.getMessage());
            throw auraEx;
        }
    }
    
    private static void sendApprovalNotificationToPurchaseTeam(Purchase_Request__c pr) {
        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id, DeveloperName 
                FROM CustomNotificationType WHERE DeveloperName = 'PR_Approval_to_Purchase_Team'
                LIMIT 1
            ];
            
            if (notifTypes.isEmpty()) {
                return;
            }
            
            Set<String> recipientIds = new Set<String>();
            
            for (GroupMember gm : [
                SELECT UserOrGroupId 
                FROM GroupMember 
                WHERE Group.Type = 'Queue' 
                AND (Group.DeveloperName = 'Purchase_Team_Queue' OR Group.Name = 'Purchase Team Queue')
            ]) {
                recipientIds.add(gm.UserOrGroupId);
            }
            
            if (recipientIds.isEmpty()) {
                return;
            }
            
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Purchase Request Approved');
            notification.setBody('Purchase Request ' + pr.Name + ' has been approved by the Admin.');
            notification.setNotificationTypeId(notifTypes[0].Id);
            notification.setTargetId(pr.Id);
            notification.send(recipientIds);
            
        } catch (Exception ex) {
            System.debug('Error sending approval notification: ' + ex.getMessage());
        }
    }
}