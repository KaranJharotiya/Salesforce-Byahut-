public class SalesOrderQuotationPdfController {
    
    public Id recordId {get;set;}
    public Id salesOrderId {get;set;}
    public List<Cart_Line_Item__c> cartLineItemList {get;set;}
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
    public static List<String> paymentTermsAndConditions{get;set;}
    public static List<String> dispatchTermsAndConditions{get;set;}
    public static utilityWrapper utilityWrapperObj{get;set;}
    
    // Tax Calculation Properties
    public Decimal totalTaxableValue {get;set;}
    public Decimal igstAmount {get;set;}
    public Decimal cgstAmount {get;set;}
    public Decimal sgstAmount {get;set;}
    public Decimal grandTotalWithGst {get;set;}
    public String salesOrderNumber{get;set;}
    
    public SalesOrderQuotationPdfController() {
        
        utilityWrapperObj = new utilityWrapper();
        salesOrderNumber = '';
        isBrandVisible = false;
        isCasNumberVisible = false;
        isCodeVisible = false;
        isGradeVisible = false;
        
        totalTaxableValue = 0;
        igstAmount = 0;
        cgstAmount = 0;
        sgstAmount = 0;
        grandTotalWithGst = 0;
        
        recordId = ApexPages.currentPage().getParameters().get('id');
        String soIdParam = ApexPages.currentPage().getParameters().get('salesOrderId');
        if(String.isNotBlank(soIdParam)){
            salesOrderId = (Id)soIdParam;
        }
        
        System.debug('recordId' + recordId);
        System.debug('salesOrderId' + salesOrderId);
        String selectedColumns = ApexPages.currentPage().getParameters().get('columns');
        
        if(String.isNotBlank(selectedColumns)) {
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
        
        if(recordId == null && salesOrderId == null) {
            cartLineItemList = new List<Cart_Line_Item__c>();
            return;
        }
        
        isBankDetailQueried = false;
        List<Bank_Detail__c> bankDetailList = getBankDetails(recordId != null ? recordId : salesOrderId);
        if(bankDetailList != null && !bankDetailList.isEmpty()){
            isBankDetailQueried = true;
            bankDetail = bankDetailList[0];
        }
        
        // Target Sales Order ka Name fetch karein
        Id targetSOId = salesOrderId != null ? salesOrderId : recordId;
        List<Sales_Order__c> soList = [SELECT Id, Name FROM Sales_Order__c WHERE Id = :targetSOId LIMIT 1];
        if(!soList.isEmpty()){
            salesOrderNumber = 'BS/' + System.Label.Current_Financial_Year + '/' + soList[0].Name;
        }
        
        Map<String,String> address = getAddress(recordId != null ? recordId : salesOrderId);
        shippingAddress = address.get('shipping');
        billingAddress = address.get('billing');
        
        // Sirf is specific Sales Order ke line items layein
        cartLineItemList = getCartLineItems(recordId, salesOrderId);
        
        if(cartLineItemList.isEmpty()){
            cartLineItemList = new List<Cart_Line_Item__c>();
            return;
        }
        
        qDate = Date.valueOf(cartLineItemList[0].CreatedDate);
        
        Decimal total = 0;
        Decimal totalGstSum = 0;
        
        // Line-by-line Taxable Value & GST Calculation
        for(Cart_Line_Item__c item : cartLineItemList){
            if(item.Total_Amount__c != null) {
                total += item.Total_Amount__c;
            }
            
            Decimal taxableVal = item.After_Discount__c != null ? item.After_Discount__c : (item.Total_Amount__c != null ? item.Total_Amount__c : 0);
            totalTaxableValue += taxableVal;
            
            if(item.GST__c != null && item.GST__c > 0) {
                totalGstSum += (taxableVal * item.GST__c) / 100;
            }
        }
        
        totalTaxableValue = totalTaxableValue.setScale(2);
        totalGstSum = totalGstSum.setScale(2);
        
        // Billing State check
        String billingState = getBillingState(recordId != null ? recordId : salesOrderId);
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
        
        System.debug('cartLineItemList >> ' + cartLineItemList);
    }
    
    // Billing State check helper method
    private static String getBillingState(Id recId) {
        String stateName = '';
        if(recId == null) return stateName;
        
        String sObjName = recId.getSObjectType().getDescribe().getName();
        Id oppId = recId;
        
        if(sObjName == 'Sales_Order__c') {
            Sales_Order__c so = [SELECT Id, Opportunity__c FROM Sales_Order__c WHERE Id = :recId LIMIT 1];
            oppId = so.Opportunity__c;
        }
        
        if(oppId != null) {
            Opportunity__c opp = [
                SELECT Id, Account_Name__c, Account_Name__r.Billing_State__c, 
                       Contact__r.Billing_State__r.Name, Contact__r.Billing_State__c 
                FROM Opportunity__c 
                WHERE Id = :oppId 
                LIMIT 1
            ];
            
            if(opp.Account_Name__r != null && String.isNotBlank(opp.Account_Name__r.Billing_State__c)) {
                stateName = opp.Account_Name__r.Billing_State__c;
            } else if(opp.Contact__r != null && opp.Contact__r.Billing_State__r != null && String.isNotBlank(opp.Contact__r.Billing_State__r.Name)) {
                stateName = opp.Contact__r.Billing_State__r.Name;
            } else if(opp.Contact__r != null && String.isNotBlank(opp.Contact__r.Billing_State__c)) {
                stateName = opp.Contact__r.Billing_State__c;
            }
        }
        return stateName;
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
        Opportunity__c opp = [SELECT CreatedDate, Contact__r.Email FROM Opportunity__c WHERE Id = :recordId];
        if(opp.Contact__r != null) {
            toEmail = opp.Contact__r.Email;
        }
        
        if(String.isBlank(toEmail)){
            throw new AuraHandledException('No Email Found');
        }
        
        PageReference pdfPage = Page.SalesOrderQuotationPdf;
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
                System.debug('Email failed: ' + results[0].getErrors()[0].getMessage());
                throw new AuraHandledException('Email Not sent successfully');
            }
        }catch(Exception e){
            system.debug('error rrooor  >> '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Boolean hasCartLineItem(Id recordId){
        List<Cart_Line_Item__c> items = getCartLineItems(recordId, null);
        system.debug('items >> '+items.size());
        return items.size() > 0;
    }
    
    // Sales Order ke according line items lane ke liye updated method
    public static List<Cart_Line_Item__c> getCartLineItems(Id recordId, Id salesOrderId){
        Id targetSOId = salesOrderId;
        if(targetSOId == null && recordId != null) {
            if(recordId.getSObjectType().getDescribe().getName() == 'Sales_Order__c') {
                targetSOId = recordId;
            }
        }

        List<Cart_Line_Item__c> cartLineItemList;
        if(targetSOId != null) {
            // Sirf selected/created Sales Order ke Cart Line Items fetch karein
            cartLineItemList = [
                SELECT Id, Name, Opportunity__c, Lead__c, Sales_Order__c,
                       Product__c, Product__r.Name, Product__r.Image_URL__c,
                       Product__r.Grade__c, Product__r.Code__c, Product__r.CAS_Number__c,
                       Product__r.Brand__r.Name, 
                       GST__c, Discount__c, After_Discount__c,
                       Product__r.Pack_Size__c,
                       Quantity__c, Amount__c, Total_Amount__c, CreatedDate, Promise_Date__c, Priority__c
                FROM Cart_Line_Item__c
                WHERE Sales_Order__c = :targetSOId
            ];
        } else if(recordId != null) {
            cartLineItemList = [
                SELECT Id, Name, Opportunity__c, Lead__c, Sales_Order__c,
                       Product__c, Product__r.Name, Product__r.Image_URL__c,
                       Product__r.Grade__c, Product__r.Code__c, Product__r.CAS_Number__c,
                       Product__r.Brand__r.Name, 
                       GST__c, Discount__c, After_Discount__c,
                       Product__r.Pack_Size__c,
                       Quantity__c, Amount__c, Total_Amount__c, CreatedDate, Promise_Date__c, Priority__c
                FROM Cart_Line_Item__c
                WHERE Opportunity__c = :recordId
            ];
        }
        
        system.debug('cartLineItemList >> '+cartLineItemList);
        return cartLineItemList != null ? cartLineItemList : new List<Cart_Line_Item__c>();
    }
    
    public static Map<String,String> getAddress(Id recordId){
        Map<String,String> address = new Map<String,String>();
        if(recordId == null) return address;

        Id oppId = recordId;
        if(recordId.getSObjectType().getDescribe().getName() == 'Sales_Order__c') {
            Sales_Order__c so = [SELECT Id, Opportunity__c FROM Sales_Order__c WHERE Id = :recordId LIMIT 1];
            oppId = so.Opportunity__c;
        }
        
        Opportunity__c opportunity = [SELECT Id,
                                      Bank__c,
                                      Contact__r.Phone, Contact__r.Email, Contact__r.GST_Number__c,
                                      Contact__r.Payment_Terms__c, Contact__r.CreatedBy.Name, Contact__r.PAN__C, Contact__r.Drug_License__c, Contact__r.TAN__C,
                                      Contact__r.Shipping_Address_1__c,
                                      Contact__r.Shipping_Address_2__c,
                                      Contact__r.Shipping_Address_3__c,
                                      Contact__r.Shipping_Country__r.Name,
                                      Contact__r.Shipping_State__r.Name,
                                      Contact__r.Shipping_City__r.Name,
                                      Contact__r.Shipping_Zip_Code__c,
                                      Contact__r.Billing_Address_1__c,
                                      Contact__r.Billing_Address_2__c,
                                      Contact__r.Billing_Address_3__c,
                                      Contact__r.Billing_Country__r.Name,
                                      Contact__r.Billing_State__r.Name,
                                      Contact__r.Billing_City__r.Name,
                                      Contact__r.Billing_Zip_Code__c
                                      FROM Opportunity__c
                                      WHERE Id = :oppId];
        
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
        if(opportunity.Contact__r.Shipping_Country__r != null) shipping.add(opportunity.Contact__r.Shipping_Country__r.Name);
        if(opportunity.Contact__r.Shipping_State__r != null) shipping.add(opportunity.Contact__r.Shipping_State__r.Name);
        if(opportunity.Contact__r.Shipping_City__r != null) shipping.add(opportunity.Contact__r.Shipping_City__r.Name);
        if(opportunity.Contact__r.Shipping_Zip_Code__c != null) shipping.add(opportunity.Contact__r.Shipping_Zip_Code__c);
        address.put('shipping', String.join(shipping, ', '));
        
        List<String> billing = new List<String>();
        if(opportunity.Contact__r.Billing_Address_1__c != null) billing.add(opportunity.Contact__r.Billing_Address_1__c);
        if(opportunity.Contact__r.Billing_Address_2__c != null) billing.add(opportunity.Contact__r.Billing_Address_2__c);
        if(opportunity.Contact__r.Billing_Address_3__c != null) billing.add(opportunity.Contact__r.Billing_Address_3__c);
        if(opportunity.Contact__r.Billing_Country__r != null) billing.add(opportunity.Contact__r.Billing_Country__r.Name);
        if(opportunity.Contact__r.Billing_State__r != null) billing.add(opportunity.Contact__r.Billing_State__r.Name);
        if(opportunity.Contact__r.Billing_City__r != null) billing.add(opportunity.Contact__r.Billing_City__r.Name);
        if(opportunity.Contact__r.Billing_Zip_Code__c != null) billing.add(opportunity.Contact__r.Billing_Zip_Code__c);
        address.put('billing', String.join(billing, ', '));
        
        return address;
    }
    
    public static List<Bank_Detail__c> getBankDetails(Id recordId){
        if(recordId == null) return null;
        Id oppId = recordId;
        if(recordId.getSObjectType().getDescribe().getName() == 'Sales_Order__c') {
            Sales_Order__c so = [SELECT Id, Opportunity__c FROM Sales_Order__c WHERE Id = :recordId LIMIT 1];
            oppId = so.Opportunity__c;
        }

        Id bankId;
        String paymentTerms;
        String dispatchTerms;
        
        paymentTermsAndConditions = new List<String>();
        dispatchTermsAndConditions = new List<String>();
        
        Opportunity__c opp = [Select Id, Payment_Terms_Conditions__c, Dispatch_Terms_Conditions__c, Bank__c from Opportunity__c Where Id = :oppId limit 1];
        bankId = opp.Bank__c;
        if(!String.isBlank(opp.Payment_Terms_Conditions__c)){
            paymentTerms = opp.Payment_Terms_Conditions__c;
        }
        if(!String.isBlank(opp.Dispatch_Terms_Conditions__c)){
            dispatchTerms = opp.Dispatch_Terms_Conditions__c;
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