@isTest
private class Pulse_WRTASK_Workflow_Controller_Test 
{
    
    // test updating a Work request through the generic button code.    
    private static testMethod void testGenericStatusButton(){
        string wrRecordType = 'Field Office Work Request';
        string newStatus = 'Cancelled';
        string msg = 'WRTASK workflow controller making fail: []';
        string tag = 'WRTASK workflow controller '; 
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
         list<WR_Task_Settings__c> wrTaskSettings = new list<WR_Task_Settings__c>();
        integer noOfSettings = 2;
        for(integer x = 1; x <= noOfSettings; x++){
            wrTaskSettings.add(new WR_Task_Settings__c(
                        Name = 'T-000' + string.valueOf(x),
                          Task_Type__c = 'Test Task ' + string.valueOf(x),
                          Task_Order__c = x * 10,
                          Status__c = 'Not Started',
                          Record_Type__c = wrRecordType,
                          Department__c = 'Test Department'
                      ));
        }
        insert wrTaskSettings;
        container.createProjectsWithRecordType(1, 'Field Office Project', true);
        container.createWorkRequestWithRecordType(1, 'Field Office Work Request', true);
        container.findWorkRequestTasks();
        
        test.startTest();
            Pulse_WRTASK_Workflow_Controller.updateWRTStatus(string.valueOf(container.testworkRequestTasks[0].Id), newStatus);
            EDiscovery_WR_Task__c updatedWRT = [select Id, Status__c from EDiscovery_WR_Task__c where Id in : container.testWorkRequestTasks limit 1];
            system.assertEquals(newStatus, updatedWRT.Status__c);
            Pulse_WRTASK_Workflow_Controller.updateWRTStatus(string.valueOf(container.testworkRequestTasks[0].Id), 'testing');
            updatedWRT = [select Id, Status__c from EDiscovery_WR_Task__c where Id in : container.testWorkRequestTasks limit 1];
            system.assertEquals(newStatus, updatedWRT.Status__c);
            Pulse_WRTASK_Workflow_Controller.trimErrorMessage(msg, tag);
        test.stopTest();
    }
}