public class LeadTriggerHandlerHalper {
    
    
    public static void assignDefaultBank(
        List<SObject> n,
        Schema.SObjectType sot, 
        String params, 
        Boolean debug
    ){
        List<Bank_Detail__c> defaultBank = [Select Id from Bank_Detail__c Where Is_Default__c = true limit 1];
        for(SObject obj : n){
            if(obj.get('Bank__c') == null && !defaultBank.isEmpty()){
                obj.put('Bank__c', defaultBank[0].Id);
            }
        }
    }
    
    public static void generateLeadId(List<Lead__c> leadList, Schema.SObjectType sot, String params, Boolean debug){
        List<Lead__c> todayLastCreatedLead = [Select Id, Lead_ID__c From Lead__c 
                                              where CreatedDate = TODAY order by CreatedDate desc limit 1];
        
        String leadId = '0001';
        if(!todayLastCreatedLead.isEmpty()){
            String runningNumber = todayLastCreatedLead[0].Lead_ID__c.substringBetween('_', '_');           
            Integer nextNum = Integer.valueOf(runningNumber) + 1;
            leadId = String.valueOf(nextNum).leftPad(4, '0');  
        }
        
        for(Lead__c lead : leadList){
            Integer day = Integer.valueOf(Date.today().day());
            Integer month = Integer.valueOf(Date.today().month());
            Integer year = Integer.valueOf(Date.today().year());
            Integer uniqueNum = leadId.length();
            lead.Lead_ID__c = 'LEAD_'+leadId+'_'+day+month+year;
        }
    }
   
    public static void assignDecisionMaker(List<Lead__c> n, Map<Id, Lead__c> oMap, Schema.SObjectType sot, String params, Boolean debug){
        Boolean isInsert = trigger.isInsert;
        Boolean isUpdate = trigger.isUpdate;
        
        for(Lead__c lead : n){
            if(lead.Same_as_Lead_Decision_Maker__c == true && 
               (isInsert || (isUpdate && lead.Same_as_Lead_Decision_Maker__c != oMap.get(lead.Id).Same_as_Lead_Decision_Maker__c))){
                lead.Decision_Maker__c = lead.Name;
            }
        }
        
    }
     
    public static void copyBillingAddressIntoShipping(List<Lead__c> leadList, Map<Id, Lead__c> oMap, Schema.SObjectType sot, String params, Boolean debug){
        for(Lead__c lead : leadList){
            if(lead.Same_As_Billing_Address__c == true){
                
                if(lead.Address_1__c != null)
                    lead.Shipping_Address_1__c = lead.Address_1__c;
                
                if(lead.Address_2__c != null)
                    lead.Shipping_Address_2__c = lead.Address_2__c;
                
                if(lead.Address_3__c != null)
                    lead.Shipping_Address_3__c = lead.Address_3__c;
                
                if(lead.Country_Billing__c != null)
                    lead.Country_Shipping__c = lead.Country_Billing__c;
                
                if(lead.State_Billing__c != null)
                    lead.State_Shipping__c = lead.State_Billing__c;
                
                if(lead.City_Billing__c != null)
                    lead.City_Shipping__c = lead.City_Billing__c;
                
                if(lead.Zip_Code__c != null)
                    lead.ShippingZip_Code__c = lead.Zip_Code__c;
            }
        }
    }
}