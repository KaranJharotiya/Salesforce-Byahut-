@isTest
private class CreateSOFromChallanTest {

    private static User createOpsUser() {
        Profile operationsProfile = [SELECT Id FROM Profile WHERE Name = 'Operations Team' LIMIT 1];
        User opsUser = new User(
            FirstName = 'Ops',
            LastName = 'ChallanSO',
            Alias = 'opschso',
            Email = 'opschso@example.com',
            Username = 'opschso' + System.currentTimeMillis() + '@example.com',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = operationsProfile.Id
        );
        insert opsUser;
        return opsUser;
    }

    @isTest
    static void systemAdministratorIsAuthorized() {
        System.assertEquals(true, CreateSalesOrderFromChallanController.isAuthorizedOperationUser());
    }

    @isTest
    static void unauthorizedUserIsBlocked() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User standardUser = new User(
            FirstName = 'Standard',
            LastName = 'ChallanSO',
            Alias = 'stdchso',
            Email = 'stdchso@example.com',
            Username = 'stdchso' + System.currentTimeMillis() + '@example.com',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id
        );
        insert standardUser;

        System.runAs(standardUser) {
            System.assertEquals(false, CreateSalesOrderFromChallanController.isAuthorizedOperationUser());

            CreateSalesOrderFromChallanController.InitResponse response =
                CreateSalesOrderFromChallanController.getEligibleProducts(null);
            System.assertEquals(false, response.isAuthorized);
            System.assertEquals(false, response.canProceed);
            System.assert(response.message.contains('System Administrators only'));

            Boolean threw = false;
            try {
                CreateSalesOrderFromChallanController.createSalesOrder(null, '{}', new List<Id>());
            } catch (AuraHandledException ex) {
                threw = true;
            }
            System.assertEquals(true, threw);
        }
    }

    @isTest
    static void returnsFullyReceivedProductsOnly() {
        User opsUser = createOpsUser();

        System.runAs(opsUser) {
            System.assertEquals(true, CreateSalesOrderFromChallanController.isAuthorizedOperationUser());

            Opportunity__c opportunity = new Opportunity__c(Name = 'Challan Sales Order Opportunity');
            insert opportunity;

            Challan__c challan = new Challan__c(Opportunity__c = opportunity.Id);
            insert challan;

            CreateSalesOrderFromChallanController.InitResponse missingPr =
                CreateSalesOrderFromChallanController.getEligibleProducts(challan.Id);
            System.assertEquals(false, missingPr.canProceed);
            System.assertEquals('No Purchase Request has been raised for this Challan.', missingPr.message);

            Purchase_Request__c purchaseRequest = new Purchase_Request__c(
                Challan__c = challan.Id,
                Opportunity__c = opportunity.Id
            );
            insert purchaseRequest;

            Product__c receivedProduct = new Product__c(Name = 'Received Product', List_Price__c = 50);
            Product__c secondReceivedProduct = new Product__c(Name = 'Second Received Product', List_Price__c = 20);
            Product__c partialProduct = new Product__c(Name = 'Partial Product', List_Price__c = 10);
            insert new List<Product__c>{ receivedProduct, secondReceivedProduct, partialProduct };

            Purchase_Order__c receivedOrder = new Purchase_Order__c(
                Purchase_Request__c = purchaseRequest.Id,
                Status__c = 'Fully Received'
            );
            Purchase_Order__c secondReceivedOrder = new Purchase_Order__c(
                Purchase_Request__c = purchaseRequest.Id,
                Status__c = 'Fully Received'
            );
            Purchase_Order__c partialOrder = new Purchase_Order__c(
                Purchase_Request__c = purchaseRequest.Id,
                Status__c = 'Partial Received'
            );
            insert new List<Purchase_Order__c>{ receivedOrder, secondReceivedOrder, partialOrder };

            insert new List<Purchase_Order_Line_Item__c>{
                new Purchase_Order_Line_Item__c(
                    Purchase_Order__c = receivedOrder.Id,
                    Product__c = receivedProduct.Id,
                    Quantity__c = 2
                ),
                new Purchase_Order_Line_Item__c(
                    Purchase_Order__c = secondReceivedOrder.Id,
                    Product__c = receivedProduct.Id,
                    Quantity__c = 3
                ),
                new Purchase_Order_Line_Item__c(
                    Purchase_Order__c = receivedOrder.Id,
                    Product__c = secondReceivedProduct.Id,
                    Quantity__c = 1
                ),
                new Purchase_Order_Line_Item__c(
                    Purchase_Order__c = partialOrder.Id,
                    Product__c = partialProduct.Id,
                    Quantity__c = 4
                )
            };

            CreateSalesOrderFromChallanController.InitResponse ready =
                CreateSalesOrderFromChallanController.getEligibleProducts(challan.Id);
            System.assertEquals(true, ready.canProceed);
            System.assertEquals(opportunity.Id, ready.opportunityId);
            System.assertEquals(2, ready.products.size());

            Map<Id, CreateSalesOrderFromChallanController.EligibleProduct> productsById =
                new Map<Id, CreateSalesOrderFromChallanController.EligibleProduct>();
            for (CreateSalesOrderFromChallanController.EligibleProduct product : ready.products) {
                productsById.put(product.productId, product);
            }
            System.assertEquals(5, productsById.get(receivedProduct.Id).quantity);
            System.assertEquals(50, productsById.get(receivedProduct.Id).listPrice);
            System.assertEquals(1, productsById.get(secondReceivedProduct.Id).quantity);
            System.assertEquals(false, productsById.containsKey(partialProduct.Id));
            System.assertEquals(0, [SELECT COUNT() FROM Sales_Order__c WHERE Opportunity__c = :opportunity.Id]);
        }
    }
}