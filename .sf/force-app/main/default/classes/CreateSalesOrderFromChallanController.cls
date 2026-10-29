public with sharing class CreateSalesOrderFromChallanController {

    private static final Set<String> AUTHORIZED_PROFILES = new Set<String>{
        'Operations Team',
        'Operations Executive',
        'System Administrator'
    };
    private static final String FULLY_RECEIVED = 'Fully Received';

    public class EligibleProduct {
        @AuraEnabled public Id productId { get; set; }
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
        @AuraEnabled public Decimal listPrice { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
    }

    public class InitResponse {
        @AuraEnabled public Boolean isAuthorized { get; set; }
        @AuraEnabled public Boolean canProceed { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id challanId { get; set; }
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public List<EligibleProduct> products { get; set; }
    }

    private class Eligibility {
        public Id opportunityId;
        public String blockerMessage;
        public Map<Id, EligibleProduct> productsById = new Map<Id, EligibleProduct>();
    }

    @AuraEnabled
    public static Boolean isAuthorizedOperationUser() {
        return currentUserIsAuthorized();
    }

    @AuraEnabled
    public static InitResponse getEligibleProducts(Id challanId) {
        InitResponse response = new InitResponse();
        response.isAuthorized = currentUserIsAuthorized();
        response.canProceed = false;
        response.products = new List<EligibleProduct>();
        response.challanId = challanId;

        if (!response.isAuthorized) {
            response.message = 'You do not have access to create a Sales Order. This action is available to Operations users and System Administrators only.';
            return response;
        }

        try {
            Eligibility eligibility = resolveEligibility(challanId);
            response.opportunityId = eligibility.opportunityId;
            if (String.isNotBlank(eligibility.blockerMessage)) {
                response.message = eligibility.blockerMessage;
                return response;
            }
            response.products.addAll(eligibility.productsById.values());
            response.products.sort(new EligibleProductNameSort());
            response.canProceed = true;
            return response;
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw auraError(ex.getMessage());
        }
    }

    @AuraEnabled
    public static Id createSalesOrder(Id challanId, String salesOrderJson, List<Id> productIds) {
        if (!currentUserIsAuthorized()) {
            throw auraError('You do not have access to create a Sales Order. This action is available to Operations users and System Administrators only.');
        }

        Map<String, Object> input = parseSalesOrderInput(salesOrderJson);
        String salesOrderDate = (String) input.get('Sales_Order_Date__c');
        if (String.isBlank(salesOrderDate)) {
            throw auraError('Please select Sales Order Date.');
        }
        String customerPurchaseOrderNo = input.get('Customer_Purchase_Order_No__c') == null
            ? null
            : String.valueOf(input.get('Customer_Purchase_Order_No__c')).trim();
        if (customerPurchaseOrderNo != null && customerPurchaseOrderNo.length() > 255) {
            throw auraError('Customer Purchase Order No cannot be longer than 255 characters.');
        }

        Set<Id> requestedProductIds = new Set<Id>();
        if (productIds != null) {
            for (Id productId : productIds) {
                if (productId != null) {
                    requestedProductIds.add(productId);
                }
            }
        }
        if (requestedProductIds.isEmpty()) {
            throw auraError('Please select at least one product to create the Sales Order.');
        }

        Eligibility eligibility = resolveEligibility(challanId);
        if (String.isNotBlank(eligibility.blockerMessage)) {
            throw auraError(eligibility.blockerMessage);
        }

        List<Map<String, Object>> selectedLineItems = new List<Map<String, Object>>();
        for (Id productId : requestedProductIds) {
            if (!eligibility.productsById.containsKey(productId)) {
                throw auraError('One or more selected products are not on a Fully Received Purchase Order for this Challan. Refresh the page and try again.');
            }
            EligibleProduct product = eligibility.productsById.get(productId);
            if (product.quantity == null || product.quantity <= 0) {
                throw auraError('Selected products must have a quantity greater than 0.');
            }
            Decimal listPrice = product.listPrice == null ? 0 : product.listPrice;
            selectedLineItems.add(new Map<String, Object>{
                'productId' => product.productId,
                'quantity' => product.quantity,
                'discount' => 0,
                'gst' => 0,
                'amount' => (listPrice * product.quantity).setScale(2)
            });
        }

        Map<String, Object> salesOrderHeader = new Map<String, Object>{
            'Sales_Order_Date__c' => salesOrderDate,
            'Customer_Purchase_Order_No__c' => customerPurchaseOrderNo
        };

        // Challan only chooses eligible products. Creation stays on the existing Sales Order process.
        Savepoint sp = Database.setSavepoint();
        try {
            return GenerateSalesOrderQuotationController.saveSalesOrderRec(
                JSON.serialize(salesOrderHeader),
                null,
                JSON.serialize(selectedLineItems),
                eligibility.opportunityId
            );
        } catch (AuraHandledException ex) {
            Database.rollback(sp);
            throw ex;
        } catch (Exception ex) {
            Database.rollback(sp);
            throw auraError(ex.getMessage());
        }
    }

    private static Eligibility resolveEligibility(Id challanId) {
        Eligibility eligibility = new Eligibility();
        if (challanId == null) {
            eligibility.blockerMessage = 'Challan record not found.';
            return eligibility;
        }
        List<Challan__c> challans = [
            SELECT Id, Opportunity__c
            FROM Challan__c
            WHERE Id = :challanId
            LIMIT 1
        ];
        if (challans.isEmpty()) {
            eligibility.blockerMessage = 'Challan record not found.';
            return eligibility;
        }
        if (challans[0].Opportunity__c == null) {
            eligibility.blockerMessage = 'This Challan is not linked to an Opportunity, so a Sales Order cannot be created.';
            return eligibility;
        }
        eligibility.opportunityId = challans[0].Opportunity__c;

        List<Purchase_Request__c> purchaseRequests = [
            SELECT Id
            FROM Purchase_Request__c
            WHERE Challan__c = :challanId
        ];
        if (purchaseRequests.isEmpty()) {
            eligibility.blockerMessage = 'No Purchase Request has been raised for this Challan.';
            return eligibility;
        }

        Set<Id> purchaseRequestIds = new Map<Id, Purchase_Request__c>(purchaseRequests).keySet();
        List<Purchase_Order__c> purchaseOrders = [
            SELECT Id
            FROM Purchase_Order__c
            WHERE Purchase_Request__c IN :purchaseRequestIds
            AND Status__c = :FULLY_RECEIVED
        ];
        if (purchaseOrders.isEmpty()) {
            eligibility.blockerMessage = 'No Fully Received Purchase Order was found for this Challan\'s Purchase Request.';
            return eligibility;
        }

        Set<Id> purchaseOrderIds = new Map<Id, Purchase_Order__c>(purchaseOrders).keySet();
        List<Purchase_Order_Line_Item__c> lineItems = [
            SELECT Product__c, Quantity__c,
                Product__r.Name, Product__r.Industry__c, Product__r.CAS_Number__c, Product__r.Code__c,
                Product__r.Brand__r.Name, Product__r.Sub_Brand__r.Name,
                Product__r.Category__r.Name, Product__r.Sub_Category__r.Name,
                Product__r.Stock__c, Product__r.Hold_Quantity__c, Product__r.Available_Quantity__c,
                Product__r.List_Price__c
            FROM Purchase_Order_Line_Item__c
            WHERE Purchase_Order__c IN :purchaseOrderIds
            AND Product__c != null
        ];

        Map<Id, Decimal> quantityByProduct = new Map<Id, Decimal>();
        Map<Id, Purchase_Order_Line_Item__c> sampleLineByProduct = new Map<Id, Purchase_Order_Line_Item__c>();
        for (Purchase_Order_Line_Item__c lineItem : lineItems) {
            Decimal quantity = lineItem.Quantity__c == null ? 0 : lineItem.Quantity__c;
            Decimal currentQuantity = quantityByProduct.containsKey(lineItem.Product__c)
                ? quantityByProduct.get(lineItem.Product__c)
                : 0;
            quantityByProduct.put(lineItem.Product__c, currentQuantity + quantity);
            if (!sampleLineByProduct.containsKey(lineItem.Product__c)) {
                sampleLineByProduct.put(lineItem.Product__c, lineItem);
            }
        }

        for (Id productId : quantityByProduct.keySet()) {
            Decimal quantity = quantityByProduct.get(productId);
            if (quantity == null || quantity <= 0) {
                continue;
            }
            eligibility.productsById.put(productId, toEligibleProduct(sampleLineByProduct.get(productId), quantity));
        }

        if (eligibility.productsById.isEmpty()) {
            eligibility.blockerMessage = 'No products were found on Fully Received Purchase Orders for this Challan.';
        }
        return eligibility;
    }

    private static EligibleProduct toEligibleProduct(Purchase_Order_Line_Item__c lineItem, Decimal quantity) {
        EligibleProduct product = new EligibleProduct();
        product.productId = lineItem.Product__c;
        product.quantity = quantity;
        product.listPrice = 0;
        product.stock = 0;
        product.holdQuantity = 0;
        product.availableQuantity = 0;

        if (lineItem.Product__r != null) {
            product.productName = lineItem.Product__r.Name;
            product.industry = lineItem.Product__r.Industry__c;
            product.casNumber = lineItem.Product__r.CAS_Number__c;
            product.productCode = lineItem.Product__r.Code__c;
            product.brandName = lineItem.Product__r.Brand__r == null ? '' : lineItem.Product__r.Brand__r.Name;
            product.subBrandName = lineItem.Product__r.Sub_Brand__r == null ? '' : lineItem.Product__r.Sub_Brand__r.Name;
            product.categoryName = lineItem.Product__r.Category__r == null ? '' : lineItem.Product__r.Category__r.Name;
            product.subCategoryName = lineItem.Product__r.Sub_Category__r == null ? '' : lineItem.Product__r.Sub_Category__r.Name;
            product.stock = lineItem.Product__r.Stock__c == null ? 0 : lineItem.Product__r.Stock__c;
            product.holdQuantity = lineItem.Product__r.Hold_Quantity__c == null ? 0 : lineItem.Product__r.Hold_Quantity__c;
            product.availableQuantity = lineItem.Product__r.Available_Quantity__c == null ? 0 : lineItem.Product__r.Available_Quantity__c;
            product.listPrice = lineItem.Product__r.List_Price__c == null ? 0 : lineItem.Product__r.List_Price__c;
        }
        return product;
    }

    private static Map<String, Object> parseSalesOrderInput(String salesOrderJson) {
        if (String.isBlank(salesOrderJson)) {
            throw auraError('Please select Sales Order Date.');
        }
        try {
            Object parsed = JSON.deserializeUntyped(salesOrderJson);
            if (!(parsed instanceof Map<String, Object>)) {
                throw auraError('Sales Order details are invalid.');
            }
            return (Map<String, Object>) parsed;
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw auraError('Sales Order details are invalid.');
        }
    }

    private static Boolean currentUserIsAuthorized() {
        User currentUser = [
            SELECT Profile.Name, User_Profile_Name__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return AUTHORIZED_PROFILES.contains(currentUser.Profile.Name)
            || AUTHORIZED_PROFILES.contains(currentUser.User_Profile_Name__c);
    }

    private static AuraHandledException auraError(String message) {
        String safeMessage = String.isBlank(message) ? 'The Sales Order could not be opened.' : message;
        AuraHandledException ex = new AuraHandledException(safeMessage);
        ex.setMessage(safeMessage);
        return ex;
    }

    private class EligibleProductNameSort implements System.Comparator<EligibleProduct> {
        public Integer compare(EligibleProduct left, EligibleProduct right) {
            String leftName = left == null || left.productName == null ? '' : left.productName;
            String rightName = right == null || right.productName == null ? '' : right.productName;
            return leftName.toLowerCase().compareTo(rightName.toLowerCase());
        }
    }
}