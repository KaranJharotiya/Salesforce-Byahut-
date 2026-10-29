public class ContactTriggerHandlerHalper {

    public static void copyShippingIntoBillingAddress(List<Contact> contactList, Map<Id, Contact> oMap, Schema.SObjectType sot, String params, Boolean debug){
        for(Contact obj : contactList){
            if(obj.Same_As_Shipping_Address__c == true){
                if(obj.Shipping_Address_1__c != null)
                obj.Billing_Address_1__c = obj.Shipping_Address_1__c;
                
                if(obj.Shipping_Address_2__c != null)
                obj.Billing_Address_2__c = obj.Shipping_Address_2__c;
                
                if(obj.Shipping_Address_3__c != null)
                obj.Billing_Address_3__c = obj.Shipping_Address_3__c;
                
                if(obj.Shipping_Country__c != null)
                obj.Billing_Country__c = obj.Shipping_Country__c;
                
                if(obj.Shipping_State__c != null)
                obj.Billing_State__c = obj.Shipping_State__c;
                
                if(obj.Shipping_City__c != null)
                obj.Billing_City__c = obj.Shipping_City__c;
                
                if(obj.Shipping_Zip_Code__c != null)
                obj.Billing_Zip_Code__c = obj.Shipping_Zip_Code__c;
            }
        }
    }
}