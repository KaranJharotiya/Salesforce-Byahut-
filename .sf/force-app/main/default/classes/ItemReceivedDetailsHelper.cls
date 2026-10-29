public class ItemReceivedDetailsHelper {
    
    public static void manageProductQuantity(List<Item_Received_Details__c> n, Map<Id,Item_Received_Details__c> oMap, String opType){
        
        Set<Id> poliIdSet = new Set<Id>();
        Map<Id,Decimal> poliIdMap = new Map<Id,Decimal>();
        for(Item_Received_Details__c ird : n){
            if(ird.Purchase_Order_Line_Item__c != null && 
               (opType == 'AFTER_INSERT' || 
                opType == 'BEFORE_DELETE' || 
                (opType == 'AFTER_UPDATE' && 
                 (ird.Received_Quantity__c != oMap.get(ird.Id).Received_Quantity__c ||
                  ird.Damaged_Quantity__c != oMap.get(ird.Id).Damaged_Quantity__c)))){
                      poliIdSet.add(ird.Id);
                  }
        }
        
        List<Item_Received_Details__c> irdList = [Select Id, Received_Quantity__c,Damaged_Quantity__c, Purchase_Order_Line_Item__r.Product__c from Item_Received_Details__c Where Id IN :poliIdSet AND Purchase_Order_Line_Item__r.Product__c != null];
        
        Map<Id,Decimal> productQuantityMap = new Map<Id,Decimal>();
        Map<Id,Decimal> productDamagedQuantityMap = new Map<Id,Decimal>();
        for(Item_Received_Details__c ird : irdList){
            Decimal qty = opType == 'AFTER_UPDATE'
                ? (ird.Received_Quantity__c == null ? 0 : ird.Received_Quantity__c)
                - (oMap.get(ird.Id).Received_Quantity__c == null ? 0 : oMap.get(ird.Id).Received_Quantity__c)
                : (ird.Received_Quantity__c == null ? 0 : ird.Received_Quantity__c);
                    Decimal damagedqty = opType == 'AFTER_UPDATE'
                    ? (ird.Damaged_Quantity__c == null ? 0 : ird.Damaged_Quantity__c)
                    - (oMap.get(ird.Id).Damaged_Quantity__c == null ? 0 : oMap.get(ird.Id).Damaged_Quantity__c)
                    : (ird.Damaged_Quantity__c == null ? 0 : ird.Damaged_Quantity__c);
                        if(productQuantityMap.containsKey(ird.Purchase_Order_Line_Item__r.Product__c)){
                productQuantityMap.put(ird.Purchase_Order_Line_Item__r.Product__c, productQuantityMap.get(ird.Purchase_Order_Line_Item__r.Product__c) + qty);
            }else {
                productQuantityMap.put(ird.Purchase_Order_Line_Item__r.Product__c, qty);
            }
            
            if(productDamagedQuantityMap.containsKey(ird.Purchase_Order_Line_Item__r.Product__c)){
                productDamagedQuantityMap.put(ird.Purchase_Order_Line_Item__r.Product__c, productDamagedQuantityMap.get(ird.Purchase_Order_Line_Item__r.Product__c) + damagedqty);
            }else {
                productDamagedQuantityMap.put(ird.Purchase_Order_Line_Item__r.Product__c, damagedqty);
            }
        }
        
        List<Product__c> productList = [Select Id, Stock__c From Product__c Where Id IN :productQuantityMap.keySet()];
        List<Product__c> productListforDamagedQty = [Select Id,Damaged_Quantity__c From Product__c Where Id IN :productDamagedQuantityMap.keySet()];
        for(Product__c prd : productList){
            if(opType == 'BEFORE_DELETE' && prd.Stock__c != null){
                prd.Stock__c = prd.Stock__c - productQuantityMap.get(prd.Id);
            }else {
                if(prd.Stock__c != null){
                    prd.Stock__c = prd.Stock__c + productQuantityMap.get(prd.Id);
                }else {
                    prd.Stock__c = productQuantityMap.get(prd.Id);
                }
            }
        }
        for(Product__c prd : productListforDamagedQty){
            if(opType == 'BEFORE_DELETE' && prd.Damaged_Quantity__c != null){
                prd.Damaged_Quantity__c = prd.Damaged_Quantity__c - productDamagedQuantityMap.get(prd.Id);
            }else {
                if(prd.Damaged_Quantity__c != null){
                    prd.Damaged_Quantity__c = prd.Damaged_Quantity__c + productDamagedQuantityMap.get(prd.Id);
                }else {
                    prd.Damaged_Quantity__c = productDamagedQuantityMap.get(prd.Id);
                }
            }
        }
        if(!productList.isEmpty()){
            Update productList;
        }
        if(!productListforDamagedQty.isEmpty()){
            Update productListforDamagedQty;
        }
    }
    
    public static void validateReceivedQuantity( List<Item_Received_Details__c> newList,Map<Id, Item_Received_Details__c> oldMap){
        Set<Id> poliIds = new Set<Id>();
        
        for (Item_Received_Details__c ird : newList) {
            if (ird.Purchase_Order_Line_Item__c != null) {
                poliIds.add(ird.Purchase_Order_Line_Item__c);
            }
        }
        if (poliIds.isEmpty()) {
            return;
        }
        Map<Id, Decimal> poliQuantityMap = new Map<Id, Decimal>();
        for (Purchase_Order_Line_Item__c poli : [ SELECT Id, Quantity__c FROM Purchase_Order_Line_Item__c WHERE Id IN :poliIds]) {
            poliQuantityMap.put( poli.Id, poli.Quantity__c == null ? 0 : poli.Quantity__c);
        }
        
        // Get existing received details
        Map<Id, Decimal> totalQuantityMap = new Map<Id, Decimal>();
        
        for (Item_Received_Details__c ird : [SELECT Id, Purchase_Order_Line_Item__c,Received_Quantity__c,Damaged_Quantity__c FROM Item_Received_Details__c WHERE Purchase_Order_Line_Item__c IN :poliIds]){
            if (oldMap != null && oldMap.containsKey(ird.Id)) {
                continue;
            }
            
            Decimal receivedQty = ird.Received_Quantity__c == null ? 0 : ird.Received_Quantity__c;
            
            Decimal damagedQty = ird.Damaged_Quantity__c == null ? 0  : ird.Damaged_Quantity__c;
            
            Decimal totalQty = receivedQty + damagedQty;
            
            if (totalQuantityMap.containsKey(ird.Purchase_Order_Line_Item__c)) {
                totalQuantityMap.put(ird.Purchase_Order_Line_Item__c,totalQuantityMap.get(ird.Purchase_Order_Line_Item__c) + totalQty);
            }else {
                totalQuantityMap.put(ird.Purchase_Order_Line_Item__c, totalQty);
            }
        }
        
        // Add current transaction records
        for (Item_Received_Details__c ird : newList) {
            if (ird.Purchase_Order_Line_Item__c == null) {
                continue;
            }
            
            Decimal receivedQty = ird.Received_Quantity__c == null ? 0 : ird.Received_Quantity__c;
            Decimal damagedQty = ird.Damaged_Quantity__c == null ? 0 : ird.Damaged_Quantity__c;
            
            Decimal totalQty = receivedQty + damagedQty;
            
            if (totalQuantityMap.containsKey(ird.Purchase_Order_Line_Item__c)) {
                totalQuantityMap.put(ird.Purchase_Order_Line_Item__c,totalQuantityMap.get(ird.Purchase_Order_Line_Item__c) + totalQty);
            } else {
                totalQuantityMap.put(ird.Purchase_Order_Line_Item__c,totalQty);
            }
        }
        
        // Validation
        for (Item_Received_Details__c ird : newList) {
            if (ird.Purchase_Order_Line_Item__c == null) {
                continue;
            }
            
            Decimal totalQty = totalQuantityMap.get(ird.Purchase_Order_Line_Item__c);
            Decimal poliQty = poliQuantityMap.get(ird.Purchase_Order_Line_Item__c);
            
            if (totalQty > poliQty) {
                ird.addError(
                    'Received Quantity + Damaged Quantity cannot be greater than the Purchase Order Line Item Quantity.'
                );
            }
        }
    }
}