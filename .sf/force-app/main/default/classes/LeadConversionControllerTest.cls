@isTest
public class LeadConversionControllerTest {
    
    @testSetup
    static void dataFactory() {
            /*
            Lead_Address__Street__s = 'MG Road',
            Lead_Address__City__s = 'Bangalore',
            Lead_Address__StateCode__s = 'KA',
            Lead_Address__CountryCode__s = 'IN',
            Lead_Address__PostalCode__s = '560001',
            */
        Lead__c lead = new Lead__c(
            Name = 'Test Lead',
            Amount__c = 5000,
            Company_Name__c = 'Tech Corp',
            Contact_Number__c = '9876543210',
            Email__c = 'testlead@example.com',
        
            Street_1__c = '12 Main Street',
            Street_2__c = 'Near Metro Station',
            City__c = 'Bangalore',
            State__c = 'Karnataka',
            Pin_Code__c = '560001',
            Landmark__c = 'Opposite Mall'
        );
        
        insert lead;
    }
    
    @isTest
    static void convertLeadTest(){
        Lead__c lead = [Select Id, Name, Amount__c, Company_Name__c, Contact_Number__c, Email__c, 
                       /*
                        Lead_Address__Street__s, Lead_Address__City__s,
                     Lead_Address__StateCode__s, Lead_Address__CountryCode__s, Lead_Address__PostalCode__s, 
                        */
                        Street_1__c, Street_2__c,
                     City__c, State__c, Pin_Code__c, Landmark__c
                     From Lead__c];
        LeadConversionController.convertLead(lead.Id);
    }
    
}