public class ToDoListCmpController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getTodayToDoListTask(){
        
        Map<String,Object> result = new Map<String,Object>();
        
        List<To_Do_List__c> todolst = [
            SELECT Id, Today_s_Task__c
            FROM To_Do_List__c
            WHERE CreatedDate = TODAY
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        List<String> todayTasklst = new List<String>();
        
        if(!todolst.isEmpty()) {
            
            if(String.isNotBlank(todolst[0].Today_s_Task__c)){
                
                String strtodaytast = todolst[0].Today_s_Task__c;
                
                strtodaytast = strtodaytast.unescapeHtml4();
                
                todayTasklst = splitLines(strtodaytast);
            }
            
            result.put('recordId', todolst[0].Id);
        }
        
        result.put('tasks', todayTasklst);
        
        return result;
    }
    
    
    public static List<String> splitLines(String txt){
        
        List<String> finalList = new List<String>();
        
        if(String.isNotBlank(txt)){
            
            List<String> tempList = txt.split('\n');
            
            for(String s : tempList){
                
                s = s.trim();
                
                if(String.isNotBlank(s)){
                    finalList.add(s);
                }
            }
        }
        
        return finalList;
    }
}