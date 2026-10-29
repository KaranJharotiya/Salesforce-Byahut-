public class AccountTriggerHandlerHelper {

    
    public static void copyShippingIntoBillingAddress(List<Account> accountList, Map<Id, Account> oMap, Schema.SObjectType sot, String params, Boolean debug){
        for(Account acc : accountList){
            if(acc.Same_As_Shipping_Address__c == true){
                if(acc.Shipping_Address_1__c != null)
                acc.Billing_Address_1__c = acc.Shipping_Address_1__c;
                
                if(acc.Shipping_Address_2__c != null)
                acc.Billing_Address_2__c = acc.Shipping_Address_2__c;
                
                if(acc.Shipping_Address_3__c != null)
                acc.Billing_Address_3__c = acc.Shipping_Address_3__c;
                
                if(acc.Shipping_Country__c != null)
                acc.Billing_Country__c = acc.Shipping_Country__c;
                
                if(acc.Shipping_State__c != null)
                acc.Billing_State__c = acc.Shipping_State__c;
                
                if(acc.Shipping_City__c != null)
                acc.Billing_City__c = acc.Shipping_City__c;
                
                if(acc.Shipping_Zip_Code__c != null)
                acc.Billing_Zip_Code__c = acc.Shipping_Zip_Code__c;
            }
        }
    }
}