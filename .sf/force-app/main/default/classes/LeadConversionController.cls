public class LeadConversionController {
    
    @AuraEnabled 
    public static responseWrapper convertLead(Id leadId){
        try{
            if(leadId == null){
                return null;
            }
            
            responseWrapper response = new responseWrapper();
            List<Lead__c> leadList = [SELECT Id, Name, Amount__c, Company_Name__c, Contact_Number__c, Email__c,Payment_Terms__c,
                                     Shipping_Address_1__c, Shipping_Address_2__c, Shipping_Address_3__c, Country_Shipping__c,
                                     State_Shipping__c, City_Shipping__c, ShippingZip_Code__c, Address_1__c, Address_2__c,
                                     Address_3__c, Country_Billing__c, State_Billing__c, City_Billing__c, Zip_Code__c, Company_Type__c,
                                     PAN__c, TAN__c, GST_Number__c, Street_1__c, Street_2__c, City__c, State__c, Pin_Code__c, Landmark__c,Drug_License__c
                                     FROM Lead__c WHERE Id = :leadId LIMIT 1];
            
            if(leadList.isEmpty()){
                return null; 
            }
            
            Lead__c lead = leadList[0];
            
            // List<Cart_Line_Item__c> cartLineItemList = [SELECT Id, Lead__c, Opportunity__c FROM Cart_Line_Item__c WHERE Lead__c = :lead.Id];
            List<Quotation__c> quotationReclst = [SELECT Id, Lead__c, Opportunity__c FROM Quotation__c WHERE Lead__c = :lead.Id];
            List<Account> lstofAccounts = new List<Account>();
            
            if(String.isNotBlank(lead.Company_Type__c) && lead.Company_Type__c == 'Dealer' && String.isNotBlank(lead.GST_Number__c)){
                lstofAccounts = [SELECT Id, GST_Number__c FROM Account WHERE GST_Number__c = :lead.GST_Number__c ORDER BY CreatedDate DESC LIMIT 1];
            }
            
            Account acc = new Account();
            
            if(lstofAccounts.isEmpty() || lead.Company_Type__c == 'End User'){
                String companyName = String.isNotBlank(lead.Company_Name__c)? lead.Company_Name__c.trim(): (lead.Name != null ? lead.Name.trim() : null);
                    if (companyName != null && companyName.length() > 80) {
                        companyName = companyName.substring(0, 80);
                    }
                acc.Name = companyName;
                acc.Phone = lead.Contact_Number__c;
                acc.Shipping_Address_1__c = lead.Shipping_Address_1__c;
                acc.Shipping_Address_2__c = lead.Shipping_Address_2__c;
                acc.Shipping_Address_3__c = lead.Shipping_Address_3__c;
                acc.Shipping_Country__c = lead.Country_Shipping__c;
                acc.Shipping_State__c = lead.State_Shipping__c;
                acc.Shipping_City__c = lead.City_Shipping__c;
                acc.Shipping_Zip_Code__c = lead.ShippingZip_Code__c;
               // acc.Lead__c = lead.Id;
                acc.Billing_Address_1__c = lead.Address_1__c;
                acc.Billing_Address_2__c = lead.Address_2__c;
                acc.Billing_Address_3__c = lead.Address_3__c;
                acc.Billing_Country__c = lead.Country_Billing__c;
                acc.Billing_State__c = lead.State_Billing__c;
                acc.Billing_City__c = lead.City_Billing__c;
                acc.Billing_Zip_Code__c = lead.Zip_Code__c;
                acc.GST_Number__c = lead.GST_Number__c;
                
                insert acc;
            } else {
                acc = lstofAccounts[0];
            }
            
            Account createdAccount = new Account();
            if(acc.Id != null){
                List<Account> accResList = [SELECT Id, Name, Type, Phone, website, Owner.Name, Site FROM Account WHERE Id = :acc.Id LIMIT 1];
                if(!accResList.isEmpty()){
                    createdAccount = accResList[0];
                }
            }
            
            Contact con = new Contact();
            con.AccountId = acc.Id;
            con.LastName = String.isNotBlank(lead.Name) ? lead.Name : 'Contact';
            con.Email = lead.Email__c;
            con.Phone = lead.Contact_Number__c;
            con.PAN__c = lead.PAN__c;
            con.TAN__c = lead.TAN__c;
            con.GST_Number__c = lead.GST_Number__c;
            con.Drug_License__c = lead.Drug_License__c;
            con.Payment_Terms__c = lead.Payment_Terms__c;
           // con.Lead__c = lead.Id;
            con.Shipping_Address_1__c = lead.Shipping_Address_1__c;
            con.Shipping_Address_2__c = lead.Shipping_Address_2__c;
            con.Shipping_Address_3__c = lead.Shipping_Address_3__c;
            con.Shipping_Country__c = lead.Country_Shipping__c;
            con.Shipping_State__c = lead.State_Shipping__c;
            con.Shipping_City__c = lead.City_Shipping__c;
            con.Shipping_Zip_Code__c = lead.ShippingZip_Code__c;
            
            con.Billing_Address_1__c = lead.Address_1__c;
            con.Billing_Address_2__c = lead.Address_2__c;
            con.Billing_Address_3__c = lead.Address_3__c;
            con.Billing_Country__c = lead.Country_Billing__c;
            con.Billing_State__c = lead.State_Billing__c;
            con.Billing_City__c = lead.City_Billing__c;
            con.Billing_Zip_Code__c = lead.Zip_Code__c;
            
            insert con;
            
            Contact createdContact = new Contact();
            if(con.Id != null){
                List<Contact> conResList = [SELECT Id, firstName, lastName, Title, Account.Name, Phone, Email, MobilePhone FROM Contact WHERE Id = :con.Id LIMIT 1];
                if(!conResList.isEmpty()){
                    createdContact = conResList[0];
                }
            }
            
            Opportunity__c opp = new Opportunity__c();
            opp.Account_Name__c = acc.Id;
            opp.Contact__c = con.Id;
            // opp.Lead__c = lead.Id;
            String leadName = String.isNotBlank(lead.Name) ? lead.Name.trim() : null;
            String companyName = String.isNotBlank(lead.Company_Name__c) ? lead.Company_Name__c.trim() : null;
            
            String opportunityName;
            
            if (String.isNotBlank(leadName) && String.isNotBlank(companyName)) {
                opportunityName = leadName + '_' + companyName;
            } else if (String.isNotBlank(leadName)) {
                opportunityName = leadName;
            } else if (String.isNotBlank(companyName)) {
                opportunityName = companyName;
            }
            
            if (String.isNotBlank(opportunityName)) {
                if (opportunityName.length() > 80) {
                    opportunityName = opportunityName.substring(0, 80);
                }
                opp.Name = opportunityName;
            }
            opp.Stage__c = 'Qualification';
            opp.Close_Date__c = System.today();
            opp.Amount__c = lead.Amount__c;
            if(!quotationReclst.isEmpty()){
                opp.Status__c = 'Quotation';
            }
            insert opp;
            
            Opportunity__c createdOpportunity = new Opportunity__c();
            if(opp.Id != null){
                List<Opportunity__c> oppResList = [SELECT Id, Name, Account_Name__r.Name, Close_Date__c, Amount__c, Owner.Name FROM Opportunity__c WHERE Id = :opp.Id LIMIT 1];
                if(!oppResList.isEmpty()){
                    createdOpportunity = oppResList[0];
                }
            }
            
            // 1. Link Quotations to Opportunity
            if(!quotationReclst.isEmpty()){
                for(Quotation__c q : quotationReclst){
                    q.Opportunity__c = opp.Id;
                }
                update quotationReclst;
            }
            
            // 2. Link Activities (Tasks & Events) to Opportunity
            List<Task> taskList = [SELECT Id, WhatId FROM Task WHERE WhatId = :lead.Id];
            if(!taskList.isEmpty()){
                for(Task t : taskList){
                    t.WhatId = opp.Id;
                }
                update taskList;
            }
            
            List<Event> eventList = [SELECT Id, WhatId FROM Event WHERE WhatId = :lead.Id];
            if(!eventList.isEmpty()){
                for(Event ev : eventList){
                    ev.WhatId = opp.Id;
                }
                update eventList;
            }
            
            // 3. Link Files (ContentDocumentLink) to Opportunity
            List<ContentDocumentLink> leadFiles = [SELECT ContentDocumentId, ShareType, Visibility FROM ContentDocumentLink WHERE LinkedEntityId = :lead.Id];
            if(!leadFiles.isEmpty()){
                List<ContentDocumentLink> oppFiles = new List<ContentDocumentLink>();
                for(ContentDocumentLink fileLink : leadFiles){
                    oppFiles.add(new ContentDocumentLink(
                        ContentDocumentId = fileLink.ContentDocumentId,
                        LinkedEntityId = opp.Id,
                        ShareType = fileLink.ShareType,
                        Visibility = fileLink.Visibility
                    ));
                }
                insert oppFiles;
            }
            
            // Link Converted Account, Contact, and Opportunity to Lead
            lead.Converted_Account__c = acc.Id;
            lead.Converted_Contact__c = con.Id;
            lead.Converted_Opportunity__c = opp.Id;
            lead.Converted_Date__c = System.today();
            lead.Converted_By__c = UserInfo.getUserId();
            update lead;
            
            response.acc = createdAccount;
            response.con = createdContact;
            response.opp = createdOpportunity;
            
            return response;
            
        } catch(Exception e){   
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public class responseWrapper {
        @AuraEnabled public Account acc;
        @AuraEnabled public Contact con;
        @AuraEnabled public Opportunity__c opp;
    }
}