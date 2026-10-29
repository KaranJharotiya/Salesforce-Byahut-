public class SalesOrderEditLineItemController {
    
    
    @AuraEnabled
    public static List<Product__c> getSearchedProducts(String productName, String productCASNumber, String productBrand, String productCode, String productIndustry) {
        try {
            String query = 'SELECT Id, Name, CAS_Number__c, List_Price__c, Industry__c, Stock__c, Code__c, Category__r.Name, '+
                ' Sub_Category__r.Name, Brand__r.Name, Sub_Brand__r.Name ' +
                ' FROM Product__c WHERE';
            
            if(!String.isBlank(productName)){
                query += ' name = \'' + String.escapeSingleQuotes(productName) + '\'';
            }
            if(!String.isBlank(productCASNumber)){
                if(!query.endsWith('WHERE')){
                    query += ' OR ';
                }
                query += ' CAS_Number__c = \'' + String.escapeSingleQuotes(productCASNumber) + '\'';
            }
            
            if(!String.isBlank(productBrand)){
                if(!query.endsWith('WHERE')){
                    query += ' OR ';
                }
                query += ' Brand__c = \'' + String.escapeSingleQuotes(productBrand) + '\'';
            }
            
            if(!String.isBlank(productCode)){
                if(!query.endsWith('WHERE')){
                    query += ' OR ';
                }
                query += ' Code__c = \'' + String.escapeSingleQuotes(productCode) + '\'';
            }
            
            if(!String.isBlank(productIndustry)){
                if(!query.endsWith('WHERE')){
                    query += ' OR ';
                }
                query += ' Industry__c INCLUDES (\'' + String.escapeSingleQuotes(productIndustry) + '\')';
            }
            
            if(query.endsWith('WHERE')){
                query = query.removeEnd('WHERE');
            }
            
            System.debug('query >> ' + query);
            
            return Database.query(query);
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
	public static void updateSalesOrderData(String recordId,String customerPurchaseOrderNo, string salesOrderDate)
    {
        
        try{
            Sales_order__c salesOrder = [select id,Sales_Order_Date__c,Customer_Purchase_Order_No__c from sales_order__c where id =: recordId limit 1];
            salesOrder.Sales_Order_Date__c = Date.valueOf(salesOrderDate);
            salesOrder.Customer_Purchase_Order_No__c = customerPurchaseOrderNo;
            update salesOrder;
        }catch(Exception e)
        {
            System.debug(e);
        }
    }
    
    
    @AuraEnabled
    public static String upsertSalesOrderLineItems(
        Id salesOrderId,
        List<Cart_Line_Item__c> lineItems
    ) {
        try {
            System.debug('upsertSalesOrderLineItems called in apex');
            if(salesOrderId == null) {
                throw new AuraHandledException('Sales Order Id cannot be null');
            }
            
            Map<Id, Cart_Line_Item__c> existingItemsMap = new Map<Id, Cart_Line_Item__c>([
                SELECT Id FROM Cart_Line_Item__c WHERE sales_order__c = :salesOrderId
            ]);
            
            List<Cart_Line_Item__c> itemsToUpsert = new List<Cart_Line_Item__c>();
            Set<Id> currentRetainedLineItemIds = new Set<Id>();
            
            for (Cart_Line_Item__c item : lineItems) {
                if (item.Id == null) {
                    item.sales_order__c = salesOrderId;
                } else {
                    currentRetainedLineItemIds.add(item.Id);
                }
                itemsToUpsert.add(item);
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
            
            return 'Sales order upserted successfully!';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static sales_order__c getCurrentSalesOrder(String salesOrderId)
    {
        sales_order__c salesOrder = new sales_order__c();
        if(salesOrderId == null || salesOrderId == '')
            return salesOrder;
        
        return [select id,Sales_Order_Date__c,Customer_Purchase_Order_No__c 
                from sales_order__c where id = :salesOrderId limit 1];
        
    }
    
    @AuraEnabled
    public static List<ProductWrapper> getExistingSalesOrderProducts(Id salesOrderId) {
        System.debug('salesOrderId : '+salesOrderId);
        List<ProductWrapper> result = new List<ProductWrapper>();
        if (salesOrderId == null) return result;
        
        Set<Id> productIds = new Set<Id>();
        Map<Id, Cart_Line_Item__c> prodToLineItemMap = new Map<Id, Cart_Line_Item__c>();
        
        for (Cart_Line_Item__c soli : [
            SELECT Id, Product__c, Quantity__c, Discount__c, GST__c,Amount__c,Priority__c,Promise_Date__c
            FROM Cart_Line_Item__c 
            WHERE Sales_Order__c = :salesOrderId AND Product__c != null
        ]) {
            productIds.add(soli.Product__c);
            prodToLineItemMap.put(soli.Product__c, soli);
        }
        
        System.debug('productIds : '+productIds);
        if (productIds.isEmpty()) return result;
        
        List<Product__c> prodList = [
            SELECT Id, Name, CAS_Number__c, List_Price__c, Industry__c, Stock__c, Code__c, 
            Brand__c, Brand__r.Name, 
            Sub_Brand__c, Sub_Brand__r.Name, 
            Category__c, Category__r.Name, 
            Sub_Category__c, Sub_Category__r.Name 
            FROM Product__c 
            WHERE Id IN :productIds
        ];
        
        System.debug('prodList : '+prodList);
        
        for (Product__c prod : prodList) {
            Cart_Line_Item__c soli = prodToLineItemMap.get(prod.Id);
            
            ProductWrapper wrap = new ProductWrapper();
            wrap.lineItemId = soli.Id;
            wrap.id = prod.Id;
            wrap.name = prod.Name;
            wrap.casNumber = prod.CAS_Number__c;
            wrap.listPrice = soli.Amount__c;
            wrap.industry = prod.Industry__c;
            wrap.stock = prod.Stock__c;
            wrap.code = prod.Code__c;
            
            wrap.brandId = prod.Brand__c;
            wrap.brandName = prod.Brand__r != null ? prod.Brand__r.Name : '';
            
            wrap.subBrandId = prod.Sub_Brand__c;
            wrap.subBrandName = prod.Sub_Brand__r != null ? prod.Sub_Brand__r.Name : '';
            
            wrap.categoryId = prod.Category__c;
            wrap.categoryName = prod.Category__r != null ? prod.Category__r.Name : '';
            
            wrap.subCategoryId = prod.Sub_Category__c;
            wrap.subCategoryName = prod.Sub_Category__r != null ? prod.Sub_Category__r.Name : '';
            
            wrap.quantity = soli.Quantity__c;
            wrap.discount = soli.Discount__c;
            wrap.gst = soli.GST__c;
            wrap.promiseDispatchDate = soli.Promise_Date__c;
            wrap.priority = soli.Priority__c;
            
            result.add(wrap);
        }
        System.debug(result);
        return result;
    }
    
    public class ProductWrapper {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public String casNumber;
       
        @AuraEnabled public String industry;
        @AuraEnabled public Decimal stock;
        @AuraEnabled public String code;
        
        @AuraEnabled public Id brandId;
        @AuraEnabled public String brandName;
        
        @AuraEnabled public Id subBrandId;
        @AuraEnabled public String subBrandName;
        
        @AuraEnabled public Id categoryId;
        @AuraEnabled public String categoryName;
        
        @AuraEnabled public Id subCategoryId;
        @AuraEnabled public String subCategoryName;
        
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal discount;
        @AuraEnabled public Decimal gst;
        
        @AuraEnabled public Date promiseDispatchDate;
        @AuraEnabled public String priority;
        
    }

}