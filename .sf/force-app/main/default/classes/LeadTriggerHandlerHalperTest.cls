@isTest
public class LeadTriggerHandlerHalperTest {

    @testsetup
    static void dataFactory(){
        Lead__c lead = new Lead__c(Name='test', Lead_ID__c='0001');
        Insert lead;
    }
    
    @isTest
    static void insertLead(){
        Test.StartTest();
        Lead__c lead = new Lead__c(Name='test', Same_As_Billing_Address__c=true,
                                  Address_1__c = 'test',
                                   Address_2__c = 'test',
                                   Address_3__c = 'test'
                                  );
        Insert lead;
        lead.Name += '1';
        update lead;
        Test.StopTest();
    }
}