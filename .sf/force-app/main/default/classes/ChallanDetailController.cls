public class ChallanDetailController {
    
    public class SalesOrderWrapper {
        @AuraEnabled public Sales_Order__c salesOrder { get; set; }
        @AuraEnabled public Sales_Order_Challan__c salesOrderChallan { get; set; }
        @AuraEnabled public List<Cart_Line_Item__c> lineItems { get; set; }
        @AuraEnabled public Integer totalLineItems { get; set; }
    }
    
    public class ChallanWrapper {
        @AuraEnabled public Challan__c challan { get; set; }
        @AuraEnabled public List<SalesOrderWrapper> salesOrders { get; set; }
        @AuraEnabled public Picker_Packer_Detail__c pickerPackerDetail { get; set; }
        @AuraEnabled public Boolean hasExistingPR { get; set; }
        @AuraEnabled public String existingPRNumber { get; set; }
        // @AuraEnabled public List<Sales_Order_Challan__c> salesOrderChallans { get; set; }
        @AuraEnabled public Id existingPRId { get; set; }
        @AuraEnabled public List<DeliveryLink> deliveries { get; set; }
    }

    public class DeliveryLink {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String name { get; set; }
    }
    
    public class PRLineItemInput {
        @AuraEnabled public Id lineItemId { get; set; }
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
    }
    
    @AuraEnabled(cacheable=true)
    public static ChallanWrapper getChallanHierarchy(Id challanId) {
        ChallanWrapper response = new ChallanWrapper();
        
        // 1. Fetch Challan Details
        response.challan = [
            SELECT Id, Name, Status__c, Opportunity__c, Opportunity__r.Name, Way_of_Transit__c, Address__c, CreatedDate,
            Total_Actual_Amount__c, Total_Ordered_Amount__c,Total_GST__c,Total_Discount__c
            FROM Challan__c
            WHERE Id = :challanId
            LIMIT 1
        ];
        
        // Check if a Purchase Request already exists for this Challan
        List<Purchase_Request__c> existingPRList = [
            SELECT Id, Name 
            FROM Purchase_Request__c 
            WHERE Challan__c = :challanId 
            LIMIT 1
        ];
        if (!existingPRList.isEmpty()) {
            response.hasExistingPR = true;
            response.existingPRNumber = existingPRList[0].Name;
            response.existingPRId = existingPRList[0].Id;
        } else {
            response.hasExistingPR = false;
        }

        response.deliveries = new List<DeliveryLink>();
        for (Delivery_Detail__c delivery : [
            SELECT Id, Name
            FROM Delivery_Detail__c
            WHERE Challan__c = :challanId
            AND RecordType.DeveloperName = 'Sales_Detail'
            ORDER BY CreatedDate DESC
        ]) {
            DeliveryLink deliveryLink = new DeliveryLink();
            deliveryLink.recordId = delivery.Id;
            deliveryLink.name = delivery.Name;
            response.deliveries.add(deliveryLink);
        }
        
        // 1.1 Fetch Associated Picker & Packer Detail (Only 1 record per Challan)
        List<Picker_Packer_Detail__c> detailList = [
            SELECT Id, Name, Challan__c, Picker__c, Picker__r.Name, Packer__c, Packer__r.Name, 
            Station_User__c, Station_User__r.Name, Instructions__c
            FROM Picker_Packer_Detail__c
            WHERE Challan__c = :challanId
            LIMIT 1
        ];
        if (!detailList.isEmpty()) {
            response.pickerPackerDetail = detailList[0];
        }
        
        List<Sales_Order_Challan__c> lstRecordsofSalesOrderChallans = [
            SELECT Id, Sales_Order__c, Actual_Amount__c, Ordered_Amount__c 
            FROM Sales_Order_Challan__c 
            WHERE Challan__c = :challanId AND Sales_Order__c != null
        ];
        // response.salesOrderChallans = lstRecordsofSalesOrderChallans;
        
        Set<Id> salesOrderIds = new Set<Id>();
        Map<Id, Sales_Order_Challan__c> soToChallanMap = new Map<Id, Sales_Order_Challan__c>();
        if (!lstRecordsofSalesOrderChallans.isEmpty()) {
            for (Sales_Order_Challan__c soChallan : lstRecordsofSalesOrderChallans) {
                salesOrderIds.add(soChallan.Sales_Order__c);
                soToChallanMap.put(soChallan.Sales_Order__c, soChallan);
            }
        }
        
        List<Sales_Order__c> soList = [
            SELECT Id, Name, Opportunity__c, Opportunity__r.Name, Special_Instructions__c, Grand_Total_With_GST__c,
            Total_Actual_Amount__c, Total_Ordered_Amount__c
            FROM Sales_Order__c
            WHERE Id IN :salesOrderIds
            ORDER BY Name ASC
        ];
        
        if (soList.isEmpty()) {
            response.salesOrders = new List<SalesOrderWrapper>();
            return response;
        }
        
        Set<Id> soIds = new Set<Id>();
        for (Sales_Order__c so : soList) {
            soIds.add(so.Id);
        }
        
        List<Cart_Line_Item__c> lineItemList = [
            SELECT Id, Name, Sales_Order__c, Product__c, Product__r.Name, 
            Quantity__c, Amount__c, GST__c, Total_Amount__c,GST_Amount__c,Priority__c,Actual_Amount__c,
            Discount__c,After_Discount__c,Final_Amount__c, Total_Dispatch_Quantity__c, Total_Pending_Quantity__c, Promise_Date__c
            FROM Cart_Line_Item__c
            WHERE Sales_Order__c IN :soIds AND Challan_Created__c = true AND Challan__c = :challanId
            ORDER BY Name ASC
        ];
        
        Map<Id, List<Cart_Line_Item__c>> soToLineItemsMap = new Map<Id, List<Cart_Line_Item__c>>();
        for (Cart_Line_Item__c cli : lineItemList) {
            if (!soToLineItemsMap.containsKey(cli.Sales_Order__c)) {
                soToLineItemsMap.put(cli.Sales_Order__c, new List<Cart_Line_Item__c>());
            }
            soToLineItemsMap.get(cli.Sales_Order__c).add(cli);
        }
        
        List<SalesOrderWrapper> wrappedSOs = new List<SalesOrderWrapper>();
        for (Sales_Order__c so : soList) {
            SalesOrderWrapper wrapper = new SalesOrderWrapper();
            wrapper.salesOrder = so;
            wrapper.salesOrderChallan = soToChallanMap.get(so.Id); // Link specific SO Challan record
            wrapper.lineItems = soToLineItemsMap.containsKey(so.Id) ? soToLineItemsMap.get(so.Id) : new List<Cart_Line_Item__c>();
            wrapper.totalLineItems = wrapper.lineItems.size();
            wrappedSOs.add(wrapper);
        }
        
        response.salesOrders = wrappedSOs;
        return response;
    }
    
    @AuraEnabled
    public static void updateLineItemQuantities(List<Cart_Line_Item__c> lineItemsToUpdate) {
        try {
            if (lineItemsToUpdate != null && !lineItemsToUpdate.isEmpty()) {
                Set<Id> lineItemIds = new Set<Id>();
                for (Cart_Line_Item__c lineItem : lineItemsToUpdate) {
                    if (lineItem.Id != null) {
                        lineItemIds.add(lineItem.Id);
                    }
                }

                Map<Id, Cart_Line_Item__c> existingLineItemsById = new Map<Id, Cart_Line_Item__c>();
                if (!lineItemIds.isEmpty()) {
                    existingLineItemsById = new Map<Id, Cart_Line_Item__c>([
                        SELECT Id, Sales_Order__c, Quantity__c, Total_Dispatch_Quantity__c
                        FROM Cart_Line_Item__c
                        WHERE Id IN :lineItemIds
                    ]);
                }

                Set<Id> changedLineItemIds = new Set<Id>();
                for (Cart_Line_Item__c lineItem : lineItemsToUpdate) {
                    Cart_Line_Item__c existingLineItem = existingLineItemsById.get(lineItem.Id);
                    if (existingLineItem == null) {
                        continue;
                    }
                    Decimal newDispatchQuantity = lineItem.Total_Dispatch_Quantity__c == null ? 0 : lineItem.Total_Dispatch_Quantity__c;
                    Decimal existingDispatchQuantity = existingLineItem.Total_Dispatch_Quantity__c == null ? 0 : existingLineItem.Total_Dispatch_Quantity__c;
                    if (newDispatchQuantity != existingDispatchQuantity) {
                        changedLineItemIds.add(lineItem.Id);
                    }
                }

                update lineItemsToUpdate;
                
                Set<Id> soOrdersItemsIds = new Set<Id>();
                
                for (Cart_Line_Item__c salesOrderLineItem : lineItemsToUpdate) {
                    soOrdersItemsIds.add(salesOrderLineItem.Id);
                }
                
                List<Cart_Line_Item__c> salesOrderItems = [SELECT Id,Challan__c, Actual_Amount__c, Sales_Order__c FROM Cart_Line_Item__c  WHERE Id IN :soOrdersItemsIds];
                
                Set<Id> challanIds = new Set<Id>();
                for (Cart_Line_Item__c salesOrderLineItem : salesOrderItems) {
                    if (salesOrderLineItem.Challan__c != null) {
                        challanIds.add(salesOrderLineItem.Challan__c);
                    }
                }
                
                Map<Id, Decimal> challanIdWithTotalActualAmount = new Map<Id, Decimal>();
                
                for (Cart_Line_Item__c salesOrderLineItem : salesOrderItems) {
                    if (salesOrderLineItem.Challan__c == null) {
                        continue;
                    }
                    
                    Decimal actualAmount =
                        salesOrderLineItem.Actual_Amount__c != null
                        ? salesOrderLineItem.Actual_Amount__c
                        : 0;
                    
                    if (challanIdWithTotalActualAmount.containsKey(salesOrderLineItem.Challan__c)) {
                        challanIdWithTotalActualAmount.put(salesOrderLineItem.Challan__c,challanIdWithTotalActualAmount.get(salesOrderLineItem.Challan__c) + actualAmount);                        
                    } else {
                        challanIdWithTotalActualAmount.put( salesOrderLineItem.Challan__c,actualAmount);
                    }
                }
                
                // Update Challan Total Actual Amount
                List<Challan__c> toUpdateChallanRec = new List<Challan__c>();
                
                for (Id challanId : challanIdWithTotalActualAmount.keySet()) {
                    toUpdateChallanRec.add(
                        new Challan__c(
                            Id = challanId,
                            Total_Actual_Amount__c =
                            challanIdWithTotalActualAmount.get(challanId)
                        )
                    );
                }
                
                if (!toUpdateChallanRec.isEmpty()) {
                    update toUpdateChallanRec;
                }
                // Update Sales Order Challan Actual Amount
                Map<String, Decimal> soChallanIdWithActualAmount = new Map<String, Decimal>();
                
                List<Sales_Order_Challan__c> salesOrderChallanRecords = [SELECT Id, Sales_Order__c, Challan__c FROM Sales_Order_Challan__c WHERE Challan__c IN :challanIds ];
                
                Map<String, Sales_Order_Challan__c> soChallanMap =  new Map<String, Sales_Order_Challan__c>();
                
                for (Sales_Order_Challan__c soc : salesOrderChallanRecords) {
                    soChallanMap.put(String.valueOf(soc.Sales_Order__c) + String.valueOf(soc.Challan__c),soc);
                }
                
                
                // Get ALL line items for these Challans
                List<Cart_Line_Item__c> allChallanLineItems = [SELECT Id, Challan__c,Sales_Order__c, Actual_Amount__c FROM Cart_Line_Item__c WHERE Challan__c IN :challanIds];
                
                for (Cart_Line_Item__c lineItem : allChallanLineItems) {
                    
                    if (lineItem.Challan__c == null || lineItem.Sales_Order__c == null) {
                        continue;
                    }
                    
                    Decimal actualAmount = lineItem.Actual_Amount__c != null ? lineItem.Actual_Amount__c : 0;
                    String key = String.valueOf(lineItem.Sales_Order__c) + String.valueOf(lineItem.Challan__c);
                    
                    if (soChallanIdWithActualAmount.containsKey(key)) {
                        soChallanIdWithActualAmount.put(key,soChallanIdWithActualAmount.get(key) + actualAmount);
                    } else {
                        soChallanIdWithActualAmount.put(key,actualAmount);
                    }
                }
                
                
                List<Sales_Order_Challan__c> toUpdateSOC =  new List<Sales_Order_Challan__c>();
                for (Sales_Order_Challan__c soc : salesOrderChallanRecords) {
                    String key = String.valueOf(soc.Sales_Order__c) + String.valueOf(soc.Challan__c);
                    Decimal totalActualAmount = soChallanIdWithActualAmount.containsKey(key) ? soChallanIdWithActualAmount.get(key): 0;
                    
                    toUpdateSOC.add(new Sales_Order_Challan__c(Id = soc.Id, Actual_Amount__c = totalActualAmount));
                }
                
                if (!toUpdateSOC.isEmpty()) {
                    update toUpdateSOC;
                }

                if (!changedLineItemIds.isEmpty()) {
                    Set<Id> salesOrderIdsToEvaluate = new Set<Id>();
                    for (Id lineItemId : changedLineItemIds) {
                        Cart_Line_Item__c existingLineItem = existingLineItemsById.get(lineItemId);
                        if (existingLineItem != null && existingLineItem.Sales_Order__c != null) {
                            salesOrderIdsToEvaluate.add(existingLineItem.Sales_Order__c);
                        }
                    }

                    if (!salesOrderIdsToEvaluate.isEmpty()) {
                        Map<Id, Sales_Order__c> salesOrderById = new Map<Id, Sales_Order__c>([
                            SELECT Id, Status__c
                            FROM Sales_Order__c
                            WHERE Id IN :salesOrderIdsToEvaluate
                        ]);

                        Map<Id, List<Cart_Line_Item__c>> lineItemsBySalesOrderId = new Map<Id, List<Cart_Line_Item__c>>();
                        for (Cart_Line_Item__c lineItem : [
                            SELECT Id, Sales_Order__c, Quantity__c, Total_Dispatch_Quantity__c
                            FROM Cart_Line_Item__c
                            WHERE Sales_Order__c IN :salesOrderIdsToEvaluate
                        ]) {
                            if (!lineItemsBySalesOrderId.containsKey(lineItem.Sales_Order__c)) {
                                lineItemsBySalesOrderId.put(lineItem.Sales_Order__c, new List<Cart_Line_Item__c>());
                            }
                            lineItemsBySalesOrderId.get(lineItem.Sales_Order__c).add(lineItem);
                        }

                        List<Sales_Order__c> salesOrdersToUpdate = new List<Sales_Order__c>();
                        for (Id salesOrderId : salesOrderIdsToEvaluate) {
                            Sales_Order__c salesOrder = salesOrderById.get(salesOrderId);
                            if (salesOrder == null || salesOrder.Status__c == 'New') {
                                continue;
                            }

                            List<Cart_Line_Item__c> salesOrderLineItems = lineItemsBySalesOrderId.get(salesOrderId);
                            if (salesOrderLineItems == null || salesOrderLineItems.isEmpty()) {
                                continue;
                            }

                            Boolean dispatchQuantityLessThanQuantity = false;
                            Boolean dispatchQuantityEqualsQuantity = false;
                            Boolean allLineItemsFullyDispatched = true;

                            for (Cart_Line_Item__c lineItem : salesOrderLineItems) {
                                Decimal quantity = lineItem.Quantity__c == null ? 0 : lineItem.Quantity__c;
                                Decimal dispatchQuantity = lineItem.Total_Dispatch_Quantity__c == null ? 0 : lineItem.Total_Dispatch_Quantity__c;

                                if (dispatchQuantity != quantity) {
                                    allLineItemsFullyDispatched = false;
                                }

                                if (!changedLineItemIds.contains(lineItem.Id)) {
                                    continue;
                                }

                                if (dispatchQuantity < quantity) {
                                    dispatchQuantityLessThanQuantity = true;
                                } else if (dispatchQuantity == quantity) {
                                    dispatchQuantityEqualsQuantity = true;
                                }
                            }

                            String newStatus;
                            if (dispatchQuantityLessThanQuantity) {
                                newStatus = 'Partial Invoice';
                            } else if (dispatchQuantityEqualsQuantity && allLineItemsFullyDispatched) {
                                newStatus = 'Complete';
                            }

                            if (newStatus != null && salesOrder.Status__c != newStatus) {
                                salesOrder.Status__c = newStatus;
                                salesOrdersToUpdate.add(salesOrder);
                            }
                        }

                        if (!salesOrdersToUpdate.isEmpty()) {
                            update salesOrdersToUpdate;
                        }
                    }
                }
            }
            
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static void savePickerPackerDetail(Id detailId, Id challanId, Id pickerId, Id packerId, Id stationUserId, String instructions) {
        try {
            Picker_Packer_Detail__c detail = new Picker_Packer_Detail__c();
            if (detailId != null) {
                detail.Id = detailId;
            } else {
                List<Picker_Packer_Detail__c> existing = [
                    SELECT Id FROM Picker_Packer_Detail__c 
                    WHERE Challan__c = :challanId 
                    LIMIT 1
                ];
                if (!existing.isEmpty()) {
                    detail.Id = existing[0].Id;
                }
            }
            detail.Challan__c = challanId;
            detail.Picker__c = pickerId;
            detail.Packer__c = packerId;
            detail.Station_User__c = stationUserId;
            detail.Instructions__c = instructions;
            upsert detail;
            
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static String createPurchaseRequestWithItems(Id challanId, List<PRLineItemInput> items) {
        try {
            List<Purchase_Request__c> existingPR = [
                SELECT Id FROM Purchase_Request__c 
                WHERE Challan__c = :challanId 
                LIMIT 1
            ];
            if (!existingPR.isEmpty()) {
                throw new AuraHandledException('A Purchase Request is already linked to this Challan.');
            }
            
            Challan__c ch = [
                SELECT Id, Opportunity__c 
                FROM Challan__c 
                WHERE Id = :challanId 
                LIMIT 1
            ];
            
            List<Group> queueList = [
                SELECT Id FROM Group 
                WHERE Type = 'Queue' AND DeveloperName = 'Purchase_Team_Queue' 
                LIMIT 1
            ];
            if (queueList.isEmpty()) {
                queueList = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name = 'Purchase Team Queue' LIMIT 1];
            }
            
            Purchase_Request__c pr = new Purchase_Request__c();
            pr.Challan__c = challanId;
            pr.Opportunity__c = ch.Opportunity__c;
            
            if (!queueList.isEmpty()) {
                pr.OwnerId = queueList[0].Id;
            }
            insert pr;
            
            List<Purchase_Request_Line_Item__c> prLineItems = new List<Purchase_Request_Line_Item__c>();
            for (PRLineItemInput item : items) {
                if (item.quantity != null && item.quantity > 0) {
                    Purchase_Request_Line_Item__c prItem = new Purchase_Request_Line_Item__c();
                    prItem.Purchase_Request__c = pr.Id;
                    prItem.Product__c = item.productId;
                    prItem.Quantity__c = item.quantity;
                    prItem.Sales_Order_Line_Item__c = item.lineItemId;
                    prLineItems.add(prItem);
                }
            }
            
            if (!prLineItems.isEmpty()) {
                insert prLineItems;
            }
            
            if (!queueList.isEmpty()) {
                List<CustomNotificationType> notifTypes = [
                    SELECT Id 
                    FROM CustomNotificationType 
                    WHERE DeveloperName = 'Purchase_Req_Assignment' 
                    LIMIT 1
                ];
                
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle('New Purchase Request Assigned');
                notification.setBody('A new Purchase Request has been assigned to the Purchase Team Queue.');
                notification.setNotificationTypeId(notifTypes[0].Id);
                notification.setTargetId(pr.Id);
                
                try {
                    notification.send(new Set<String>{ queueList[0].Id });
                } catch (Exception ex) {
                    System.debug('Error sending custom notification: ' + ex.getMessage());
                }
            }
            return pr.Id;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Sales_Order__c> toUpdateSalesOrderStatus(Id challanId, String currentChallanStatus){
        if(String.isBlank(currentChallanStatus)){
            List<Challan__c> chList = [SELECT Id, Status__c FROM Challan__c WHERE Id = :challanId LIMIT 1];
            if(!chList.isEmpty()){
                currentChallanStatus = chList[0].Status__c;
            }
        }
        
        List<Sales_Order_Challan__c> lstRecSOChallan = [
            SELECT Id, Sales_Order__c FROM Sales_Order_Challan__c 
            WHERE Challan__c = :challanId AND Sales_Order__c != null
        ];
        
        if(lstRecSOChallan.isEmpty()){
            return new List<Sales_Order__c>();
        }
        
        Set<Id> salesOrderIds = new Set<Id>();
        for(Sales_Order_Challan__c soc : lstRecSOChallan){
            salesOrderIds.add(soc.Sales_Order__c);
        }
        
        List<Sales_Order_Challan__c> allLinkedSOChallans = [
            SELECT Id, Sales_Order__c, Challan__c 
            FROM Sales_Order_Challan__c 
            WHERE Sales_Order__c IN :salesOrderIds AND Challan__c != null
        ];
        
        Set<Id> allChallanIds = new Set<Id>();
        Map<Id, Set<Id>> soToChallanIdsMap = new Map<Id, Set<Id>>();
        for(Sales_Order_Challan__c soc : allLinkedSOChallans){
            allChallanIds.add(soc.Challan__c);
            if(!soToChallanIdsMap.containsKey(soc.Sales_Order__c)){
                soToChallanIdsMap.put(soc.Sales_Order__c, new Set<Id>());
            }
            soToChallanIdsMap.get(soc.Sales_Order__c).add(soc.Challan__c);
        }
        
        Map<Id, String> challanStatusMap = new Map<Id, String>();
        for(Challan__c ch : [SELECT Id, Status__c FROM Challan__c WHERE Id IN :allChallanIds]){
            challanStatusMap.put(ch.Id, ch.Status__c);
        }
        
        if(String.isNotBlank(currentChallanStatus)){
            challanStatusMap.put(challanId, currentChallanStatus);
        }
        
        Set<Id> soWithPendingLineItems = new Set<Id>();
        for(Cart_Line_Item__c cli : [
            SELECT Id, Sales_Order__c 
            FROM Cart_Line_Item__c 
            WHERE Sales_Order__c IN :salesOrderIds AND Challan_Created__c = false
        ]){
            soWithPendingLineItems.add(cli.Sales_Order__c);
        }
        
        Set<String> pickingOrAboveStatuses = new Set<String>{
            'picking in progress',
                'ready for packer',
                'packing in progress',
                'packing completed/invoice pending'
                };
                    
                    List<Sales_Order__c> salesOrdersList = [
                        SELECT Id, Status__c 
                        FROM Sales_Order__c 
                        WHERE Id IN :salesOrderIds
                    ];
        
        List<Sales_Order__c> salesOrderToUpdate = new List<Sales_Order__c>();
        
        for(Sales_Order__c so : salesOrdersList){
            if(!soWithPendingLineItems.contains(so.Id) && soToChallanIdsMap.containsKey(so.Id)){
                Set<Id> chIds = soToChallanIdsMap.get(so.Id);
                
                Boolean allPackingCompleted = true;
                Boolean allPickingInProgressOrAbove = true;
                
                for(Id chId : chIds){
                    String st = challanStatusMap.get(chId);
                    String stLower = (st != null) ? st.trim().toLowerCase() : '';
                    
                    if(stLower != 'packing completed/invoice pending'){
                        allPackingCompleted = false;
                    }
                    
                    if(!pickingOrAboveStatuses.contains(stLower)){
                        allPickingInProgressOrAbove = false;
                    }
                }
                
                if(allPackingCompleted){
                    if(so.Status__c != 'Shipment Ready'){
                        so.Status__c = 'Shipment Ready';
                        salesOrderToUpdate.add(so);
                    }
                } else if(allPickingInProgressOrAbove){
                    if(so.Status__c != 'Packing In Progress'){
                        so.Status__c = 'Packing In Progress';
                        salesOrderToUpdate.add(so);
                    }
                }
            }
        }
        
        if(!salesOrderToUpdate.isEmpty()){
            update salesOrderToUpdate;
            return salesOrderToUpdate;
        }
        
        return new List<Sales_Order__c>();
    }
    
    @AuraEnabled
    public static void assignChallanToStation(Id challanId, Id stationUserId){
        List<Challan__c> challanlstRec = [SELECT Name, Id, Status__c FROM Challan__c WHERE Id = :challanId LIMIT 1];
        
        if(!challanlstRec.isEmpty()){
            List<CustomNotificationType> notifTypes = [
                SELECT Id 
                FROM CustomNotificationType 
                WHERE DeveloperName = 'Assignee_Challan_To_Station' 
                LIMIT 1
            ];
            
            if(!notifTypes.isEmpty()){
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle('Challan Assigned: ' + challanlstRec[0].Name);
                notification.setBody('Challan ' + challanlstRec[0].Name + ' has been assigned to you. Current Status: ' + challanlstRec[0].Status__c + '.');
                notification.setNotificationTypeId(notifTypes[0].Id);
                notification.setTargetId(challanlstRec[0].Id);
                
                try {
                    notification.send(new Set<String>{ String.valueOf(stationUserId) });
                } catch (Exception ex) {
                    System.debug('Error sending custom notification: ' + ex.getMessage());
                }
            }
            
            if(!challanlstRec.isEmpty() && stationUserId != null){
                challanlstRec[0].OwnerId = stationUserId;
                update challanlstRec;
            }
        }
    }
    
    @AuraEnabled
    public static void updateInvoiceReadyforDispatch(Id contentDocumentId, Id challanId) {
        List<User> wareHosueTeamUserlstRec = [SELECT Id FROM User WHERE User_Profile_Name__c = 'Warehouse Team' AND IsActive = true LIMIT 1];
        List<Challan__c> challanlstRec = [SELECT Id, Name, Status__c, OwnerId FROM Challan__c WHERE Id = :challanId LIMIT 1];
        if(!challanlstRec.isEmpty() && challanlstRec[0].Status__c == 'Packing Completed/Invoice Pending'){
            challanlstRec[0].Status__c = 'Invoiced/Ready For Dispatch';
            if(!wareHosueTeamUserlstRec.isEmpty()){
                challanlstRec[0].OwnerId = wareHosueTeamUserlstRec[0].Id;
            }
            update challanlstRec;
            
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Challan Assigned: ' + challanlstRec[0].Name);
            notification.setBody('Challan ' + challanlstRec[0].Name + ' has been assigned to you. Current Status: ' + challanlstRec[0].Status__c + '.');
            notification.setNotificationTypeId(System.Label.Assignee_Challan_To_WareHosue_Team_Before_Dispatch);
            notification.setTargetId(challanlstRec[0].Id);
            
            try {
                notification.send(new Set<String>{ String.valueOf(wareHosueTeamUserlstRec[0].Id) });
            } catch (Exception ex) {
                System.debug('Error sending custom notification: ' + ex.getMessage());
            }

        }
        List<ContentVersion> latestVersionList = [
            SELECT Id, Type__c 
            FROM ContentVersion 
            WHERE ContentDocumentId = :contentDocumentId 
            AND IsLatest = true 
            LIMIT 1
        ];
        if (!latestVersionList.isEmpty()) {
            latestVersionList[0].Type__c = 'Invoice';
            update latestVersionList[0];
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<User> fetchLogisticsUser(){
        return [SELECT Id FROM User WHERE User_Profile_Name__c = 'Logistics Team Manager' AND IsActive = true LIMIT 1];
    }
    
    @AuraEnabled
    public static List<Delivery_Detail__c> fetchDeliveryRecord(String challanId){
        try {
            return [SELECT Id FROM Delivery_Detail__c WHERE Challan__c = :challanId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void notifyAccountsForInvoice(String challanId){
        try {
            List<Group> lstQueue = [
                SELECT Id FROM Group
                WHERE Type = 'Queue' AND DeveloperName = 'Accounts_Team'
                LIMIT 1
            ];
            if (lstQueue.isEmpty()) {
                lstQueue = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name = 'Accounts Team' LIMIT 1];
            }
            Challan__c challanRec = new Challan__c(Id = challanId, OwnerId = lstQueue[0].Id);
            UPDATE challanRec;
            
            List<Challan__c> lstChallan = [SELECT Id, Name FROM Challan__c WHERE Id = :challanId];
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Challan/Order Packed & Invoice Pending: ' + lstChallan[0].Name);
            notification.setBody('Challan ' + lstChallan[0].Name + ' has been packed and kindly generate and attach the invoice.');
            notification.setNotificationTypeId(label.Accounts_Invoice_Notification);
            notification.setTargetId(challanId);
            notification.send(new Set<String>{lstQueue[0].Id});
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}