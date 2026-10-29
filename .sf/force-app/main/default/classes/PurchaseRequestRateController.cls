public class PurchaseRequestRateController {

    public class VendorRateWrapper {
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
    }

    public class ProductAccordionWrapper {
        @AuraEnabled public Id prLineItemId { get; set; }
        @AuraEnabled public String prLineItemNumber { get; set; }
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public Decimal requestedQty { get; set; }
        @AuraEnabled public List<VendorRateWrapper> vendorRates { get; set; }
    }

    @AuraEnabled
    public static List<ProductAccordionWrapper> getPRLineItemsWithVendors(Id purchaseRequestId) {
        try {
            List<ProductAccordionWrapper> responseList = new List<ProductAccordionWrapper>();

            // 1. Fetch all PR Line Items for this Purchase Request
            List<Purchase_Request_Line_Item__c> prLineItems = [
                SELECT Id, Name, Product__c, Product__r.Name, Product__r.Brand__c, Product__r.Sub_Brand__c, Quantity__c
                FROM Purchase_Request_Line_Item__c
                WHERE Purchase_Request__c = :purchaseRequestId
                ORDER BY Name ASC
            ];

            if (prLineItems.isEmpty()) {
                return responseList;
            }

            // Collect Product & PR Line Item Ids, and Brands
            Set<Id> prLineItemIds = new Set<Id>();
            Set<Id> brandIds = new Set<Id>();
            for (Purchase_Request_Line_Item__c prli : prLineItems) {
                prLineItemIds.add(prli.Id);
                if (prli.Product__c != null) {
                    if (prli.Product__r.Brand__c != null) brandIds.add(prli.Product__r.Brand__c);
                    if (prli.Product__r.Sub_Brand__c != null) brandIds.add(prli.Product__r.Sub_Brand__c);
                }
            }

            // 2. Fetch Vendors matching the brands
            List<Vendor__c> vendorList = [
                SELECT Id, Vendor_Master__c, Vendor_Master__r.Name, Brand__c 
                FROM Vendor__c 
                WHERE Brand__c IN :brandIds
            ];

            // Map Brand to its Vendor Masters
            Map<Id, Map<Id, String>> brandToVendorMap = new Map<Id, Map<Id, String>>();
            for (Vendor__c ven : vendorList) {
                if (ven.Vendor_Master__c != null && ven.Brand__c != null) {
                    if (!brandToVendorMap.containsKey(ven.Brand__c)) {
                        brandToVendorMap.put(ven.Brand__c, new Map<Id, String>());
                    }
                    brandToVendorMap.get(ven.Brand__c).put(ven.Vendor_Master__c, ven.Vendor_Master__r.Name);
                }
            }

            // 3. Fetch Existing IVR records linked to these PR Line Items
            List<Item_Vendor_Rate__c> existingIVRList = [
                SELECT Id, Product__c, Vendor__c, Status__c, Discount__c, GST__c, Quantity__c, Rate__c, 
                       Purchase_Request_Line_Item__c, Delivery_Transportation_Charges__c, Other_Applicable_Commercial_Terms__c 
                FROM Item_Vendor_Rate__c 
                WHERE Purchase_Request_Line_Item__c IN :prLineItemIds
            ];

            // Key: prLineItemId + '_' + vendorId -> IVR
            Map<String, Item_Vendor_Rate__c> ivrMap = new Map<String, Item_Vendor_Rate__c>();
            for (Item_Vendor_Rate__c ivr : existingIVRList) {
                String key = ivr.Purchase_Request_Line_Item__c + '_' + ivr.Vendor__c;
                ivrMap.put(key, ivr);
            }

            // 4. Build Accordion structure
            for (Purchase_Request_Line_Item__c prli : prLineItems) {
                ProductAccordionWrapper pWrap = new ProductAccordionWrapper();
                pWrap.prLineItemId = prli.Id;
                pWrap.prLineItemNumber = prli.Name;
                pWrap.productId = prli.Product__c;
                pWrap.productName = prli.Product__r != null ? prli.Product__r.Name : 'No Product';
                pWrap.requestedQty = prli.Quantity__c;
                pWrap.vendorRates = new List<VendorRateWrapper>();

                Set<Id> addedVendors = new Set<Id>();
                Map<Id, String> availableVendors = new Map<Id, String>();

                if (prli.Product__c != null) {
                    if (prli.Product__r.Brand__c != null && brandToVendorMap.containsKey(prli.Product__r.Brand__c)) {
                        availableVendors.putAll(brandToVendorMap.get(prli.Product__r.Brand__c));
                    }
                    if (prli.Product__r.Sub_Brand__c != null && brandToVendorMap.containsKey(prli.Product__r.Sub_Brand__c)) {
                        availableVendors.putAll(brandToVendorMap.get(prli.Product__r.Sub_Brand__c));
                    }
                }

                for (Id vMasterId : availableVendors.keySet()) {
                    if (!addedVendors.contains(vMasterId)) {
                        String key = prli.Id + '_' + vMasterId;
                        Item_Vendor_Rate__c existingIvr = ivrMap.get(key);

                        VendorRateWrapper vWrap = new VendorRateWrapper();
                        vWrap.ivrId = existingIvr != null ? existingIvr.Id : null;
                        vWrap.prLineItemId = prli.Id;
                        vWrap.productId = prli.Product__c;
                        vWrap.productName = prli.Product__r != null ? prli.Product__r.Name : '';
                        vWrap.vendorMasterId = vMasterId;
                        vWrap.vendorMasterName = availableVendors.get(vMasterId);
                        vWrap.rate = existingIvr != null ? existingIvr.Rate__c : null;
                        vWrap.quantity = existingIvr != null ? existingIvr.Quantity__c : prli.Quantity__c;
                        vWrap.discount = existingIvr != null ? existingIvr.Discount__c : null;
                        vWrap.gst = existingIvr != null ? existingIvr.GST__c : null;
                        vWrap.deliveryCharges = existingIvr != null ? existingIvr.Delivery_Transportation_Charges__c : null;
                        vWrap.commercialTerms = existingIvr != null ? existingIvr.Other_Applicable_Commercial_Terms__c : null;
                        vWrap.status = existingIvr != null ? existingIvr.Status__c : 'Pending';

                        pWrap.vendorRates.add(vWrap);
                        addedVendors.add(vMasterId);
                    }
                }

                responseList.add(pWrap);
            }

            return responseList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage() + ' ' + e.getStackTraceString());
        }
    }

    @AuraEnabled
    public static Map<String, String> saveItemVendorRates(Id purchaseRequestId, List<Item_Vendor_Rate__c> ivrRecordList) {
        Map<String, String> response = new Map<String, String>();
        try {
            if (ivrRecordList == null || ivrRecordList.isEmpty()) {
                response.put('status', 'error');
                response.put('message', 'No vendor rate entered to save.');
                return response;
            }

            upsert ivrRecordList;

            if (purchaseRequestId != null) {
                Purchase_Request__c pr = new Purchase_Request__c();
                pr.Id = purchaseRequestId;
                pr.Status__c = 'Vendor Rates Added';
                update pr;
            }

            response.put('status', 'success');
            response.put('message', 'Vendor Rates saved successfully!');
            return response;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    
}