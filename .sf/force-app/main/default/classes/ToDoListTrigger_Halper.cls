public class ToDoListTrigger_Halper {
    
    public static void checkRecordAllreadyCreatedOrNot(List<To_Do_List__c> n){
        
        
        
        
        Date todayDate = Date.today();
        
        List<To_Do_List__c> existingRecordLst = [
            SELECT Id
            FROM To_Do_List__c
            WHERE CreatedDate = TODAY
            LIMIT 1
        ];
        
        if(!existingRecordLst.isEmpty()){
            
            for(To_Do_List__c obj : n){
                obj.addError('Today\'s To-Do List record already exists. Only one record can be created per day.');
            }
            
        }
    }
    
    
    public static void updateToDoRecord(List<To_Do_List__c> n){
        for(To_Do_List__c obj : n){
            
            if(obj.User__c != null){
                
                obj.OwnerId = obj.User__c;
            }  
            
        }
    }
    
}