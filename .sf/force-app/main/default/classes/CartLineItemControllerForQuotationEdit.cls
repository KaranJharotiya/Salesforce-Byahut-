public class CartLineItemControllerForQuotationEdit {
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getPicklistValues(String objectApiName, String fieldApiName) {
        List<Map<String,String>> picklistValuesList = new List<Map<String,String>>();
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        Schema.DescribeFieldResult fieldDescribe = objDescribe.fields.getMap().get(fieldApiName).getDescribe();
        
        for(Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()){
            if(entry.isActive()){
                picklistValuesList.add(new Map<String,String>{'label' => entry.getLabel(), 'value' => entry.getValue()});
            }
        }
        return picklistValuesList;
    }
    
    @AuraEnabled
    public static String getObjectNameFromId(Id recordId) {
        if(recordId == null) return null;
        return recordId.getSObjectType().getDescribe().getName();
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getIndustryValues(){
        List<Map<String,String>> valuesMap = new List<Map<String,String>>();
        valuesMap.add(new Map<String,String>{
            'label' => '--None--',
                'value' => ''
                });
        Schema.DescribeFieldResult fieldResult = Product__c.Industry__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        for(Schema.PicklistEntry pe : picklistValues){
            Map<String,String> v = new Map<String,String>();
            v.put('label', pe.getLabel());
            v.put('value', pe.getLabel());
            valuesMap.add(v);
        }
        return valuesMap;
    }
    
    @AuraEnabled
    public static Product__c getSelectedProduct(String productId){
        return [Select Id, Name, CAS_Number__c, Brand__c, Code__c From Product__c Where Id = :productId];
    }
    
    @AuraEnabled
    public static List<Suggested_Product__c> getSuggestedProduct(List<String> productIds){
        Set<String> productIdSet = new Set<String>(productIds);
        return [Select Id, Product__r.Name, Product__r.CAS_Number__c, Product__r.List_Price__c, Product__r.Industry__c, Product__r.Stock__c,Product__r.Hold_Quantity__c,Product__r.Available_Quantity__c, Product__r.Code__c, Product__r.Category__r.Name,
                Product__r.Sub_Category__r.Name, Product__r.Brand__r.Name, Product__r.Sub_Brand__r.Name
                From Suggested_Product__c Where Parent__c in :productIdSet];
    }
    
   /* @AuraEnabled
    public static List<Product__c> getSearchedProducts(String productName, String productCASNumber, String productBrand, String productCode, String productIndustry) {
        try {
            String query = 'SELECT Id, Name, CAS_Number__c, List_Price__c, Industry__c, Stock__c, Code__c, Category__r.Name, '+
                ' Sub_Category__r.Name, Brand__r.Name, Sub_Brand__r.Name ' +
                ' FROM Product__c WHERE';
            
            if(!String.isBlank(productName)){
                query += ' Name LIKE \'%' + String.escapeSingleQuotes(productName) + '%\'';
            }
            if(!String.isBlank(productCASNumber)){
                if(!query.endsWith('WHERE')){
                    query += ' AND ';
                }
                query += ' CAS_Number__c LIKE \'%' + String.escapeSingleQuotes(productCASNumber) + '%\'';
            }
            if(!String.isBlank(productBrand)){
                if(!query.endsWith('WHERE')){
                    query += ' AND ';
                }
                query += ' Brand__c = \'' + String.escapeSingleQuotes(productBrand) + '\'';
            }
            if(!String.isBlank(productCode)){
                if(!query.endsWith('WHERE')){
                    query += ' AND ';
                }
                query += ' Code__c LIKE \'%' + String.escapeSingleQuotes(productCode) + '%\'';
            }
            if(!String.isBlank(productIndustry)){
                if(!query.endsWith('WHERE')){
                    query += ' AND ';
                }
                query += ' Industry__c INCLUDES  (\'' + String.escapeSingleQuotes(productIndustry) + '\')';
            }
            
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    } */
    
    @AuraEnabled
    public static List<Product__c> getSearchedProducts(String productName, String productCASNumber, String productBrand, String productCode, String productIndustry) {
        try {
            String query = 'SELECT Id, Name, CAS_Number__c, List_Price__c, Industry__c, Stock__c, Available_Quantity__c,Hold_Quantity__c,Code__c, Category__r.Name, '+
                ' Sub_Category__r.Name, Brand__r.Name, Sub_Brand__r.Name ' +
                ' FROM Product__c WHERE';
            
            if(!String.isBlank(productName)){
                query += ' Id = \'' + String.escapeSingleQuotes(productName) + '\'';
            }
            if(!String.isBlank(productCASNumber)){
                if(!query.endsWith('WHERE')){
                    query += ' AND ';
                }
                query += ' Id = \'' + String.escapeSingleQuotes(productCASNumber) + '\'';
            }
            
            if(!String.isBlank(productBrand)){
                if(!query.endsWith('WHERE')){
                    query += ' AND ';
                }
                query += ' Brand__c = \'' + String.escapeSingleQuotes(productBrand) + '\'';
            }
            
            if(!String.isBlank(productCode)){
                if(!query.endsWith('WHERE')){
                    query += ' AND ';
                }
                query += ' Id = \'' + String.escapeSingleQuotes(productCode) + '\'';
            }
            
            if(!String.isBlank(productIndustry)){
                if(!query.endsWith('WHERE')){
                    query += ' AND ';
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
    public static String createCartLineItem(List<Cart_Line_Item__c> cartLineItem){
        try{
            Insert cartLineItem;
            return 'Record saved successfully!';
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String createQuotationWithLineItems(
        Id leadId,
        List<Quotation_Line_Items__c> lineItems
    ) {
        try {
            Quotation__c quotation = new Quotation__c();
            quotation.Lead__c = leadId;
            insert quotation;
            
            for (Quotation_Line_Items__c item : lineItems) {
                item.Quotation__c = quotation.Id;
            }
            insert lineItems;
            return 'Record saved successfully!';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String createQuotationWithLineItemsOpp(
        Id oppId,
        List<Quotation_Line_Items__c> lineItems
    ) {
        try {
            Quotation__c quotation = new Quotation__c();
            quotation.Opportunity__c = oppId;
            insert quotation;
            
            for (Quotation_Line_Items__c item : lineItems) {
                item.Quotation__c = quotation.Id;
            }
            insert lineItems;
            return 'Record saved successfully!';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String updateQuotationLineItems(
        Id quotationId,
        List<Quotation_Line_Items__c> lineItems
    ) {
        try {
            if(quotationId == null) {
                throw new AuraHandledException('Quotation Id cannot be null');
            }
            
            Map<Id, Quotation_Line_Items__c> existingItemsMap = new Map<Id, Quotation_Line_Items__c>([
                SELECT Id FROM Quotation_Line_Items__c WHERE Quotation__c = :quotationId
            ]);
            
            List<Quotation_Line_Items__c> itemsToUpsert = new List<Quotation_Line_Items__c>();
            Set<Id> currentRetainedLineItemIds = new Set<Id>();
            
            for (Quotation_Line_Items__c item : lineItems) {
                if (item.Id == null) {
                    item.Quotation__c = quotationId;
                } else {
                    currentRetainedLineItemIds.add(item.Id);
                }
                itemsToUpsert.add(item);
            }
            
            List<Quotation_Line_Items__c> itemsToDelete = new List<Quotation_Line_Items__c>();
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
            
            return 'Quotation updated successfully!';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String getProductNameById(Id recordId) {
        if (recordId == null) {
            return '';
        }
        try {
            Product__c prod = [SELECT Id, Name FROM Product__c WHERE Id = :recordId LIMIT 1];
            return prod.Name;
        } catch (Exception e) {
            System.debug(e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static String getProductCasById(Id recordId) {
        if (String.isBlank(recordId)) {
            return '';
        }
        List<Product__c> prodList = [SELECT Id, CAS_Number__c FROM Product__c WHERE Id = :recordId LIMIT 1];
        return (!prodList.isEmpty() && prodList[0].CAS_Number__c != null) ? prodList[0].CAS_Number__c : '';
    }
    
    @AuraEnabled(cacheable=true)
    public static String getBrandNameById(Id recordId) {
        if (String.isBlank(recordId)) {
            return '';
        }
        try {
            List<Brand_Master__c> brandList = [SELECT Id, Name FROM Brand_Master__c WHERE Id = :recordId LIMIT 1];
            return !brandList.isEmpty() ? brandList[0].Name : '';
        } catch (Exception e) {
            return '';
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static String getProductCodeById(Id recordId) {
        if (String.isBlank(recordId)) {
            return '';
        }
        try {
            List<Product__c> prodList = [SELECT Id, Code__c FROM Product__c WHERE Id = :recordId LIMIT 1];
            return (!prodList.isEmpty() && prodList[0].Code__c != null) ? prodList[0].Code__c : '';
        } catch (Exception e) {
            return '';
        }
    }
    
    @AuraEnabled
    public static List<ProductWrapper> getExistingQuotationProducts(Id quotationId) {
        List<ProductWrapper> result = new List<ProductWrapper>();
        if (quotationId == null) return result;
        
        Set<Id> productIds = new Set<Id>();
        Map<Id, Quotation_Line_Items__c> prodToLineItemMap = new Map<Id, Quotation_Line_Items__c>();
        
        for (Quotation_Line_Items__c qli : [
            SELECT Id, Product__c, Quantity__c, Discount__c, GST__c,Amount__c 
            FROM Quotation_Line_Items__c 
            WHERE Quotation__c = :quotationId AND Product__c != null
        ]) {
            productIds.add(qli.Product__c);
            prodToLineItemMap.put(qli.Product__c, qli);
        }
        
        if (productIds.isEmpty()) return result;
        
        List<Product__c> prodList = [
            SELECT Id, Name, CAS_Number__c, List_Price__c, Industry__c, Stock__c,Hold_Quantity__c,Available_Quantity__c, Code__c, 
            Brand__c, Brand__r.Name, 
            Sub_Brand__c, Sub_Brand__r.Name, 
            Category__c, Category__r.Name, 
            Sub_Category__c, Sub_Category__r.Name 
            FROM Product__c 
            WHERE Id IN :productIds
        ];
        
        for (Product__c prod : prodList) {
            Quotation_Line_Items__c qli = prodToLineItemMap.get(prod.Id);
            
            ProductWrapper wrap = new ProductWrapper();
            wrap.lineItemId = qli.Id;
            wrap.id = prod.Id;
            wrap.name = prod.Name;
            wrap.casNumber = prod.CAS_Number__c;
            wrap.listPrice = qli.Amount__c;
            wrap.industry = prod.Industry__c;
            wrap.stock = prod.Stock__c;
             wrap.holdQuantity = prod.Hold_Quantity__c;
             wrap.availableQuantity = prod.Available_Quantity__c;
            wrap.code = prod.Code__c;
            
            wrap.brandId = prod.Brand__c;
            wrap.brandName = prod.Brand__r != null ? prod.Brand__r.Name : '';
            
            wrap.subBrandId = prod.Sub_Brand__c;
            wrap.subBrandName = prod.Sub_Brand__r != null ? prod.Sub_Brand__r.Name : '';
            
            wrap.categoryId = prod.Category__c;
            wrap.categoryName = prod.Category__r != null ? prod.Category__r.Name : '';
            
            wrap.subCategoryId = prod.Sub_Category__c;
            wrap.subCategoryName = prod.Sub_Category__r != null ? prod.Sub_Category__r.Name : '';
            
            wrap.quantity = qli.Quantity__c;
            wrap.discount = qli.Discount__c;
            wrap.gst = qli.GST__c;
            
            result.add(wrap);
        }
        return result;
    }
    
    public class ProductWrapper {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String casNumber;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public String industry;
        @AuraEnabled public Decimal stock;
        @AuraEnabled public Decimal holdQuantity;
        @AuraEnabled public Decimal availableQuantity;
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
    }
}