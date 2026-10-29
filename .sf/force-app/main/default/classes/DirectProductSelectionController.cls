public class DirectProductSelectionController {
    
    // Picklist values for Industry dropdown
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getIndustryValues() {
        List<Map<String,String>> valuesMap = new List<Map<String,String>>();
        valuesMap.add(new Map<String,String>{
            'label' => '--None--',
            'value' => ''
        });
        
        Schema.DescribeFieldResult fieldResult = Product__c.Industry__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry pe : picklistValues) {
            Map<String,String> v = new Map<String,String>();
            v.put('label', pe.getLabel());
            v.put('value', pe.getLabel());
            valuesMap.add(v);
        }
        return valuesMap;
    }
    
    // Search Products based on 5 filters
   /* @AuraEnabled
    public static List<Product__c> getSearchedProducts(
        String productName, 
        String productCASNumber, 
        String productBrand, 
        String productCode, 
        String productIndustry
    ) {
        try {
            String query = 'SELECT Id, Name, CAS_Number__c, List_Price__c, Industry__c, Stock__c, Code__c, ' +
                           'Category__r.Name, Sub_Category__r.Name, Brand__r.Name, Sub_Brand__r.Name ' +
                           'FROM Product__c WHERE';
            
            if (String.isNotBlank(productName)) {
                query += ' Name LIKE \'%' + String.escapeSingleQuotes(productName) + '%\'';
            }
            if (String.isNotBlank(productCASNumber)) {
                if (!query.endsWith('WHERE')) {
                    query += ' AND ';
                }
                query += ' CAS_Number__c LIKE \'%' + String.escapeSingleQuotes(productCASNumber) + '%\'';
            }
            if (String.isNotBlank(productBrand)) {
                if (!query.endsWith('WHERE')) {
                    query += ' AND ';
                }
                query += ' Brand__c = \'' + String.escapeSingleQuotes(productBrand) + '\'';
            }
            if (String.isNotBlank(productCode)) {
                if (!query.endsWith('WHERE')) {
                    query += ' AND ';
                }
                query += ' Code__c LIKE \'%' + String.escapeSingleQuotes(productCode) + '%\'';
            }
            if (String.isNotBlank(productIndustry)) {
                if (!query.endsWith('WHERE')) {
                    query += ' AND ';
                }
                query += ' Industry__c INCLUDES (\'' + String.escapeSingleQuotes(productIndustry) + '\')';
            }
            
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    } */
    
    
     @AuraEnabled
    public static List<Product__c> getSearchedProducts(String productName, String productCASNumber, String productBrand, String productCode, String productIndustry) {
        try {
            String query = 'SELECT Id, Name, CAS_Number__c, List_Price__c, Industry__c, Stock__c,Hold_Quantity__c,Available_Quantity__c, Code__c, Category__r.Name, '+
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
    
    
    
    // Suggested products based on selected products
    @AuraEnabled
    public static List<Suggested_Product__c> getSuggestedProduct(List<String> productIds) {
        Set<String> productIdSet = new Set<String>(productIds);
        return [
            SELECT Id, Product__r.Name, Product__r.CAS_Number__c, Product__r.List_Price__c, 
                   Product__r.Industry__c, Product__r.Stock__c,Product__r.Hold_Quantity__c,Product__r.Available_Quantity__c, Product__r.Code__c, 
                   Product__r.Category__r.Name, Product__r.Sub_Category__r.Name, 
                   Product__r.Brand__r.Name, Product__r.Sub_Brand__r.Name
            FROM Suggested_Product__c 
            WHERE Parent__c IN :productIdSet
        ];
    }
    
    // Helper to get Product Name by Id
    @AuraEnabled
    public static String getProductNameById(Id recordId) {
        if (recordId == null) return '';
        try {
            Product__c prod = [SELECT Id, Name FROM Product__c WHERE Id = :recordId LIMIT 1];
            return prod.Name;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Helper to get CAS Number by Id
    @AuraEnabled(cacheable=true)
    public static String getProductCasById(Id recordId) {
        if (String.isBlank(recordId)) return '';
        List<Product__c> prodList = [SELECT Id, CAS_Number__c FROM Product__c WHERE Id = :recordId LIMIT 1];
        return (!prodList.isEmpty() && prodList[0].CAS_Number__c != null) ? prodList[0].CAS_Number__c : '';
    }
    
    // Helper to get Product Code by Id
    @AuraEnabled(cacheable=true)
    public static String getProductCodeById(Id recordId) {
        if (String.isBlank(recordId)) return '';
        try {
            List<Product__c> prodList = [SELECT Id, Code__c FROM Product__c WHERE Id = :recordId LIMIT 1];
            return (!prodList.isEmpty() && prodList[0].Code__c != null) ? prodList[0].Code__c : '';
        } catch (Exception e) {
            return '';
        }
    }
}