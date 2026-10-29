public class SalesOrderTriggerHelper {
    
    public static void assignSalesOrderToCartItem(
        List<SObject> n, Map<Id, SObject> nMap, List<SObject> o, Map<Id, SObject> oMap, 
        Schema.SObjectType sot, String params, Boolean debug){
            /*
            Set<Id> oppIdSet = new Set<Id>();
            for(SObject obj : n){
                Id opportunityId = (Id)obj.get('Opportunity__c');
                if(opportunityId != null){
                    oppIdSet.add(opportunityId);
                }
            }
            
            if(!oppIdSet.isEmpty()){
                
                Map<Id,Opportunity__c> opportunityCartItemMap = new Map<Id,Opportunity__c>(
                    [Select Id, (Select Id, Sales_Order__c From Cart_Line_Items__r) From Opportunity__c Where Id IN :oppIdSet]);
                
                List<Cart_Line_Item__c> cartLineItemList = new List<Cart_Line_Item__c>();
                
                for(SObject obj : n){
                    Id salesOrderId = (Id)obj.get('Id');
                    Id opportunityId = (Id)obj.get('Opportunity__c');
                    if(opportunityId != null){
                        for(Cart_Line_Item__c cli : opportunityCartItemMap.get(opportunityId).Cart_Line_Items__r){
                            cartLineItemList.add(new Cart_Line_Item__c(Id=cli.Id, Sales_Order__c=salesOrderId));
                        }
                    }
                }
                
                if(!cartLineItemList.isEmpty()){
                    Update cartLineItemList;
                }
                
            }
*/
        }
}