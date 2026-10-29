public class POLI_Trigger_Helper {
    
    /*public static void putReceivedDate(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap,Schema.SObjectType sot, String params, Boolean debug){
        
        for(SObject obj : n){
            if(obj.get('Status__c') == 'Received' && obj.get('Status__c') != oMap.get((Id)obj.get('Id')).get('Status__c')){
                obj.put('Received_Date__c', Date.today());
            }
        }
    }*/
    
    /*public static void completePO(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap,Schema.SObjectType sot, String params, Boolean debug){
        Set<Id> poIdSet = new Set<Id>();
        
        for(SObject obj : n){
            if(obj.get('Status__c') != oMap.get((Id)obj.get('Id')).get('Status__c')){
                poIdSet.add((Id)obj.get('Product__c'));
            }
        }
        
        Map<Id,Product__c> productMap = new Map<Id,Product__c>([Select Id, Stock__c From Product__c Where Id IN :poIdSet]);
        for(SObject obj : n){
            
            if(obj.get('Status__c') == 'Received' && obj.get('Status__c') != oMap.get((Id)obj.get('Id')).get('Status__c')){
                Decimal qty = productMap.get((Id)obj.get('Product__c')).Stock__c != null ? productMap.get((Id)obj.get('Product__c')).Stock__c : 0;
                Decimal totalQty = qty + (Decimal) obj.get('Quantity__c');
                productMap.get((Id)obj.get('Product__c')).Stock__c= totalQty;
            }else if(obj.get('Status__c') != 'Received' && obj.get('Status__c') != oMap.get((Id)obj.get('Id')).get('Status__c')) {
                Decimal qty = productMap.get((Id)obj.get('Product__c')).Stock__c != null ? productMap.get((Id)obj.get('Product__c')).Stock__c : 0;
                Decimal totalQty = qty - (Decimal) obj.get('Quantity__c');
                productMap.get((Id)obj.get('Product__c')).Stock__c= totalQty;
            }
        }
        
        if(!productMap.isEmpty()){
            Update productMap.values();
        }
        
        if(!PoIdSet.isEmpty()){
            List<Purchase_Order__c> toBeUpdatePoList = new List<Purchase_Order__c>();
            List<Purchase_Order__c> poList = [Select Id, (Select Id From Purchase_Order_Line_Item__r Where Status__c != 'Received') From Purchase_Order__c Where Id IN :poIdSet];
            for(Purchase_Order__c po : poList){
                if(po.Purchase_Order_Line_Item__r.isEmpty()){
                    toBeUpdatePoList.add(new Purchase_Order__c(Id = po.Id, Status__c = 'Completed', Is_From_Child__c = true));
                }else {
                    toBeUpdatePoList.add(new Purchase_Order__c(Id = po.Id, Status__c = 'Pending', Is_From_Child__c = true));
                    
                }
            }
            
            if(!toBeUpdatePoList.isEmpty()){
                Update toBeUpdatePoList;
                for(Purchase_Order__c po : toBeUpdatePoList){
                    po.Is_From_Child__c = false;
                }
                Update toBeUpdatePoList;
            }
        }
    }*/
    
    /*public static void updateProQuantityAndPO(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap,Schema.SObjectType sot, String params, Boolean debug){ 
        
        Map<Id,Purchase_Order_Line_Item__c> mapofProductsIdWithLineItems = new Map<Id,Purchase_Order_Line_Item__c>();
        Map<Id,Purchase_Order_Line_Item__c> purchaseOrderItemMap =  (Map<Id,Purchase_Order_Line_Item__c>)oMap;
        for(Purchase_Order_Line_Item__c poLineItem : (List<Purchase_Order_Line_Item__c>) n){
            if(poLineItem.Actual_Quantity__c != purchaseOrderItemMap.get(poLineItem.Id).Actual_Quantity__c){
                mapofProductsIdWithLineItems.put(poLineItem.Product__c,poLineItem);
            }
        }
        
        if(!mapofProductsIdWithLineItems.IsEmpty()){
            
            List<Product__c> lstProductRec = [SELECT Id,Stock__c FROM Product__c WHERE Id IN : mapofProductsIdWithLineItems.keySet()];
            List<Product__c> toUpdatelstProducts = new List<Product__c>();
            for(Product__c product : lstProductRec){
                product.Stock__c += mapofProductsIdWithLineItems.get(product.Id).Actual_Quantity__c;
                toUpdatelstProducts.add(product);
            }
            
            if(!toUpdatelstProducts.IsEmpty()){
                update toUpdatelstProducts;
            }
        }
    }*/
    
    public static void updatePOStatusIfAllOrderReceived(List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap,Schema.SObjectType sot, String params, Boolean debug){
        
        Set<Id> purchaseOrderIds = new Set<Id>();
        Map<Id,Purchase_Order_Line_Item__c> purchaseOrderItemMap =  (Map<Id,Purchase_Order_Line_Item__c>)oMap;
        for(Purchase_Order_Line_Item__c poLineItem : (List<Purchase_Order_Line_Item__c>) n){
            if(poLineItem.Fully_Received__c != purchaseOrderItemMap.get(poLineItem.Id).Fully_Received__c){
                purchaseOrderIds.add(poLineItem.Purchase_Order__c);
            }
        }
        if (!purchaseOrderIds.isEmpty()) {
            
            List<Purchase_Order__c> lineItemPORecords = [
                SELECT Id, Status__c
                FROM Purchase_Order__c
                WHERE Id IN :purchaseOrderIds
            ];
            
            List<Purchase_Order_Line_Item__c> purchaseOrderLineItems = [
                SELECT Id, Fully_Received__c, Purchase_Order__c
                FROM Purchase_Order_Line_Item__c
                WHERE Purchase_Order__c IN :purchaseOrderIds
            ];
            
            Map<Id, Boolean> PORecMap = new Map<Id, Boolean>();
            
            for (Purchase_Order_Line_Item__c purchaseOrderItem : purchaseOrderLineItems) {
                
                Id poId = purchaseOrderItem.Purchase_Order__c;
                
                if (!PORecMap.containsKey(poId)) {
                    PORecMap.put(poId, purchaseOrderItem.Fully_Received__c);
                } else if (!purchaseOrderItem.Fully_Received__c) {
                    PORecMap.put(poId, false);
                }
            }
            
            if(!PORecMap.IsEmpty()){
                List<Purchase_Order__c> purchaseOrederReclst = [SELECT Id,Status__c FROM Purchase_Order__c WHERE Id IN : PORecMap.keySet()];
                List<Purchase_Order__c> toUpdatePOStatus = new List<Purchase_Order__c>();
                for(Purchase_Order__c PORec : purchaseOrederReclst){
                    if(PORecMap.get(PORec.Id) == true){
                        PORec.Status__c = 'Fully Received';
                        toUpdatePOStatus.add(PORec);
                    }else if(PORecMap.get(PORec.Id) == false){
                        PORec.Status__c = 'Partial Received';
                        toUpdatePOStatus.add(PORec);
                    }
                }
                
                if(!toUpdatePOStatus.IsEmpty()){
                    update toUpdatePOStatus;
                }
            }
        }
    }
}