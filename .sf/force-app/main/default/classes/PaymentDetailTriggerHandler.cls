public class PaymentDetailTriggerHandler extends Trigger_Handler_Utilities {

    public override void afterInsert(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap,
        Schema.SObjectType sot, String params, Boolean debug
    ) {
        rollupSuccessfulAmount(n, null);
    }

    public override void afterUpdate(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap,
        Schema.SObjectType sot, String params, Boolean debug
    ) {
        rollupSuccessfulAmount(n, o);
    }

    public override void afterDelete(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap,
        Schema.SObjectType sot, String params, Boolean debug
    ) {
        rollupSuccessfulAmount(null, o);
    }

    public override void afterUndelete(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap,
        Schema.SObjectType sot, String params, Boolean debug
    ) {
        rollupSuccessfulAmount(n, null);
    }

    private static void rollupSuccessfulAmount(List<SObject> currentRows, List<SObject> previousRows) {
        Set<Id> challanIds = new Set<Id>();
        Set<Id> purchaseOrderIds = new Set<Id>();
        collectParentIds(currentRows, challanIds, purchaseOrderIds);
        collectParentIds(previousRows, challanIds, purchaseOrderIds);
        rollupPurchaseOrders(purchaseOrderIds);
        if (challanIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        for (Id challanId : challanIds) {
            totals.put(challanId, 0);
        }
        for (AggregateResult result : [
            SELECT Challan__c challanId, SUM(Amount__c) totalAmount
            FROM Payment_Details__c
            WHERE Challan__c IN :challanIds
            AND Payment_Status__c = 'Successful'
            GROUP BY Challan__c
        ]) {
            Decimal totalAmount = (Decimal) result.get('totalAmount');
            totals.put((Id) result.get('challanId'), totalAmount == null ? 0 : totalAmount);
        }

        List<Challan__c> updates = new List<Challan__c>();
        for (Id challanId : totals.keySet()) {
            updates.add(new Challan__c(
                Id = challanId,
                Successful_Payment_Amount__c = totals.get(challanId)
            ));
        }
        update updates;
        DeliveryDetailTriggerHelper.syncChallanDeliveryPaymentStatus(totals.keySet());
    }

    private static void collectParentIds(List<SObject> rows, Set<Id> challanIds, Set<Id> purchaseOrderIds) {
        if (rows == null) {
            return;
        }
        for (SObject row : rows) {
            Id challanId = (Id) row.get('Challan__c');
            if (challanId != null) {
                challanIds.add(challanId);
            }
            Id purchaseOrderId = (Id) row.get('Purchase_Order__c');
            if (purchaseOrderId != null) {
                purchaseOrderIds.add(purchaseOrderId);
            }
        }
    }

    private static void rollupPurchaseOrders(Set<Id> purchaseOrderIds) {
        if (purchaseOrderIds == null || purchaseOrderIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        for (Id purchaseOrderId : purchaseOrderIds) {
            totals.put(purchaseOrderId, 0);
        }
        for (AggregateResult result : [
            SELECT Purchase_Order__c purchaseOrderId, SUM(Amount__c) totalAmount
            FROM Payment_Details__c
            WHERE Purchase_Order__c IN :purchaseOrderIds
            AND Payment_Status__c = 'Successful'
            GROUP BY Purchase_Order__c
        ]) {
            Decimal totalAmount = (Decimal) result.get('totalAmount');
            totals.put((Id) result.get('purchaseOrderId'), totalAmount == null ? 0 : totalAmount);
        }

        List<Purchase_Order__c> updates = new List<Purchase_Order__c>();
        for (Id purchaseOrderId : totals.keySet()) {
            updates.add(new Purchase_Order__c(
                Id = purchaseOrderId,
                Successful_Payment_Amount__c = totals.get(purchaseOrderId)
            ));
        }
        update updates;
    }
}