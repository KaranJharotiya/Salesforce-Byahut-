@isTest
private class PurchasePaymentFollowUpTest {

    @isTest
    static void generatePoCreatesAssignedPurchasePayment() {
        Vendor_Master__c vendor = new Vendor_Master__c(Name = 'Payment Vendor');
        insert vendor;
        Product__c product = new Product__c(Name = 'Payment Product');
        insert product;
        Purchase_Request__c request = new Purchase_Request__c(Status__c = 'Approved');
        insert request;
        Purchase_Request_Line_Item__c requestLine = new Purchase_Request_Line_Item__c(
            Purchase_Request__c = request.Id,
            Product__c = product.Id,
            Quantity__c = 2
        );
        insert requestLine;
        Item_Vendor_Rate__c vendorRate = new Item_Vendor_Rate__c(
            Product__c = product.Id,
            Vendor__c = vendor.Id,
            Purchase_Request_Line_Item__c = requestLine.Id,
            Rate__c = 100,
            Quantity__c = 2,
            Discount__c = 0,
            GST__c = 0,
            Status__c = 'Approved'
        );
        insert vendorRate;

        PurchaseRequestGeneratePOController.POLineItemWrapper line =
            new PurchaseRequestGeneratePOController.POLineItemWrapper();
        line.ivrId = vendorRate.Id;
        line.productId = product.Id;
        line.productName = product.Name;
        line.quantity = 2;
        line.rate = 100;
        line.discount = 0;
        line.gst = 0;

        PurchaseRequestGeneratePOController.VendorGroupWrapper vendorGroup =
            new PurchaseRequestGeneratePOController.VendorGroupWrapper();
        vendorGroup.vendorId = vendor.Id;
        vendorGroup.vendorName = vendor.Name;
        vendorGroup.expectedDeliveryDate = Date.today().addDays(5);
        vendorGroup.lineItems = new List<PurchaseRequestGeneratePOController.POLineItemWrapper>{ line };

        Test.startTest();
        PurchaseRequestGeneratePOController.createPurchaseOrders(
            request.Id,
            new List<PurchaseRequestGeneratePOController.VendorGroupWrapper>{ vendorGroup }
        );
        Test.stopTest();

        Purchase_Order__c purchaseOrder = [
            SELECT Id, Total_Amount__c, Successful_Payment_Amount__c, Pending_Amount__c
            FROM Purchase_Order__c
            WHERE Purchase_Request__c = :request.Id
        ];
        Payment_Details__c payment = [
            SELECT RecordType.DeveloperName, Purchase_Order__c, Challan__c, Payment_Status__c,
                Payment_Type__c, Amount__c, OwnerId
            FROM Payment_Details__c
            WHERE Purchase_Order__c = :purchaseOrder.Id
        ];
        Group accountsQueue = [
            SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Accounts_Team' LIMIT 1
        ];

        System.assertEquals('Purchase_Payment_Details', payment.RecordType.DeveloperName);
        System.assertEquals(purchaseOrder.Id, payment.Purchase_Order__c);
        System.assertEquals(null, payment.Challan__c);
        System.assertEquals('Pending', payment.Payment_Status__c);
        System.assertEquals('Invoice Payment', payment.Payment_Type__c);
        System.assertEquals(purchaseOrder.Total_Amount__c, payment.Amount__c);
        System.assert(purchaseOrder.Total_Amount__c > 0);
        System.assertEquals(accountsQueue.Id, payment.OwnerId);
        System.assertEquals(0, purchaseOrder.Successful_Payment_Amount__c);
        System.assertEquals(purchaseOrder.Total_Amount__c, purchaseOrder.Pending_Amount__c);

        payment.Payment_Status__c = 'Successful';
        update payment;

        Purchase_Order__c afterSuccess = [
            SELECT Successful_Payment_Amount__c, Pending_Amount__c
            FROM Purchase_Order__c
            WHERE Id = :purchaseOrder.Id
        ];
        System.assertEquals(purchaseOrder.Total_Amount__c, afterSuccess.Successful_Payment_Amount__c);
        System.assertEquals(0, afterSuccess.Pending_Amount__c);

        DeliveryDetailTriggerHelper.createPurchasePaymentsForOrders(new Set<Id>{ purchaseOrder.Id });
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Payment_Details__c WHERE Purchase_Order__c = :purchaseOrder.Id]
        );
    }
}