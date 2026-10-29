public class PurchaseRequestGeneratePOController {
    
    public class POLineItemWrapper {
        @AuraEnabled public Id ivrId { get; set; }
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal rate { get; set; }
        @AuraEnabled public Decimal discount { get; set; }
        @AuraEnabled public Decimal gst { get; set; }
        @AuraEnabled public Decimal deliveryCharges { get; set; }
        @AuraEnabled public String commercialTerms { get; set; }
    }
    
    public class VendorGroupWrapper {
        @AuraEnabled public Id vendorId { get; set; }
        @AuraEnabled public String vendorName { get; set; }
        @AuraEnabled public String sectionLabel { get; set; }
        @AuraEnabled public List<POLineItemWrapper> lineItems { get; set; }
        
        // Delivery Details
        @AuraEnabled public Date expectedDeliveryDate { get; set; }
        @AuraEnabled public String trackingNumber { get; set; }
        @AuraEnabled public String trackingUrl { get; set; }
    }
    
    @AuraEnabled
    public static List<VendorGroupWrapper> getApprovedVendorsForPO(Id purchaseRequestId) {
        try {
            Purchase_Request__c pr = [
                SELECT Id, Status__c 
                FROM Purchase_Request__c 
                WHERE Id = :purchaseRequestId 
                LIMIT 1
            ];
            
            if (pr.Status__c != 'Approved') {
                AuraHandledException ex = new AuraHandledException('PO can only be generated when status is "Approved". Current Status: ' + pr.Status__c);
                ex.setMessage('PO can only be generated when status is "Approved". Current Status: ' + pr.Status__c);
                throw ex;
            }
            
            List<Purchase_Request_Line_Item__c> prLines = [
                SELECT Id 
                FROM Purchase_Request_Line_Item__c 
                WHERE Purchase_Request__c = :purchaseRequestId
            ];
            
            Set<Id> prLineIds = new Set<Id>();
            for (Purchase_Request_Line_Item__c prl : prLines) {
                prLineIds.add(prl.Id);
            }
            
            List<Item_Vendor_Rate__c> approvedIVRList = [
                SELECT Id, Vendor__c, Vendor__r.Name, Product__c, Product__r.Name, 
                Rate__c, Quantity__c, Discount__c, GST__c, Status__c,
                Purchase_Request_Line_Item__c,
                Delivery_Transportation_Charges__c, Other_Applicable_Commercial_Terms__c
                FROM Item_Vendor_Rate__c 
                WHERE Purchase_Request_Line_Item__c IN :prLineIds 
                AND Status__c = 'Approved'
                ORDER BY Vendor__r.Name ASC, Product__r.Name ASC
            ];
            
            if (approvedIVRList.isEmpty()) {
                AuraHandledException ex = new AuraHandledException('No Approved vendor rates found for this Purchase Request.');
                ex.setMessage('No Approved vendor rates found for this Purchase Request.');
                throw ex;
            }
            
            Map<Id, List<Item_Vendor_Rate__c>> vendorMap = new Map<Id, List<Item_Vendor_Rate__c>>();
            Map<Id, String> vendorNameMap = new Map<Id, String>();
            
            for (Item_Vendor_Rate__c ivr : approvedIVRList) {
                if (!vendorMap.containsKey(ivr.Vendor__c)) {
                    vendorMap.put(ivr.Vendor__c, new List<Item_Vendor_Rate__c>());
                    vendorNameMap.put(ivr.Vendor__c, ivr.Vendor__r.Name);
                }
                vendorMap.get(ivr.Vendor__c).add(ivr);
            }
            
            List<VendorGroupWrapper> responseList = new List<VendorGroupWrapper>();
            
            for (Id vId : vendorMap.keySet()) {
                VendorGroupWrapper vWrap = new VendorGroupWrapper();
                vWrap.vendorId = vId;
                vWrap.vendorName = vendorNameMap.get(vId);
                vWrap.sectionLabel = 'Vendor: ' + vWrap.vendorName + ' (' + vendorMap.get(vId).size() + ' Items)';
                vWrap.lineItems = new List<POLineItemWrapper>();
                
                for (Item_Vendor_Rate__c ivr : vendorMap.get(vId)) {
                    POLineItemWrapper item = new POLineItemWrapper();
                    item.ivrId = ivr.Id;
                    item.productId = ivr.Product__c;
                    item.productName = ivr.Product__r != null ? ivr.Product__r.Name : '-';
                    item.quantity = ivr.Quantity__c;
                    item.rate = ivr.Rate__c;
                    item.discount = ivr.Discount__c;
                    item.gst = ivr.GST__c;
                    item.deliveryCharges = ivr.Delivery_Transportation_Charges__c;
                    item.commercialTerms = ivr.Other_Applicable_Commercial_Terms__c;
                    vWrap.lineItems.add(item);
                }
                
                responseList.add(vWrap);
            }
            
            return responseList;
            
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            AuraHandledException auraEx = new AuraHandledException(ex.getMessage());
            auraEx.setMessage(ex.getMessage());
            throw auraEx;
        }
    }
    
    @AuraEnabled
    public static void createPurchaseOrders(Id purchaseRequestId, List<VendorGroupWrapper> vendorGroupsData) {
        try {
            Purchase_Request__c pr = [
                SELECT Id, Status__c, Opportunity__c, Challan__c 
                FROM Purchase_Request__c 
                WHERE Id = :purchaseRequestId 
                LIMIT 1
            ];
            
            if (pr.Status__c != 'Approved') {
                AuraHandledException ex = new AuraHandledException('PO can only be generated when Status is "Approved".');
                ex.setMessage('PO can only be generated when Status is "Approved".');
                throw ex;
            }
            
            if (vendorGroupsData == null || vendorGroupsData.isEmpty()) {
                AuraHandledException ex = new AuraHandledException('No vendor data available to generate PO.');
                ex.setMessage('No vendor data available to generate PO.');
                throw ex;
            }
            
            // Fetch RecordTypeId for Delivery_Detail__c with DeveloperName or Name 'Purchase_Detail'
            Id purchaseDetailRecordTypeId;
            try {
                purchaseDetailRecordTypeId = Schema.SObjectType.Delivery_Detail__c.getRecordTypeInfosByDeveloperName().get('Purchase_Detail').getRecordTypeId();
            } catch(Exception e) {
                if (Schema.SObjectType.Delivery_Detail__c.getRecordTypeInfosByName().containsKey('Purchase Detail')) {
                    purchaseDetailRecordTypeId = Schema.SObjectType.Delivery_Detail__c.getRecordTypeInfosByName().get('Purchase Detail').getRecordTypeId();
                }
            }
            
            // Server-side validation for mandatory Expected Delivery Date
            for (VendorGroupWrapper vg : vendorGroupsData) {
                if (vg.expectedDeliveryDate == null) {
                    AuraHandledException ex = new AuraHandledException('Expected Delivery Date is required for vendor: ' + vg.vendorName);
                    ex.setMessage('Expected Delivery Date is required for vendor: ' + vg.vendorName);
                    throw ex;
                }
            }
            
            List<Purchase_Order__c> poListToInsert = new List<Purchase_Order__c>();
            Map<Id, Purchase_Order__c> vendorToPOMap = new Map<Id, Purchase_Order__c>();
            
            for (VendorGroupWrapper vg : vendorGroupsData) {
                Purchase_Order__c po = new Purchase_Order__c();
                po.Vendor_Master__c = vg.vendorId;
                po.Purchase_Request__c = pr.Id;
                poListToInsert.add(po);
                vendorToPOMap.put(vg.vendorId, po);
            }
            
            insert poListToInsert;
            
            List<Purchase_Order_Line_Item__c> poliListToInsert = new List<Purchase_Order_Line_Item__c>();
            List<Item_Vendor_Rate__c> ivrListToUpdate = new List<Item_Vendor_Rate__c>();
            List<Delivery_Detail__c> deliveryDetailsToInsert = new List<Delivery_Detail__c>();
            List<User> logisticsTeamUserRecords = [SELECT Id FROM User WHERE User_Profile_Name__c = 'Logistics Team Manager' AND IsActive = true LIMIT 1];
            for (VendorGroupWrapper vg : vendorGroupsData) {
                Purchase_Order__c createdPO = vendorToPOMap.get(vg.vendorId);
                Decimal totalPromisedItems = 0;
                
                for (POLineItemWrapper item : vg.lineItems) {
                    Purchase_Order_Line_Item__c poli = new Purchase_Order_Line_Item__c();
                    poli.Purchase_Order__c = createdPO.Id;
                    poli.Product__c = item.productId;
                    poli.Unit_Price__c = item.rate;
                    poli.Quantity__c = item.quantity;
                    poli.Discount__c = item.discount;
                    poli.GST__c = item.gst;
                    poli.Delivery_Transportation_Charges__c = item.deliveryCharges;
                    poli.Other_Applicable_Commercial_Terms__c = item.commercialTerms;
                    poliListToInsert.add(poli);
                    
                    if (item.quantity != null) {
                        totalPromisedItems += item.quantity;
                    }
                    
                    Item_Vendor_Rate__c ivr = new Item_Vendor_Rate__c();
                    ivr.Id = item.ivrId;
                    ivr.Status__c = 'Generated';
                    ivrListToUpdate.add(ivr);
                }
                
                // Delivery Detail Record per Vendor Table
                Delivery_Detail__c dd = new Delivery_Detail__c();
                if (purchaseDetailRecordTypeId != null) {
                    dd.RecordTypeId = purchaseDetailRecordTypeId;
                }
                dd.Purchase_Order__c = createdPO.Id; // Purchase Order Link
                //dd.Challan__c = pr.Challan__c;
                dd.Expected_Delivery_Date__c = vg.expectedDeliveryDate;
                dd.Tracking_Number__c = vg.trackingNumber;
                // URL Formatting (Handles both "google.com" and "https://mail.google.com")
                String formattedUrl = vg.trackingUrl != null ? vg.trackingUrl.trim() : null;
                if (String.isNotBlank(formattedUrl) && !formattedUrl.startsWithIgnoreCase('http://') && !formattedUrl.startsWithIgnoreCase('https://')) {
                    formattedUrl = 'https://' + formattedUrl;
                }
                dd.Tracking_URL__c = formattedUrl;
                dd.Delivery_Status__c = 'Dispatched';
                dd.Promised_Items__c = totalPromisedItems;
                if(!logisticsTeamUserRecords.IsEmpty()){
                    dd.OwnerId = logisticsTeamUserRecords[0].Id;
                }
                deliveryDetailsToInsert.add(dd);
            }
            
            if (!poliListToInsert.isEmpty()) {
                insert poliListToInsert;
            }
            
            if (!deliveryDetailsToInsert.isEmpty()) {
                insert deliveryDetailsToInsert;
                Set<Id> deliveryDetailIds = new Set<Id>();
                for(Delivery_detail__c deliveryDetail : deliveryDetailsToInsert){
                    deliveryDetailIds.add(deliveryDetail.Id);
                }
                if(!deliveryDetailIds.IsEmpty()){
                    List<Delivery_Detail__c> lstRecofDeliveryDetails = [SELECT Id,Name,Purchase_Order__c,Purchase_Order__r.Name FROM Delivery_Detail__c WHERE Id IN : deliveryDetailIds];
                    List<User> logisticsTeamUserlst = [SELECT Id FROM User WHERE User_Profile_Name__c = 'Logistics Team Manager' AND IsActive = true LIMIT 1];
                    for(Delivery_detail__c deliveryDetail : lstRecofDeliveryDetails){
                        Messaging.CustomNotification logisticsNotification = new Messaging.CustomNotification();
                        logisticsNotification.setTitle('New Delivery Detail Assigned');
                        logisticsNotification.setBody(
                            'Purchase Order: ' + deliveryDetail.Purchase_Order__r.Name +
                            '\nDelivery Detail: ' + deliveryDetail.Name +
                            '\n\nA new Delivery Detail has been created. ' +
                            'Please review the Delivery Detail and proceed with the next steps.'
                        );
                        logisticsNotification.setNotificationTypeId( label.PO_Delivery_Detail_To_Logistics);
                        logisticsNotification.setTargetId(deliveryDetail.Id);
                        
                        try {
                            logisticsNotification.send( new Set<String>{ logisticsTeamUserlst[0].Id });
                        } catch (Exception e) {
                            System.debug(
                                'Logistics notification error: ' + e.getMessage()
                            );
                        }
                    }
                }
                
            }
            
            if (!ivrListToUpdate.isEmpty()) {
                update ivrListToUpdate;
            }
            
            pr.Status__c = 'PO Generated';
            update pr;
            
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            AuraHandledException auraEx = new AuraHandledException(ex.getMessage());
            auraEx.setMessage(ex.getMessage());
            throw auraEx;
        }
    }
}