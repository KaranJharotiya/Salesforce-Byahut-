@isTest
public class ToDoListCmpControllerTest {
    
    @testSetup
    public static void dataFactory(){
        To_Do_List__c toDo = new To_Do_List__c(
            Today_s_Task__c = 'Test'
        );
        insert toDo;
    }

    @isTest
    public static void getTodayToDoListTaskTest(){
        ToDoListCmpController.getTodayToDoListTask();
    }
    
    @isTest
    public static void splitLinesTest(){
        ToDoListCmpController.splitLines('test');
    }
}