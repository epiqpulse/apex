@isTest
public class Pulse_InternalWRTask_Test {

    // validate that OE Work Requests are defaulted to someone other than the creator
    // when inserted.
    private static testMethod void testDefaultTaskOwnership() {
        list<Internal_WR_Task_Setting__mdt> taskSettings = [select Task_Name__c, Default_Owner_Name__c, Default_Task__c, Owner_Type__c 
                                                              from Internal_WR_Task_Setting__mdt where Default_Owner__c = true];
        set<string> tasksWithDefaultOwners = Pulse_Utils.getFieldValueSet(taskSettings, 'Task_Name__c');
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createInternalProjects(1, 'OE Project', true);
        container.createInternalWorkRequests(1, 'OE - Enhancement Request', true);
        container.findInternalWRTasks();
        system.debug(container.testInternalWRTasks);
        for(Internal_WR_Task__c iwrTask : container.testInternalWRTasks) {
            if(tasksWithDefaultOwners.contains(iwrTask.Task_Type__c)){
                system.assertNotEquals(UserInfo.getUserId(), iwrTask.OwnerId);
            }
            system.debug(iwrTask.Task_Type__c);
            system.debug(iwrTask.OwnerId);
        }
    }

    private static testMethod void testTaskFieldTimeStamps() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createInternalProjects(1, 'OE Project', true);
        container.createInternalWorkRequests(1, 'OE - Enhancement Request', true);
        container.findInternalWRTasks();
   		Pulse_Utils.setFieldToValue(container.testInternalWRTasks, 'Status__c', 'Started');
        update container.testInternalWRTasks;
        container.findInternalWRTasks();
        for(Internal_WR_Task__c iwrTask : container.testInternalWRTasks) {
            system.assert(iwrTask.Task_Started__c != null);
        }
   		Pulse_Utils.setFieldToValue(container.testInternalWRTasks, 'Status__c', 'Finished');
        update container.testInternalWRTasks;
        container.findInternalWRTasks();
        for(Internal_WR_Task__c iwrTask : container.testInternalWRTasks) {
            system.assert(iwrTask.Task_Completed__c != null);
        }
    }
}