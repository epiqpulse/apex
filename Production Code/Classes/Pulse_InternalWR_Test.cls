@isTest
public class Pulse_InternalWR_Test {

    private static testMethod void testDefaultTaskCreation() {
        map<Id, string> internalProjectRecordTypes = Pulse_Utils.getSObjectRecordTypeMap('Internal_Project__c');
        map<Id, string> internalWRRecordTypes = Pulse_Utils.getSObjectRecordTypeMap('Internal_Work_Request__c');
        Integer tasksCreated = 0;
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        test.startTest();
            // for each record type of Internal Project create Projects and then create Work Requests whose Record Types 
            // are of the appropriate type
            for(string projectRecordType : internalProjectRecordTypes.values()) {
                system.debug(projectRecordType);
                container.createInternalProjects(1, projectRecordType, true);
                system.debug(container.testInternalProjects);
                for(string wrRecordType : internalWRRecordTypes.values()) {
                    system.debug(wrRecordType);
                    if((projectRecordType.startsWith('CI') && wrRecordType.startsWith('OE'))
                       || (projectRecordType.startsWith('OE') && wrRecordType.startsWith('CI'))) {
                           system.debug('continuing');
                           continue;
                    }
                    container.createInternalWorkRequests(1, wrRecordType, true);
                    system.debug(container.testInternalWorkRequests);
                }  
            }
        test.stopTest();
        list<Internal_WR_Task__c> iwrTasks = [select Internal_Work_Request__c, Internal_Work_Request__r.RecordType.Name, Notes__c, 
                                   	Owners__c, Task_Completed__c, Task_Order__c, Task_Owners__c, Task_Started__c, Task_Type__c
                            		from Internal_WR_Task__c];
        set<string> parentIWRIds = Pulse_Utils.getFieldValueSet(iwrTasks, 'Internal_Work_Request__c');
        system.debug(parentIWRIds);
        for(Internal_Work_Request__c iWorkRequest : [select Id from Internal_Work_Request__c]) {
        	system.debug(iWorkRequest);
            system.assert(parentIWRIds.contains(string.valueOf(iWorkRequest.Id)));    
        }
    }
    
    private static testMethod void testIWRStatusButton() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createInternalProjects(1, 'OE Project', true);
        container.createInternalWorkRequests(1, 'OE - Enhancement Request', true);
        container.testInternalWorkRequests = [select Id, Status__c from Internal_Work_Request__c where Id in : container.testInternalWorkRequests];
        system.assertNotEquals('Submitted', container.testInternalWorkRequests[0].Status__c);
        test.startTest();
        ApexPages.StandardSetController con = new ApexPages.StandardSetController(container.testInternalWorkRequests);
		Pulse_InternalWR_Controller controller = new Pulse_InternalWR_Controller(con);
        test.stopTest();
        // below update should succeed and return 'Success'
        system.assertEquals('Success', Pulse_InternalWR_Controller.updateIWRStatus(string.valueOf(container.testInternalWorkRequests[0].Id), 'Submitted'));
        // below update should fail due to the attempt to set a value not already in the picklist.
        system.assertNotEquals('Success', Pulse_InternalWR_Controller.updateIWRStatus(string.valueOf(container.testInternalWorkRequests[0].Id), 'Subminted'));
    }
     
    // test that Internal Work Requests cannot be set to Cancelled/Complete/Invoiced if there are any tasks
    // that are not Cancelled or Finished
    private static testMethod void testInternalWorkRequestIncompleteTaskValidation() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createInternalProjects(1, 'CI Project', true);
        container.createInternalWorkRequests(1, 'CI Work Request', true);
        container.findInternalWRTasks();
		
        test.startTest();
        try {
            container.testInternalWorkRequests[0].Status__c = 'Cancelled';
            update container.testInternalWorkRequests;
            system.assert(false, 'This update should have failed, since no Tasks have been updated');
        } catch(Exception exc) {
            system.assert(exc.getMessage().contains('unless all of their Internal WR Tasks are either Finished or Cancelled'));
        }
        try {
            container.testInternalWorkRequests[0].Status__c = 'Complete';
            update container.testInternalWorkRequests;
            system.assert(false, 'This update should have failed, since no Tasks have been updated');
        } catch(Exception exc) {
            system.assert(exc.getMessage().contains('unless all of their Internal WR Tasks are either Finished or Cancelled'));
        }
        try {
            container.testInternalWorkRequests[0].Status__c = 'Invoiced';
            update container.testInternalWorkRequests;
            system.assert(false, 'This update should have failed, since no Tasks have been updated');
        } catch(Exception exc) {
            system.assert(exc.getMessage().contains('unless all of their Internal WR Tasks are either Finished or Cancelled'));
        }
        // cancel all of the created Internal WR Tasks so the update can go through.
        Pulse_Utils.setFieldToValue(container.TestInternalWRTasks, 'Status__c', 'Cancelled');
        update container.TestInternalWRTasks;
        try {
            container.testInternalWorkRequests[0].Status__c = 'Cancelled';
            update container.testInternalWorkRequests;
            system.assert(true, 'This update should succeed since all tasks are now cancelled');
        } catch(Exception exc) {
            system.assert(false, 'The update was expected to succeed since the tasks were cancelled beforehand.');
        }
        test.stopTest();   
    }
}