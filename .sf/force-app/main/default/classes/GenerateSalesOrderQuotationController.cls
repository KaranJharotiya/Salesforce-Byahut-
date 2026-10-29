public without sharing class GenerateSalesOrderQuotationController {
    
    // Wrapper to hold Quotation and its Line Items
    public class QuotationWrapper {
        @AuraEnabled public Quotation__c quotation { get; set; }
        @AuraEnabled public List<QuotationLineItemWrapper> lineItems { get; set; }
    }

    public class QuotationLineItemWrapper {
        @AuraEnabled public Quotation_Line_Items__c item { get; set; }
        @AuraEnabled public Integer index { get; set; }
        @AuraEnabled public Boolean isSelected { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal discount { get; set; }
        @AuraEnabled public Decimal gst { get; set; }
        @AuraEnabled public Decimal price { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Decimal discountAmount { get; set; }
        @AuraEnabled public Decimal afterDiscount { get; set; }
        @AuraEnabled public Decimal gstAmount { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }

        // Flattened fields for table display
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String industry { get; set; }
        @AuraEnabled public String casNumber { get; set; }
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public String brandName { get; set; }
        @AuraEnabled public String subBrandName { get; set; }
        @AuraEnabled public String categoryName { get; set; }
        @AuraEnabled public String subCategoryName { get; set; }
        @AuraEnabled public Decimal stock { get; set; }
         @AuraEnabled public Decimal holdQuantity { get; set; }
         @AuraEnabled public Decimal availableQuantity { get; set; }
    }

    // Payload Wrapper for Deserialization
    public class CartItemPayload {
        public Id productId;
        public Decimal quantity;
        public Decimal discount;
        public Decimal gst;
        public Decimal amount;
        public Date promiseDate;
        public String priority;
    }

    @AuraEnabled(cacheable=true)
    public static List<QuotationWrapper> getQuotationsWithItems(Id opportunityId) {
        List<QuotationWrapper> wrapperList = new List<QuotationWrapper>();

        List<Quotation__c> quotes = [
            SELECT Id, Name, Status__c,
                   (SELECT Id, Name, Product__c, Product__r.Name, 
                           Product__r.Industry__c, Product__r.CAS_Number__c, Product__r.Code__c,
                           Product__r.Brand__r.Name, Product__r.Sub_Brand__r.Name, 
                           Product__r.Category__r.Name, Product__r.Sub_Category__r.Name, 
                           Product__r.Stock__c,Product__r.Available_Quantity__c,Product__r.Hold_Quantity__c, Product__r.List_Price__c,
                           Quantity__c, Amount__c, Discount__c, GST__c, After_Discount__c, 
                           Final_Amount__c, Total_Amount__c 
                    FROM Quotation_Line_Items__r)
            FROM Quotation__c
            WHERE Opportunity__c = :opportunityId AND Status__c = 'Quote'
            ORDER BY CreatedDate DESC
        ];

        for (Quotation__c q : quotes) {
            QuotationWrapper qw = new QuotationWrapper();
            qw.quotation = q;
            qw.lineItems = new List<QuotationLineItemWrapper>();

            if (q.Quotation_Line_Items__r != null) {
                Integer sNo = 1;
                for (Quotation_Line_Items__c qli : q.Quotation_Line_Items__r) {
                    QuotationLineItemWrapper itemWrap = new QuotationLineItemWrapper();
                    itemWrap.item = qli;
                    itemWrap.index = sNo++;
                    itemWrap.isSelected = false;
                    itemWrap.quantity = qli.Quantity__c != null ? qli.Quantity__c : 1;
                    itemWrap.discount = qli.Discount__c != null ? qli.Discount__c : 0;
                    itemWrap.gst = qli.GST__c != null ? qli.GST__c : 0;
                    itemWrap.price = qli.Product__r.List_Price__c != null ? qli.Product__r.List_Price__c : (qli.Amount__c != null ? qli.Amount__c : 0);

                    // Map flattened display fields
                    if (qli.Product__r != null) {
                        itemWrap.productName = qli.Product__r.Name;
                        itemWrap.industry = qli.Product__r.Industry__c;
                        itemWrap.casNumber = qli.Product__r.CAS_Number__c;
                        itemWrap.productCode = qli.Product__r.Code__c != null ? qli.Product__r.Code__c : null;
                        itemWrap.brandName = qli.Product__r.Brand__r != null ? qli.Product__r.Brand__r.Name : '';
                        itemWrap.subBrandName = qli.Product__r.Sub_Brand__r != null ? qli.Product__r.Sub_Brand__r.Name : '';
                        itemWrap.categoryName = qli.Product__r.Category__r != null ? qli.Product__r.Category__r.Name : '';
                        itemWrap.subCategoryName = qli.Product__r.Sub_Category__r != null ? qli.Product__r.Sub_Category__r.Name : '';
                        itemWrap.stock = qli.Product__r.Stock__c != null ? qli.Product__r.Stock__c : 0;
                        itemWrap.holdQuantity = qli.Product__r.Hold_Quantity__c != null ? qli.Product__r.Hold_Quantity__c : 0;
                        itemWrap.availableQuantity = qli.Product__r.Available_Quantity__c != null ? qli.Product__r.Available_Quantity__c : 0;
                    }
                    
                    // Calculations
                    Decimal amt = itemWrap.price * itemWrap.quantity;
                    Decimal discAmt = (amt * itemWrap.discount) / 100;
                    Decimal afterDisc = amt - discAmt;
                    Decimal gstAmt = (afterDisc * itemWrap.gst) / 100;
                    Decimal totAmt = afterDisc + gstAmt;

                    itemWrap.amount = amt.setScale(2);
                    itemWrap.discountAmount = discAmt.setScale(2);
                    itemWrap.afterDiscount = afterDisc.setScale(2);
                    itemWrap.gstAmount = gstAmt.setScale(2);
                    itemWrap.totalAmount = totAmt.setScale(2);

                    qw.lineItems.add(itemWrap);
                }
            }
            wrapperList.add(qw);
        }
        return wrapperList;
    }
    
    @AuraEnabled
    public static Id saveSalesOrderRec(String strsalesOrderRec, String selectedQuotationId, String strSelectedLineItems, Id OpportunityId) {
        List<User> operationProfileUsers = new List<User>();
        String profileName;
        if (Schema.sObjectType.Profile.isAccessible()){
            operationProfileUsers = [SELECT Id, Name, Email FROM User WHERE Profile.Name = 'Operations Team' AND IsActive = true LIMIT 1];
        }else{
            operationProfileUsers = [SELECT Id, Name, Email FROM User WHERE User_Profile_Name__c = 'Operations Team' AND IsActive = true LIMIT 1];
        }

        // 1. Insert Sales Order
        Sales_Order__c salesOrderRec = (Sales_Order__c) JSON.deserialize(strsalesOrderRec, Sales_Order__c.class);
        salesOrderRec.Opportunity__c = OpportunityId;
        salesOrderRec.OwnerId = operationProfileUsers[0].Id;
        salesOrderRec.Sales_Order_Date__c = DateTime.now();
        Opportunity__c opportunity = [SELECT Id, Status__c FROM Opportunity__c WHERE Id = :OpportunityId LIMIT 1];
        opportunity.Status__c = 'Sales Order';
        update opportunity;
        
        insert salesOrderRec;

        // 2. Update Quotations Status (only if a quotation was selected)
        if (String.isNotBlank(selectedQuotationId)) {
            List<Quotation__c> allQuotes = [SELECT Id, Status__c FROM Quotation__c WHERE Opportunity__c = :OpportunityId];
            List<Quotation__c> quotesToUpdate = new List<Quotation__c>();
            for (Quotation__c q : allQuotes) {
                if (q.Id == selectedQuotationId) {
                    q.Status__c = 'Ordered';
                } else if(q.Status__c == 'Quote') {
                    q.Status__c = 'Discarded';
                }
                quotesToUpdate.add(q);
            }
            if (!quotesToUpdate.isEmpty()) {
                update quotesToUpdate;
            }
        }

        // 3. Create Cart_Line_Item__c records (if line items exist)
        if (String.isNotBlank(strSelectedLineItems)) {
            List<CartItemPayload> selectedItems = (List<CartItemPayload>) JSON.deserialize(strSelectedLineItems, List<CartItemPayload>.class);
            List<Cart_Line_Item__c> cartItemsToInsert = new List<Cart_Line_Item__c>();

            if (selectedItems != null) {
                for (CartItemPayload itemPayload : selectedItems) {
                    Cart_Line_Item__c cartItem = new Cart_Line_Item__c();
                    cartItem.Sales_Order__c = salesOrderRec.Id;
                    cartItem.Opportunity__c = OpportunityId;
                    cartItem.Product__c = itemPayload.productId;
                    cartItem.Quantity__c = itemPayload.quantity;
                    cartItem.Discount__c = itemPayload.discount;
                    cartItem.GST__c = itemPayload.gst;
                    cartItem.Amount__c = itemPayload.amount;
                    cartItem.Promise_Date__c = itemPayload.promiseDate;
                    cartItem.Priority__c = itemPayload.priority;
                    cartItemsToInsert.add(cartItem);
                }
            }

            if (!cartItemsToInsert.isEmpty()) {
                insert cartItemsToInsert;
            }
        }

        Sales_Order__c salesOrder = [
            SELECT Id, Name, Opportunity__r.Name, Sales_Order_Date__c, Delivery_Type__c, Special_Instructions__c, CreatedBy.Name
            FROM Sales_Order__c
            WHERE Id = :salesOrderRec.Id
            LIMIT 1
        ];
        
        if (!operationProfileUsers.isEmpty()) {
            List<CustomNotificationType> notifTypes = [
                SELECT Id, DeveloperName
                FROM CustomNotificationType
                WHERE DeveloperName = 'Sales_Order_Created_Operations_Team'
                LIMIT 1
            ];
            if (!notifTypes.isEmpty()) {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle('New Sales Order Created - ' + salesOrder.Name);
                notification.setBody(
                    'Sales Order ' + salesOrder.Name + ' has been created by ' + salesOrder.CreatedBy.Name +
                    ' and moved to the Operations Team for further actions.'
                );
                notification.setNotificationTypeId(notifTypes[0].Id);
                notification.setTargetId(salesOrder.Id);

                try {
                    notification.send(new Set<String>{ operationProfileUsers[0].Id });
                } catch (Exception e) {
                    System.debug('Operations Problem sending notification: ' + e.getMessage());
                }
            }
        }

      /*  if (!operationProfileUsers.isEmpty()) {
            List<OrgWideEmailAddress> oweaList = [
                SELECT Id, Address, DisplayName 
                FROM OrgWideEmailAddress 
                WHERE DisplayName = 'Byahut' 
                LIMIT 1
            ];
            
            String body = ''
                + 'Hello ' + operationProfileUsers[0].Name + ',\n\n'
                + 'A new Sales Order has been submitted successfully.\n\n'
                + 'Sales Order Details:\n'
                + '-----------------------------------\n'
                + 'Sales Order No : ' + salesOrder.Name + '\n'
                + 'Opportunity Name: ' + salesOrder.Opportunity__r.Name + '\n'
                + 'Order Date     : ' + String.valueOf(salesOrder.Sales_Order_Date__c) + '\n'
                + 'Dispatch Type  : ' + salesOrder.Delivery_Type__c + '\n\n'
                + 'Special Instructions  : ' + (salesOrder.Special_Instructions__c != null ? salesOrder.Special_Instructions__c : '') + '\n\n'
                + 'Required Action:\n'
                + '1. Please review the Sales Order.\n'
                + '2. Verify customer and pricing details.\n'
                + '3. Approve or process the order further.\n\n'
                + 'Thank you.\n'
                + 'Team';
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ operationProfileUsers[0].Email });
            mail.setSubject('Sales Order Submitted - ' + salesOrder.Name);
            mail.setPlainTextBody(body);
            if (!oweaList.isEmpty()) {
                mail.setOrgWideEmailAddressId(oweaList[0].Id);
            }
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } */



        return salesOrderRec.Id;
    }
}