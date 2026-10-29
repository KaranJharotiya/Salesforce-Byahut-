@isTest
private class DeliveryPaymentFollowUpTest {

    @isTest
    static void deliveredSalesDetailCreatesAssignedPayment() {
        Challan__c challan = new Challan__c(Total_Actual_Amount__c = 1000);
        insert challan;

        Id salesDetailRtId = deliveryRecordTypeId('Sales_Detail');
        Delivery_Detail__c delivery = new Delivery_Detail__c(
            RecordTypeId = salesDetailRtId,
            Challan__c = challan.Id,
            Delivery_Status__c = 'Dispatched'
        );
        insert delivery;

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Payment_Details__c WHERE Delivery_Detail__c = :delivery.Id]
        );

        Test.startTest();
        delivery.Delivery_Status__c = 'Delivered';
        update delivery;
        Test.stopTest();

        Payment_Details__c payment = [
            SELECT RecordType.DeveloperName, Challan__c, Delivery_Detail__c, Payment_Status__c,
                Payment_Type__c, Amount__c, OwnerId
            FROM Payment_Details__c
            WHERE Delivery_Detail__c = :delivery.Id
        ];
        Group accountsQueue = [
            SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Accounts_Team' LIMIT 1
        ];

        System.assertEquals('Sales_Payment_Details', payment.RecordType.DeveloperName);
        System.assertEquals(challan.Id, payment.Challan__c);
        System.assertEquals(delivery.Id, payment.Delivery_Detail__c);
        System.assertEquals('Pending', payment.Payment_Status__c);
        System.assertEquals('Invoice Payment', payment.Payment_Type__c);
        System.assertEquals(1000, payment.Amount__c);
        System.assertEquals(accountsQueue.Id, payment.OwnerId);
        Set<Id> accountsTeamUserIds = new Set<Id>();
        for (GroupMember member : [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId = :accountsQueue.Id
        ]) {
            accountsTeamUserIds.add(member.UserOrGroupId);
        }
        System.assert(accountsTeamUserIds.contains('005Bg00000Aqr2UIAR'));
        System.assert(accountsTeamUserIds.contains('005Bg00000AvL1xIAF'));
        System.assertEquals(false, accountsTeamUserIds.contains(UserInfo.getUserId()));

        Challan__c beforeSuccess = [
            SELECT Successful_Payment_Amount__c, Pending_Amount__c, Status__c
            FROM Challan__c
            WHERE Id = :challan.Id
        ];
        System.assertEquals(0, beforeSuccess.Successful_Payment_Amount__c);
        System.assertEquals(1000, beforeSuccess.Pending_Amount__c);
        System.assertEquals('Delivered/Payment Pending', beforeSuccess.Status__c);

        payment.Payment_Status__c = 'Successful';
        payment.Amount__c = 400;
        update payment;

        Payment_Details__c partial = payment.clone(false, true, false, false);
        partial.Amount__c = 250;
        partial.Payment_Status__c = 'Successful';
        partial.Delivery_Detail__c = null;
        insert partial;

        Challan__c afterSuccess = [
            SELECT Successful_Payment_Amount__c, Pending_Amount__c
            FROM Challan__c
            WHERE Id = :challan.Id
        ];
        System.assertEquals(650, afterSuccess.Successful_Payment_Amount__c);
        System.assertEquals(350, afterSuccess.Pending_Amount__c);

        delete partial;
        Challan__c afterDelete = [
            SELECT Successful_Payment_Amount__c, Pending_Amount__c
            FROM Challan__c
            WHERE Id = :challan.Id
        ];
        System.assertEquals(400, afterDelete.Successful_Payment_Amount__c);
        System.assertEquals(600, afterDelete.Pending_Amount__c);
    }

    @isTest
    static void fullSuccessfulPaymentMarksChallanReceived() {
        Challan__c challan = new Challan__c(Total_Actual_Amount__c = 100);
        insert challan;

        Delivery_Detail__c delivery = new Delivery_Detail__c(
            RecordTypeId = deliveryRecordTypeId('Sales_Detail'),
            Challan__c = challan.Id,
            Delivery_Status__c = 'Delivered'
        );
        insert delivery;

        Payment_Details__c payment = [
            SELECT Id, Amount__c
            FROM Payment_Details__c
            WHERE Delivery_Detail__c = :delivery.Id
        ];
        payment.Payment_Status__c = 'Successful';
        update payment;

        Challan__c received = [
            SELECT Status__c, Pending_Amount__c
            FROM Challan__c
            WHERE Id = :challan.Id
        ];
        System.assertEquals(0, received.Pending_Amount__c);
        System.assertEquals('Delivered/Payment Received', received.Status__c);
    }

    @isTest
    static void repeatAndNonSalesDeliveriesDoNotCreateExtraPayments() {
        Challan__c challan = new Challan__c(Total_Actual_Amount__c = 500);
        insert challan;

        Delivery_Detail__c salesDelivery = new Delivery_Detail__c(
            RecordTypeId = deliveryRecordTypeId('Sales_Detail'),
            Challan__c = challan.Id,
            Delivery_Status__c = 'Delivered'
        );
        Delivery_Detail__c purchaseDelivery = new Delivery_Detail__c(
            RecordTypeId = deliveryRecordTypeId('Purchase_Detail'),
            Challan__c = challan.Id,
            Delivery_Status__c = 'Delivered'
        );
        insert new List<Delivery_Detail__c>{ salesDelivery, purchaseDelivery };

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Payment_Details__c WHERE Challan__c = :challan.Id]
        );

        salesDelivery.Delivery_Status__c = 'Delivered';
        update salesDelivery;

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Payment_Details__c WHERE Challan__c = :challan.Id]
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Payment_Details__c WHERE Delivery_Detail__c = :purchaseDelivery.Id]
        );
    }

    @isTest
    static void onlyAccountsTeamCanCreateOrEditPayments() {
        Challan__c challan = new Challan__c(Total_Actual_Amount__c = 100);
        insert challan;

        Id salesPaymentRtId = Schema.SObjectType.Payment_Details__c
            .getRecordTypeInfosByDeveloperName()
            .get('Sales_Payment_Details')
            .getRecordTypeId();
        Payment_Details__c payment = new Payment_Details__c(
            RecordTypeId = salesPaymentRtId,
            Challan__c = challan.Id,
            Payment_Date__c = Date.today(),
            Payment_Status__c = 'Pending',
            Payment_Type__c = 'Invoice Payment',
            Amount__c = 100
        );

        User salesUser = [SELECT Id FROM User WHERE Username = 'salesteam1@gmail.com' LIMIT 1];
        User accountsUser = [SELECT Id FROM User WHERE Username = 'accountsuser1@gmail.com' LIMIT 1];

        System.runAs(salesUser) {
            Database.SaveResult blocked = Database.insert(payment, false, AccessLevel.USER_MODE);
            System.assertEquals(false, blocked.isSuccess());
        }

        System.runAs(accountsUser) {
            Database.SaveResult allowed = Database.insert(payment, false, AccessLevel.USER_MODE);
            System.assertEquals(true, allowed.isSuccess(), allowed.getErrors().isEmpty() ? '' : allowed.getErrors()[0].getMessage());

            payment.Amount__c = 80;
            Database.SaveResult edited = Database.update(payment, false, AccessLevel.USER_MODE);
            System.assertEquals(true, edited.isSuccess(), edited.getErrors().isEmpty() ? '' : edited.getErrors()[0].getMessage());
        }
    }

    private static Id deliveryRecordTypeId(String developerName) {
        return Schema.SObjectType.Delivery_Detail__c
            .getRecordTypeInfosByDeveloperName()
            .get(developerName)
            .getRecordTypeId();
    }
}