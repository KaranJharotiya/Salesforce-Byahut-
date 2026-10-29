public class PoPdfController {
    
    Id recordId{get;set;}
    public Purchase_Order__c po{get;set;}
    public List<Purchase_Order_Line_Item__c> poli{get;set;}
    
    public PoPdfController(ApexPages.StandardController controller){
        
        recordId = controller.getId();
        
        po = [Select Id, Name, Vendor_Master__c, Vendor_Master__r.Name, Vendor_Master__r.Last_Name__c, Vendor_Master__r.Email__c, 
              Vendor_Master__r.Mobile_No__c, Vendor_Master__r.Address__c, Vendor_Master__r.GST__c,Total_GST_Amount__c,Grand_Total_Without_GST__c,
              Delivery_Timeline__c,Payment_Terms__c,CreatedBy.Name,
              Total_Amount__c, CreatedDate From Purchase_Order__c Where Id = :recordId];
        poli = [Select Id, Name, Product__c, Product__r.Name, Product__r.Code__c, Product__r.Pack_Size__c,
                Unit_Price__c, Quantity__c, GST__c,GST_Amount__c,
                Discount__c, Amount__c
                From Purchase_Order_Line_Item__c Where Purchase_Order__c = :po.Id];
    }
}