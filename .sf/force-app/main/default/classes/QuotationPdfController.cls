public class QuotationPdfController {
    
    public static List<String> paymentTermsAndConditions{get;set;}
    public static List<String> dispatchTermsAndConditions{get;set;}
    public static utilityWrapper utilityWrapperObj{get;set;}
    public Id recordId {get;set;}
    public Id quotationId {get;set;} // Selected Quotation Id
    public List<Quotation_Line_Items__c> quotationLineItemList {get;set;}
    public String totalWords{get;set;}
    public String toEmail{get;set;}
    public Date qDate{get;set;}
    public Bank_Detail__c bankDetail{get;set;}
    public Boolean isBankDetailQueried{get;set;}
    public String shippingAddress{get;set;}
    public String billingAddress{get;set;}
    public Boolean isBrandVisible{get;set;}
    public Boolean isCasNumberVisible{get;set;}
    public Boolean isCodeVisible{get;set;}
    public Boolean isGradeVisible{get;set;}
    
    // Tax Calculation Properties
    public Decimal totalTaxableValue {get;set;}
    public Decimal igstAmount {get;set;}
    public Decimal cgstAmount {get;set;}
    public Decimal sgstAmount {get;set;}
    public Decimal grandTotalWithGst {get;set;}
    public String quotationNumber{get;set;}
    public QuotationPdfController() {
        
        utilityWrapperObj = new utilityWrapper();
        
        isBrandVisible = false;
        isCasNumberVisible = false;
        isCodeVisible = false;
        isGradeVisible = false;
        
        totalTaxableValue = 0;
        igstAmount = 0;
        cgstAmount = 0;
        sgstAmount = 0;
        grandTotalWithGst = 0;
        quotationNumber = '';
        recordId = ApexPages.currentPage().getParameters().get('id');
        System.debug('recordId' + recordId);
        String quotationParam = ApexPages.currentPage().getParameters().get('quotationId');
        System.debug('quotationParam' + quotationParam);
        if(String.isNotBlank(quotationParam)) {
            quotationId = (Id)quotationParam;
        }
        
        String selectedColumns = ApexPages.currentPage().getParameters().get('columns');
        
        if(String.isNotBlank(selectedColumns)) {
            // Decode just in case
            selectedColumns = EncodingUtil.urlDecode(selectedColumns, 'UTF-8');
            
            Set<String> columnSet = new Set<String>();
            for(String col : selectedColumns.split(',')) {
                columnSet.add(col.trim());
            }
            
            isBrandVisible     = columnSet.contains('Brand__c');
            isCasNumberVisible = columnSet.contains('CAS_Number__c');
            isCodeVisible      = columnSet.contains('Code__c');
            isGradeVisible     = columnSet.contains('Grade__c');
        }
        
        if(recordId == null) {
            quotationLineItemList = new List<Quotation_Line_Items__c>();
            return;
        }
        isBankDetailQueried = false;
        List<Bank_Detail__c> bankDetailList = getBankDetails(recordId);
        if(bankDetailList != null && !bankDetailList.isEmpty()){
            isBankDetailQueried = true;
            bankDetail = bankDetailList[0];
        }
        
        Map<String,String> address = getAddress(recordId);
        shippingAddress = address.get('shipping');
        billingAddress = address.get('billing');
        
        quotationLineItemList = getQuotationLineItems(recordId, quotationId);
        
        if(quotationLineItemList.isEmpty()){
            quotationLineItemList = new List<Quotation_Line_Items__c>();
            return;
        }
        
        qDate = Date.valueOf(quotationLineItemList[0].CreatedDate);
        
        Decimal total = 0;
        Decimal totalGstSum = 0;
        List<Quotation__c> quotationReclst = [SELECT Id,Name FROM Quotation__c WHERE Id =: quotationId LIMIT 1];
        if(!quotationReclst.IsEmpty()){
            quotationNumber = 'BS/' + System.Label.Current_Financial_Year + '/' + quotationReclst[0].Name;
        }
        for(Quotation_Line_Items__c item : quotationLineItemList){
            if(item.Total_Amount__c != null) {
                total += item.Total_Amount__c;
            }
            
            // Taxable Value
            Decimal taxableVal = item.After_Discount__c != null ? item.After_Discount__c : (item.Total_Amount__c != null ? item.Total_Amount__c : 0);
            totalTaxableValue += taxableVal;
            
            // GST calculation per line
            if(item.GST__c != null && item.GST__c > 0) {
                totalGstSum += (taxableVal * item.GST__c) / 100;
            }
        }
        
        totalTaxableValue = totalTaxableValue.setScale(2);
        totalGstSum = totalGstSum.setScale(2);
        
        // Billing State check
        String billingState = getBillingState(recordId, quotationId);
        Boolean isRajasthan = false;
        if(String.isNotBlank(billingState) && billingState.trim().equalsIgnoreCase('Rajasthan')) {
            isRajasthan = true;
        }
        
        if(isRajasthan) {
            cgstAmount = (totalGstSum / 2).setScale(2);
            sgstAmount = (totalGstSum / 2).setScale(2);
            igstAmount = 0;
        } else {
            igstAmount = totalGstSum;
            cgstAmount = 0;
            sgstAmount = 0;
        }
        
        grandTotalWithGst = (totalTaxableValue + totalGstSum).setScale(2);
        
        system.debug('total >> '+total);
        totalWords = toIndianRupeesWords(grandTotalWithGst);
    }
    
    // Billing State check: Lead ya Opportunity ke Account se
    private static String getBillingState(Id recId, Id qId) {
        String stateName = '';
        String objectName = recId != null ? recId.getSObjectType().getDescribe().getName() : '';
        
        // Agar recordId Quotation__c object ka ho
        if(objectName == 'Quotation__c' || (recId == null && qId != null)) {
            Id effectiveQId = (recId != null && objectName == 'Quotation__c') ? recId : qId;
            Quotation__c q = [SELECT Id, Lead__c, Opportunity__c FROM Quotation__c WHERE Id = :effectiveQId LIMIT 1];
            if(q.Opportunity__c != null) {
                recId = q.Opportunity__c;
                objectName = 'Opportunity__c';
            } else if(q.Lead__c != null) {
                recId = q.Lead__c;
                objectName = 'Lead__c';
            }
        }
        
        if(objectName == 'Lead__c') {
            Lead__c lead = [SELECT Id, State_Billing__c, State_Billing__r.Name FROM Lead__c WHERE Id = :recId LIMIT 1];
            if(lead.State_Billing__r != null && String.isNotBlank(lead.State_Billing__r.Name)) {
                stateName = lead.State_Billing__r.Name;
            } else if(String.isNotBlank(lead.State_Billing__c)) {
                stateName = lead.State_Billing__c;
            }
        } else if(objectName == 'Opportunity__c') {
            Opportunity__c opp = [SELECT Id, Account_Name__c, Account_Name__r.Billing_State__c, Contact__r.Billing_State__r.Name FROM Opportunity__c WHERE Id = :recId LIMIT 1];
            if(opp.Account_Name__r != null && String.isNotBlank(opp.Account_Name__r.Billing_State__c)) {
                stateName = opp.Account_Name__r.Billing_State__c;
            } else if(opp.Contact__r != null && opp.Contact__r.Billing_State__r != null) {
                stateName = opp.Contact__r.Billing_State__r.Name;
            }
        }
        return stateName;
    }
    
    // Naya method Lead ke related Quotations lane ke liye
    @AuraEnabled(cacheable=true)
    public static List<Quotation__c> getQuotationsByLead(Id recordId) {
        System.debug('recordId' + recordId);
        if(recordId == null) return new List<Quotation__c>();
        String objectName = recordId.getSObjectType().getDescribe().getName();
        if(objectName == 'Lead__c'){
            return [SELECT Id, Name FROM Quotation__c WHERE Lead__c = :recordId ORDER BY CreatedDate DESC];     
        }else if(objectName == 'Opportunity__c'){
            return [SELECT Id, Name FROM Quotation__c WHERE Opportunity__c = :recordId ORDER BY CreatedDate DESC];     
        }
        return new List<Quotation__c>();
    }
    
    private static final List<String> belowTwenty = new List<String>{
        '', 'One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Ten',
        'Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'
    };
    private static final List<String> tens = new List<String>{'', '', 'Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'};
    
    public static String toIndianRupeesWords(Decimal amount) {
        Long rupees = (amount == null ? 0 : amount.longValue());
        Integer paise = Math.abs((amount - rupees).setScale(2) * 100).intValue();
        String r = rupees == 0 ? 'Zero' : numberToIndianWords(rupees);
        String p = paise > 0 ? ' and ' + numberToIndianWords(paise) + ' Paise' : '';
        return 'INR ' + r + (p == '' ? ' Only' : p + ' Only');
    }
    
    private static String numberToIndianWords(Long n) {
        if(n == 0) return 'Zero';
        List<String> parts = new List<String>();
        if(n >= 10000000) { parts.add(segmentWords(n/10000000) + ' Crore'); n = Math.mod(n,10000000); }
        if(n >= 100000) { parts.add(segmentWords(n/100000) + ' Lakh'); n = Math.mod(n,100000); }
        if(n >= 1000) { parts.add(segmentWords(n/1000) + ' Thousand'); n = Math.mod(n,1000); }
        if(n >= 100) { parts.add(segmentWords(n/100) + ' Hundred'); n = Math.mod(n,100); }
        if(n > 0 && !parts.isEmpty()) parts.add('and');
        parts.add(segmentWords(n));
        return String.join(parts,' ').replace('  ',' ').trim();
    }
    
    private static String segmentWords(Long n) {
        if(n == null || n == 0) return '';
        if(n < 20) return belowTwenty[Integer.valueOf(n)];
        if(n < 100) {
            Integer t = Integer.valueOf(n/10);
            Integer u = Integer.valueOf(Math.mod(n,10));
            return tens[t] + (u>0 ? ' '+belowTwenty[u] : '');
        }
        Integer h = Integer.valueOf(n/100);
        Long rest = Math.mod(n,100);
        return belowTwenty[h] + ' Hundred' + (rest>0 ? ' '+segmentWords(rest) : '');
    }
    
    @AuraEnabled
    public static String sendEmail(Id recordId){
        String toEmail;
        String objectName = recordId.getSObjectType().getDescribe().getName();
        
        if(objectName == 'Lead__c') {
            Lead__c lead = [SELECT Email__c, CreatedDate FROM Lead__c WHERE Id = :recordId];
            toEmail = lead.Email__c;
        } else if(objectName == 'Opportunity__c') {
            Opportunity__c opp = [SELECT CreatedDate, Contact__r.Email FROM Opportunity__c WHERE Id = :recordId];
            if(opp.Contact__r != null) {
                toEmail = opp.Contact__r.Email;
            }
        }
        
        if(String.isBlank(toEmail)){
            throw new AuraHandledException('No Email Found');
        }
        
        PageReference pdfPage = Page.QuotationPdf;
        pdfPage.getParameters().put('id', recordId);
        
        Blob pdfBlob;
        if(Test.isRunningTest()){
            pdfBlob = Blob.valueOf('Test PDF');
        } else {
            pdfBlob = pdfPage.getContentAsPDF();
        }
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { toEmail });
        email.setSubject('Quotation PDF');
        email.setPlainTextBody('Please find attached quotation.');
        
        OrgWideEmailAddress owea = [
            SELECT Id, Address
            FROM OrgWideEmailAddress 
            LIMIT 1
        ];
        
        email.setOrgWideEmailAddressId(owea.Id);
        
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('Quotation.pdf');
        attachment.setBody(pdfBlob);
        attachment.setContentType('application/pdf');
        
        email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
        
        try{
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            if (results[0].isSuccess()) { 
                return 'Email sent successfully!'; 
            } else { 
                throw new AuraHandledException('Email Not sent successfully');
            }
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Mobile app ke liye: PDF generate karke File (ContentVersion) me save karein aur ContentDocumentId return karein
    @AuraEnabled
    public static Id generateQuotationPdfFile(Id recordId, Id quotationId, String columns){
        try{
            PageReference pdfPage = Page.QuotationPdf;
            pdfPage.getParameters().put('id', recordId);
            if(quotationId != null){
                pdfPage.getParameters().put('quotationId', quotationId);
            }
            if(String.isNotBlank(columns)){
                pdfPage.getParameters().put('columns', columns);
            }

            Blob pdfBlob;
            if(Test.isRunningTest()){
                pdfBlob = Blob.valueOf('Test PDF');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            String fileName = 'Quotation';
            if(quotationId != null){
                List<Quotation__c> quotes = [SELECT Name FROM Quotation__c WHERE Id = :quotationId LIMIT 1];
                if(!quotes.isEmpty()){
                    fileName = quotes[0].Name;
                }
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName + '.pdf';
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = recordId;
            insert cv;

            return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean hasQuotationLineItem(Id recordId, Id quotationId){
        List<Quotation_Line_Items__c> items = getQuotationLineItems(recordId, quotationId);
        return items.size() > 0;
    }
    
    public static List<Quotation_Line_Items__c> getQuotationLineItems(Id recordId, Id quotationId){
        List<Quotation_Line_Items__c> itemsList = new List<Quotation_Line_Items__c>();
        if(quotationId != null) {
            itemsList = [
                SELECT Id, Name, Quotation__c, Discount__c, After_Discount__c, GST__c, 
                Product__c, Product__r.Name, Product__r.Image_URL__c,
                Product__r.Grade__c, Product__r.Code__c, Product__r.CAS_Number__c,
                Product__r.Brand__r.Name, Product__r.Pack_Size__c,
                Quantity__c, Amount__c, Total_Amount__c, CreatedDate
                FROM Quotation_Line_Items__c
                WHERE Quotation__c = :quotationId
            ];
        } else if(recordId != null) {
            String objectName = recordId.getSObjectType().getDescribe().getName();
            if(objectName == 'Lead__c') {
                itemsList = [
                    SELECT Id, Name, Quotation__c, Discount__c, After_Discount__c, GST__c, 
                    Product__c, Product__r.Name, Product__r.Image_URL__c,
                    Product__r.Grade__c, Product__r.Code__c, Product__r.CAS_Number__c,
                    Product__r.Brand__r.Name, Product__r.Pack_Size__c,
                    Quantity__c, Amount__c, Total_Amount__c, CreatedDate
                    FROM Quotation_Line_Items__c
                    WHERE Quotation__r.Lead__c = :recordId
                ];
            }
        }
        return itemsList;
    }
    
    public static Map<String,String> getAddress(Id recordId){
        Map<String,String> address = new Map<String,String>();
        String objectName = recordId.getSObjectType().getDescribe().getName();
        
        if(objectName == 'Lead__c'){
            Lead__c lead = [SELECT Id, Bank__c, Contact_Number__c, Email__c, GST_Number__c, Payment_Terms__c, PAN__C,Drug_License__c,TAN__C,
                            Shipping_Address_1__c, Shipping_Address_2__c, Shipping_Address_3__c,
                            Country_Shipping__r.Name, State_Shipping__r.Name, City_Shipping__r.Name, ShippingZip_Code__c,
                            Address_1__c, Address_2__c, Address_3__c,
                            Country_Billing__r.Name, State_Billing__r.Name, City_Billing__r.Name,
                            Zip_Code__c, CreatedBy.Name
                            FROM Lead__c WHERE Id = :recordId];
            
            utilityWrapperObj.contactNumber = lead.Contact_Number__c;
            utilityWrapperObj.Email = lead.Email__c;
            utilityWrapperObj.gstNumber = lead.GST_Number__c;
            utilityWrapperObj.paymentTerm = lead.Payment_Terms__c;
            utilityWrapperObj.createdBy = lead.CreatedBy.Name;
            utilityWrapperObj.pan = lead.PAN__C;
            utilityWrapperObj.tan = lead.TAN__C;
            utilityWrapperObj.drugLicense = lead.Drug_License__c;
            
            List<String> shipping = new List<String>();
            if(lead.Shipping_Address_1__c != null) shipping.add(lead.Shipping_Address_1__c + ' ');
            if(lead.Shipping_Address_2__c != null) shipping.add(lead.Shipping_Address_2__c + ' ');
            if(lead.Shipping_Address_3__c != null) shipping.add(lead.Shipping_Address_3__c + ' ');
            if(lead.Country_Shipping__r != null) shipping.add(lead.Country_Shipping__r.Name + ' ');
            if(lead.State_Shipping__r != null) shipping.add(lead.State_Shipping__r.Name + ' ');
            if(lead.City_Shipping__r != null) shipping.add(lead.City_Shipping__r.Name + ' ');
            if(lead.ShippingZip_Code__c != null) shipping.add(lead.ShippingZip_Code__c + ' ');
            address.put('shipping', String.join(shipping, ', '));
            
            List<String> billing = new List<String>();
            if(lead.Address_1__c != null) billing.add(lead.Address_1__c + ' ');
            if(lead.Address_2__c != null) billing.add(lead.Address_2__c + ' ');
            if(lead.Address_3__c != null) billing.add(lead.Address_3__c + ' ');
            if(lead.Country_Billing__r != null) billing.add(lead.Country_Billing__r.Name + ' ');
            if(lead.State_Billing__r != null) billing.add(lead.State_Billing__r.Name + ' ');
            if(lead.City_Billing__r != null) billing.add(lead.City_Billing__r.Name + ' ');
            if(lead.Zip_Code__c != null) billing.add(lead.Zip_Code__c + ' ');
            address.put('billing', String.join(billing, ', '));
        }
        else if(objectName == 'Opportunity__c'){
            Opportunity__c opportunity = [SELECT Id, Bank__c, Contact__r.Phone, Contact__r.Email, Contact__r.GST_Number__c,
                                          Contact__r.Payment_Terms__c, Contact__r.CreatedBy.Name, Contact__r.PAN__C,Contact__r.Drug_License__c, Contact__r.TAN__C,
                                          Contact__r.Shipping_Address_1__c, Contact__r.Shipping_Address_2__c, Contact__r.Shipping_Address_3__c,
                                          Contact__r.Shipping_Country__r.Name, Contact__r.Shipping_State__r.Name, Contact__r.Shipping_City__r.Name, Contact__r.Shipping_Zip_Code__c,
                                          Contact__r.Billing_Address_1__c, Contact__r.Billing_Address_2__c, Contact__r.Billing_Address_3__c,
                                          Contact__r.Billing_Country__r.Name, Contact__r.Billing_State__r.Name, Contact__r.Billing_City__r.Name, Contact__r.Billing_Zip_Code__c
                                          FROM Opportunity__c WHERE Id = :recordId];
            
            utilityWrapperObj.contactNumber = opportunity.Contact__r.Phone;
            utilityWrapperObj.Email = opportunity.Contact__r.Email;
            utilityWrapperObj.gstNumber = opportunity.Contact__r.GST_Number__c;
            utilityWrapperObj.paymentTerm = opportunity.Contact__r.Payment_Terms__c;
            utilityWrapperObj.createdBy = opportunity.Contact__r.CreatedBy.Name;
            utilityWrapperObj.pan = opportunity.Contact__r.PAN__C;
            utilityWrapperObj.tan = opportunity.Contact__r.TAN__C;
            utilityWrapperObj.drugLicense = opportunity.Contact__r.Drug_License__c;
            List<String> shipping = new List<String>();
            if(opportunity.Contact__r.Shipping_Address_1__c != null) shipping.add(opportunity.Contact__r.Shipping_Address_1__c);
            if(opportunity.Contact__r.Shipping_Address_2__c != null) shipping.add(opportunity.Contact__r.Shipping_Address_2__c);
            if(opportunity.Contact__r.Shipping_Address_3__c != null) shipping.add(opportunity.Contact__r.Shipping_Address_3__c);
            if(opportunity.Contact__r.Shipping_City__r != null) shipping.add(opportunity.Contact__r.Shipping_City__r.Name);
            if(opportunity.Contact__r.Shipping_Zip_Code__c != null) shipping.add(opportunity.Contact__r.Shipping_Zip_Code__c);
            if(opportunity.Contact__r.Shipping_Country__r != null) shipping.add(opportunity.Contact__r.Shipping_Country__r.Name);
            if(opportunity.Contact__r.Shipping_State__r != null) shipping.add(opportunity.Contact__r.Shipping_State__r.Name);
            address.put('shipping', String.join(shipping, ', '));
            
            List<String> billing = new List<String>();
            if(opportunity.Contact__r.Billing_Address_1__c != null) billing.add(opportunity.Contact__r.Billing_Address_1__c);
            if(opportunity.Contact__r.Billing_Address_2__c != null) billing.add(opportunity.Contact__r.Billing_Address_2__c);
            if(opportunity.Contact__r.Billing_Address_3__c != null) billing.add(opportunity.Contact__r.Billing_Address_3__c);
            if(opportunity.Contact__r.Billing_City__r != null) billing.add(opportunity.Contact__r.Billing_City__r.Name);
            if(opportunity.Contact__r.Billing_Zip_Code__c != null) billing.add(opportunity.Contact__r.Billing_Zip_Code__c);
            if(opportunity.Contact__r.Billing_Country__r != null) billing.add(opportunity.Contact__r.Billing_Country__r.Name);
            if(opportunity.Contact__r.Billing_State__r != null) billing.add(opportunity.Contact__r.Billing_State__r.Name);
            address.put('billing', String.join(billing, ', '));
        }
        return address;
    }
    
    public static List<Bank_Detail__c> getBankDetails(Id recordId){
        String objectName = recordId.getSObjectType().getDescribe().getName();
        Id bankId;
        String paymentTerms;
        String dispatchTerms;
        
        paymentTermsAndConditions = new List<String>();
        dispatchTermsAndConditions = new List<String>();
        
        if(objectName == 'Lead__c'){
            Lead__c lead = [Select Id, Payment_Terms_Conditions__c, Dispatch_Terms_Conditions__c, Bank__c from Lead__c Where Id = :recordId limit 1];
            bankId = lead.Bank__c;
            if(!String.isBlank(lead.Payment_Terms_Conditions__c)){
                paymentTerms = lead.Payment_Terms_Conditions__c;
            }
            if(!String.isBlank(lead.Dispatch_Terms_Conditions__c)){
                dispatchTerms = lead.Dispatch_Terms_Conditions__c;
            }
        } else if(objectName == 'Opportunity__c'){
            Opportunity__c opp = [Select Id, Payment_Terms_Conditions__c, Dispatch_Terms_Conditions__c, Bank__c from Opportunity__c Where Id = :recordId limit 1];
            bankId = opp.Bank__c;
            if(!String.isBlank(opp.Payment_Terms_Conditions__c)){
                paymentTerms = opp.Payment_Terms_Conditions__c;
            }
            if(!String.isBlank(opp.Dispatch_Terms_Conditions__c)){
                dispatchTerms = opp.Dispatch_Terms_Conditions__c;
            }
        }
        
        if(!String.isBlank(paymentTerms)){
            for(String line : paymentTerms.split('\\r?\\n')){
                if(!String.isBlank(line)){
                    paymentTermsAndConditions.add(line.trim());
                }
            }
        }
        
        if(!String.isBlank(dispatchTerms)){
            for(String line : dispatchTerms.split('\\r?\\n')){
                if(!String.isBlank(line)){
                    dispatchTermsAndConditions.add(line.trim());
                }
            }
        }
        
        if(bankId != null){
            return [Select Id, Name, Account_Type__c, Account_Holder_Name__c, Account_Number__c, 
                    IFSC_Code__c, Branch_Address__c, Status__c
                    From Bank_Detail__c Where Id =: bankId and Status__c = 'Active' limit 1];
        }
        return null;
    }
    
    public class utilityWrapper{
        public String contactNumber{get;set;}
        public String Email{get;set;}
        public String gstNumber{get;set;}
        public String paymentTerm{get;set;}
        public String createdBy{get;set;}
        public String pan{get;set;}
        public String tan{get;set;}
        public String drugLicense{get;set;}
     
    }
}