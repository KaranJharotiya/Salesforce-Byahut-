public with sharing class CreateChallanController {
    
    public class InitDataWrapper {
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public String opportunityId { get; set; }
        @AuraEnabled public String opportunityName { get; set; }
        @AuraEnabled public List<Sales_Order__c> salesOrders { get; set; }
        @AuraEnabled public List<Cart_Line_Item__c> lineItems { get; set; }
    }
    
    @AuraEnabled
    public static InitDataWrapper getInitialData(List<Id> salesOrderIds) {
        
        Id currentUserId = UserInfo.getUserId();
        InitDataWrapper wrapper = new InitDataWrapper();
        if (salesOrderIds == null || salesOrderIds.isEmpty()) {
            wrapper.errorMessage = 'Please select at least one Sales Order from the list view.';
            return wrapper;
        }
        if(currentUserId != null){
            User user = [SELECT Id,User_Profile_Name__c FROM User WHERE Id =: currentUserId];
            if(user.User_Profile_Name__c != 'Operations Executive' && user.User_Profile_Name__c != 'Operations Team'  && user.User_Profile_Name__c != 'System Administrator' && user.User_Profile_Name__c != 'PT1'){
                wrapper.errorMessage = 'You do not have permission to create a Challan.';
                return wrapper;
            }
        }
        
        
        List<Sales_Order__c> salesOrders = [
            SELECT Id, Name, Status__c, Opportunity__c, Opportunity__r.Name
            FROM Sales_Order__c
            WHERE Id IN :salesOrderIds
        ];
        
        for (Sales_Order__c so : salesOrders) {
            if(so.Status__c != 'New'){
                wrapper.errorMessage = 'Select Only Status "New" Sales Order(s)';
                return wrapper;
            }
        }
        
        if (salesOrders.isEmpty()) {
            wrapper.errorMessage = 'No valid Sales Orders found for the selected records.';
            return wrapper;
        }
        
        Set<Id> opportunityIds = new Set<Id>();
        for (Sales_Order__c so : salesOrders) {
            if (so.Opportunity__c == null) {
                wrapper.errorMessage = 'Selected Sales Order (' + so.Name + ') does not have an Opportunity linked.';
                return wrapper;
            }
            opportunityIds.add(so.Opportunity__c);
            wrapper.opportunityName = so.Opportunity__r.Name;
        }
        
       
        
        if (opportunityIds.size() > 1) {
            wrapper.errorMessage = 'Error: ONLY SALES ORDERS FROM THE SAME OPPORTUNITY CAN BE SELECTED TO CREATE A CHALLAN.';
            return wrapper;
        }
        
        List<Cart_Line_Item__c> pendingLineItems = [
            SELECT Id, Name, Product__c, Product__r.Name, Quantity__c, 
            Sales_Order__c, Sales_Order__r.Name, Challan_Created__c,
            Total_Dispatch_Quantity__c, Total_Pending_Quantity__c
            FROM Cart_Line_Item__c
            WHERE Sales_Order__c IN :salesOrderIds 
            AND Challan_Created__c = false
        ];
        
        if(pendingLineItems.isEmpty()){
            wrapper.errorMessage = 'All Line Items for the selected Sales Order(s) already have Challans created.';
            return wrapper;
        }
        
        wrapper.opportunityId = (String)opportunityIds.iterator().next();
        wrapper.salesOrders = salesOrders;
        wrapper.lineItems = pendingLineItems;
        return wrapper;
    }
    
    @AuraEnabled
    public static String saveChallan(
        List<Id> salesOrderIds, 
        List<Id> selectedLineItemIds, 
        String opportunityId, 
        String wayOfTransit, 
        String address, 
        String specialInstructions
    ){
        try {
            if (String.isBlank(wayOfTransit)) {
                throw new AuraHandledException('Please select Way of Transit.');
            }
            if (selectedLineItemIds == null || selectedLineItemIds.isEmpty()) {
                throw new AuraHandledException('Please select at least one Line Item to create a Challan.');
            }
            
            List<User> wereHouseTeamUserlst = [SELECT Id FROM User WHERE User_Profile_Name__c = 'Warehouse Team' AND IsActive = true LIMIT 1];
            
            Challan__c newChallan = new Challan__c();
            newChallan.Opportunity__c = opportunityId;
            newChallan.Way_of_Transit__c = wayOfTransit;
            newChallan.Address__c = address;
            newChallan.Total_Items__c = String.valueOf(selectedLineItemIds.size());
            
            if (!wereHouseTeamUserlst.isEmpty()) {
                newChallan.OwnerId = wereHouseTeamUserlst[0].Id; 
            }
            insert newChallan;
            
            List<Cart_Line_Item__c> lineItemsToUpdate = [
                SELECT Id, Sales_Order__c, Quantity__c, Challan_Created__c,Total_Amount__c,Actual_Amount__c,
                Total_Dispatch_Quantity__c, Total_Pending_Quantity__c,GST__c,Discount__c
                FROM Cart_Line_Item__c 
                WHERE Id IN :selectedLineItemIds
            ];
            
            Map<Id, Sales_Order_Challan__c> soToChallanMap = new Map<Id, Sales_Order_Challan__c>();
            
            for (Cart_Line_Item__c cli : lineItemsToUpdate) {
                cli.Challan_Created__c = true;
                cli.Challan__c = newChallan.Id;
                if (!soToChallanMap.containsKey(cli.Sales_Order__c)) {
                    soToChallanMap.put(cli.Sales_Order__c, new Sales_Order_Challan__c(
                        Sales_Order__c = cli.Sales_Order__c,
                        Challan__c = newChallan.Id,
                        Quantity__c = 0,
                        Total_Dispatch_Quantity__c = 0,
                        Total_Pending_Quantity__c = 0,
                        Actual_Amount__c = 0,
                        Ordered_Amount__c = 0,
                        Total_Discount__c = 0,
                        Total_GST__c = 0
                    ));
                }
                
                Sales_Order_Challan__c currentSOC = soToChallanMap.get(cli.Sales_Order__c);
                if (cli.Quantity__c != null) {
                    currentSOC.Quantity__c += cli.Quantity__c;
                }
                if (cli.Total_Dispatch_Quantity__c != null) {
                    currentSOC.Total_Dispatch_Quantity__c += cli.Total_Dispatch_Quantity__c;
                }
                if (cli.Total_Pending_Quantity__c != null) {
                    currentSOC.Total_Pending_Quantity__c += cli.Total_Pending_Quantity__c;
                }
            }
            
            Database.update(lineItemsToUpdate, AccessLevel.SYSTEM_MODE);
           
            if(!lineItemsToUpdate.IsEmpty()){
                Decimal totalActualAmount = 0;
                Decimal totalOrderedAmount = 0;
                Decimal totalGst = 0;
                Decimal totalDis = 0;
                for(Cart_Line_Item__c soOrderItem : lineItemsToUpdate){
                    Sales_Order_Challan__c currentSOC = soToChallanMap.get(soOrderItem.Sales_Order__c);
                    if(soOrderItem.Challan__c == newChallan.Id){
                        totalActualAmount += soOrderItem.Actual_Amount__c != null 
                            ? soOrderItem.Actual_Amount__c : 0;
                        
                        totalOrderedAmount += soOrderItem.Total_Amount__c != null 
                            ? soOrderItem.Total_Amount__c : 0;
                        
                        totalDis += soOrderItem.Discount__c != null 
                            ? soOrderItem.Discount__c : 0;
                        
                        totalGst += soOrderItem.GST__c != null 
                            ? soOrderItem.GST__c : 0;
                    }
                    
                    currentSOC.Ordered_Amount__c += soOrderItem.Total_Amount__c != null 
                        ? soOrderItem.Total_Amount__c : 0;
                    
                    currentSOC.Actual_Amount__c += soOrderItem.Actual_Amount__c != null 
                        ? soOrderItem.Actual_Amount__c : 0;
                    
                    currentSOC.Total_Discount__c += soOrderItem.Discount__c != null 
                        ? soOrderItem.Discount__c : 0;
                    
                    currentSOC.Total_GST__c += soOrderItem.GST__c != null 
                        ? soOrderItem.GST__c : 0;
                }
                
                Challan__c  toUpdateChallan = new Challan__c(
                    Id = newChallan.Id,
                    Total_Ordered_Amount__c = totalOrderedAmount,
                    Total_Actual_Amount__c = totalActualAmount,
                    Total_GST__c = totalGst,
                    Total_Discount__c = totalDis
                );
                
                if(toUpdateChallan != null){
                    update toUpdateChallan;
                }
            }

            if (!soToChallanMap.isEmpty()) {
                insert soToChallanMap.values();
            }
            
            List<Cart_Line_Item__c> remainingUncreatedItems = [
                SELECT Id, Sales_Order__c 
                FROM Cart_Line_Item__c 
                WHERE Sales_Order__c IN :salesOrderIds 
                AND Challan_Created__c = false
            ];
            
            Set<Id> soWithPendingItems = new Set<Id>();
            for (Cart_Line_Item__c cli : remainingUncreatedItems) {
                soWithPendingItems.add(cli.Sales_Order__c);
            }
            
            List<Sales_Order__c> soToUpdate = new List<Sales_Order__c>();
            
            for (Id soId : salesOrderIds) {
                if (!soWithPendingItems.contains(soId)) {
                    soToUpdate.add(new Sales_Order__c(
                        Id = soId,
                        Special_Instructions__c = specialInstructions,
                        Status__c = 'Challan Created'
                    ));
                } else if (String.isNotBlank(specialInstructions)) {
                    soToUpdate.add(new Sales_Order__c(
                        Id = soId,
                        Special_Instructions__c = specialInstructions
                    ));
                }
            }
            
            if (!soToUpdate.isEmpty()) {
                update soToUpdate;
            }

            if (!wereHouseTeamUserlst.isEmpty()) {
               /* List<CustomNotificationType> notifTypes = [
                    SELECT Id, DeveloperName 
                    FROM CustomNotificationType 
                    WHERE DeveloperName = 'Werehouse_Team_Challan_Creation' 
                    LIMIT 1
                ];*/
               // if (!notifTypes.isEmpty()) {
                    Challan__c currentChallan = [SELECT Id, Name FROM Challan__c WHERE Id = :newChallan.Id LIMIT 1];
                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    notification.setTitle('New Challan Assigned');
                    notification.setBody(
                        'A new Challan ' + currentChallan.Name + 
                        ' has been created and assigned to the Warehouse Team.'
                    );
                    //notification.setNotificationTypeId(notifTypes[0].Id);
                    notification.setNotificationTypeId(label.Werehouse_Team_Challan_Creation);
                    notification.setTargetId(newChallan.Id);
                    
                    try {
                        notification.send(new Set<String>{ wereHouseTeamUserlst[0].Id });
                    } catch (Exception e) {
                        System.debug('Warehouse Problem sending notification: ' + e.getMessage());
                    }
               // }
            }
            
            return newChallan.Id;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    
}