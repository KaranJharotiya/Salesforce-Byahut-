public without sharing class EditSalesOrderController {

    // ==========================================
    // WRAPPER CLASSES
    // ==========================================
    public class LineItemWrapper {
        @AuraEnabled public Id lineItemId { get; set; }
        @AuraEnabled public Id id { get; set; } // Product Id
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String casNumber { get; set; }
        @AuraEnabled public Decimal listPrice { get; set; }
        @AuraEnabled public String industry { get; set; }
        @AuraEnabled public Decimal stock { get; set; }
        @AuraEnabled public Decimal holdQuantity { get; set; }
        @AuraEnabled public Decimal availableQuantity { get; set; }
        @AuraEnabled public String code { get; set; }
        @AuraEnabled public Id brandId { get; set; }
        @AuraEnabled public String brandName { get; set; }
        @AuraEnabled public Id subBrandId { get; set; }
        @AuraEnabled public String subBrandName { get; set; }
        @AuraEnabled public Id categoryId { get; set; }
        @AuraEnabled public String categoryName { get; set; }
        @AuraEnabled public Id subCategoryId { get; set; }
        @AuraEnabled public String subCategoryName { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal discount { get; set; }
        @AuraEnabled public Decimal gst { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public Date promiseDispatchDate { get; set; }
    }

    // ==========================================
    // 1. GET CURRENT SALES ORDER DETAILS
    // ==========================================
    @AuraEnabled(cacheable=false)
    public static Sales_Order__c getCurrentSalesOrder(Id salesOrderId) {
        if (salesOrderId == null) return null;
        return [
            SELECT Id, Name, Sales_Order_Date__c, Customer_Purchase_Order_No__c, Opportunity__c
            FROM Sales_Order__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];
    }

    // ==========================================
    // 2. GET EXISTING SALES ORDER CART LINE ITEMS
    // ==========================================
    @AuraEnabled(cacheable=false)
    public static List<LineItemWrapper> getExistingSalesOrderProducts(Id salesOrderId) {
        List<LineItemWrapper> result = new List<LineItemWrapper>();
        if (salesOrderId == null) return result;

        List<Cart_Line_Item__c> items = [
            SELECT Id, Product__c, Product__r.Name, Product__r.CAS_Number__c, Product__r.Code__c,
                   Product__r.Industry__c, Product__r.Stock__c, Product__r.Hold_Quantity__c, 
                   Product__r.Available_Quantity__c, Product__r.List_Price__c,
                   Product__r.Brand__c, Product__r.Brand__r.Name,
                   Product__r.Sub_Brand__c, Product__r.Sub_Brand__r.Name,
                   Product__r.Category__c, Product__r.Category__r.Name,
                   Product__r.Sub_Category__c, Product__r.Sub_Category__r.Name,
                   Amount__c, Quantity__c, Discount__c, GST__c, Priority__c, Promise_Date__c
            FROM Cart_Line_Item__c
            WHERE Sales_Order__c = :salesOrderId AND Product__c != null
        ];

        for (Cart_Line_Item__c cli : items) {
            LineItemWrapper wrap = new LineItemWrapper();
            wrap.lineItemId = cli.Id;
            wrap.id = cli.Product__c;
            wrap.name = cli.Product__r != null ? cli.Product__r.Name : '';
            wrap.casNumber = cli.Product__r != null ? cli.Product__r.CAS_Number__c : '';
            wrap.code = cli.Product__r != null ? cli.Product__r.Code__c : '';
            wrap.industry = cli.Product__r != null ? cli.Product__r.Industry__c : '';
            wrap.stock = cli.Product__r != null ? cli.Product__r.Stock__c : 0;
            wrap.holdQuantity = cli.Product__r != null ? cli.Product__r.Hold_Quantity__c : 0;
            wrap.availableQuantity = cli.Product__r != null ? cli.Product__r.Available_Quantity__c : 0;
            wrap.listPrice = cli.Amount__c != null ? cli.Amount__c : (cli.Product__r != null ? cli.Product__r.List_Price__c : 0);
            wrap.brandId = cli.Product__r != null ? cli.Product__r.Brand__c : null;
            wrap.brandName = cli.Product__r?.Brand__r != null ? cli.Product__r.Brand__r.Name : '';
            wrap.subBrandId = cli.Product__r != null ? cli.Product__r.Sub_Brand__c : null;
            wrap.subBrandName = cli.Product__r?.Sub_Brand__r != null ? cli.Product__r.Sub_Brand__r.Name : '';
            wrap.categoryId = cli.Product__r != null ? cli.Product__r.Category__c : null;
            wrap.categoryName = cli.Product__r?.Category__r != null ? cli.Product__r.Category__r.Name : '';
            wrap.subCategoryId = cli.Product__r != null ? cli.Product__r.Sub_Category__c : null;
            wrap.subCategoryName = cli.Product__r?.Sub_Category__r != null ? cli.Product__r.Sub_Category__r.Name : '';
            wrap.quantity = cli.Quantity__c;
            wrap.discount = cli.Discount__c;
            wrap.gst = cli.GST__c;
            wrap.priority = cli.Priority__c;
            wrap.promiseDispatchDate = cli.Promise_Date__c;
            result.add(wrap);
        }
        return result;
    }

    // ==========================================
    // 3. GET INDUSTRY PICKLIST VALUES
    // ==========================================
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getIndustryValues() {
        List<Map<String, String>> valuesMap = new List<Map<String, String>>();
        valuesMap.add(new Map<String, String>{
            'label' => '--None--',
            'value' => ''
        });

        Schema.DescribeFieldResult fieldResult = Product__c.Industry__c.getDescribe();
        for (Schema.PicklistEntry pe : fieldResult.getPicklistValues()) {
            if (pe.isActive()) {
                valuesMap.add(new Map<String, String>{
                    'label' => pe.getLabel(),
                    'value' => pe.getValue()
                });
            }
        }
        return valuesMap;
    }

    // ==========================================
    // 4. SEARCH PRODUCTS BY FILTERS
    // ==========================================
    @AuraEnabled
    public static List<Product__c> getSearchedProducts(String productName, String productCASNumber, String productBrand, String productCode, String productIndustry) {
        try {
            String query = 'SELECT Id, Name, CAS_Number__c, List_Price__c, Industry__c, Stock__c, Available_Quantity__c, Hold_Quantity__c, Code__c, ' +
                           'Category__r.Name, Sub_Category__r.Name, Brand__r.Name, Sub_Brand__r.Name ' +
                           'FROM Product__c WHERE ';

            List<String> conditions = new List<String>();

            if (String.isNotBlank(productName)) {
                conditions.add('Id = \'' + String.escapeSingleQuotes(productName) + '\'');
            }
            if (String.isNotBlank(productCASNumber)) {
                conditions.add('Id = \'' + String.escapeSingleQuotes(productCASNumber) + '\'');
            }
            if (String.isNotBlank(productBrand)) {
                conditions.add('Brand__c = \'' + String.escapeSingleQuotes(productBrand) + '\'');
            }
            if (String.isNotBlank(productCode)) {
                conditions.add('Id = \'' + String.escapeSingleQuotes(productCode) + '\'');
            }
            if (String.isNotBlank(productIndustry)) {
                conditions.add('Industry__c INCLUDES (\'' + String.escapeSingleQuotes(productIndustry) + '\')');
            }

            if (conditions.isEmpty()) {
                return new List<Product__c>();
            }

            query += String.join(conditions, ' AND ');
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ==========================================
    // 5. GET SUGGESTED PRODUCTS
    // ==========================================
    @AuraEnabled
    public static List<Suggested_Product__c> getSuggestedProduct(List<String> productIds) {
        if (productIds == null || productIds.isEmpty()) return new List<Suggested_Product__c>();
        Set<String> productIdSet = new Set<String>(productIds);
        return [
            SELECT Id, Product__c, Product__r.Name, Product__r.CAS_Number__c, Product__r.List_Price__c, 
                   Product__r.Industry__c, Product__r.Stock__c, Product__r.Hold_Quantity__c, 
                   Product__r.Available_Quantity__c, Product__r.Code__c, Product__r.Category__r.Name,
                   Product__r.Sub_Category__r.Name, Product__r.Brand__r.Name, Product__r.Sub_Brand__r.Name
            FROM Suggested_Product__c 
            WHERE Parent__c IN :productIdSet
        ];
    }

    // ==========================================
    // 6. UPSERT CART LINE ITEMS FOR SALES ORDER
    // ==========================================
    @AuraEnabled
    public static String upsertSalesOrderLineItems(Id salesOrderId, List<Cart_Line_Item__c> lineItems) {
        try {
            if (salesOrderId == null) {
                throw new AuraHandledException('Sales Order Id cannot be null');
            }

            Sales_Order__c so = [SELECT Id, Opportunity__c FROM Sales_Order__c WHERE Id = :salesOrderId LIMIT 1];

            Map<Id, Cart_Line_Item__c> existingItemsMap = new Map<Id, Cart_Line_Item__c>([
                SELECT Id FROM Cart_Line_Item__c WHERE Sales_Order__c = :salesOrderId
            ]);

            List<Cart_Line_Item__c> itemsToUpsert = new List<Cart_Line_Item__c>();
            Set<Id> currentRetainedLineItemIds = new Set<Id>();

            if (lineItems != null) {
                for (Cart_Line_Item__c item : lineItems) {
                    if (item.Id == null) {
                        item.Sales_Order__c = salesOrderId;
                        if (so.Opportunity__c != null) {
                            item.Opportunity__c = so.Opportunity__c;
                        }
                    } else {
                        currentRetainedLineItemIds.add(item.Id);
                    }
                    itemsToUpsert.add(item);
                }
            }

            List<Cart_Line_Item__c> itemsToDelete = new List<Cart_Line_Item__c>();
            for (Id existingId : existingItemsMap.keySet()) {
                if (!currentRetainedLineItemIds.contains(existingId)) {
                    itemsToDelete.add(existingItemsMap.get(existingId));
                }
            }

            if (!itemsToDelete.isEmpty()) {
                delete itemsToDelete;
            }
            if (!itemsToUpsert.isEmpty()) {
                upsert itemsToUpsert;
            }

            return 'Sales Order Items updated successfully!';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ==========================================
    // 7. UPDATE SALES ORDER HEADER DATA
    // ==========================================
    @AuraEnabled
    public static void updateSalesOrderData(Id recordId, String customerPurchaseOrderNo, Date salesOrderDate, Boolean isDateChanged) {
        try {
            Sales_Order__c so = new Sales_Order__c(
                Id = recordId,
                Customer_Purchase_Order_No__c = customerPurchaseOrderNo
            );

            // Sales Order Date sirf tabhi update hogi agar user ne UI par date change ki ho
            if (isDateChanged == true) {
                if (salesOrderDate != null) {
                    Time currentTime = DateTime.now().time();
                    so.Sales_Order_Date__c = DateTime.newInstance(salesOrderDate, currentTime);
                } else {
                    so.Sales_Order_Date__c = null;
                }
            }

            update so;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}