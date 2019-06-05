@isTest
private class Pulse_WRTaskTrigger_Test {

    // test that when a Del - Final Management QC task is set to Finished
    // status a new Internal Task record is created associated to the Project
    // and verify that the desired information is populated on the new record.
    static testMethod void GeneratedInternalTaskTest(){
        createEMSTaskSettings();
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createProjectsWithRecordType(1, 'Data Center Project', false);
        container.discoPros[0].Primary_PM__c = system.UserInfo.getUserId();
        insert container.discoPros;
        container.createWorkRequestWithRecordType(1, 'EMS Third Party Data Load', false);
        container.testWorkRequests[0].Requested_Time__c = DateTime.now().addDays(-2);
        insert container.testWorkRequests;
        container.findWorkRequestTasks();
        for(EDiscovery_WR_Task__c each : container.testWorkRequestTasks){
            each.Status__c = 'Started';
        }
        update container.testWorkRequestTasks;
        test.startTest();
        for(EDiscovery_WR_Task__c each : container.testWorkRequestTasks){
            each.Status__c = 'Finished';
        }
        update container.testWorkRequestTasks;
        test.stopTest();
        EDiscovery_WR_Task__c wrTask = [select Id, Date_Finished__c, Work_Request__r.Name, Work_Request__r.Project__c, 
                                        Work_Request__r.Project__r.Primary_PM__c, Work_Request__r.Requested_Time__c
                                       	from EDiscovery_WR_Task__c where Task_Type__c = 'Del - Final Management QC'
                                       	limit 1];
        system.assertNotEquals(null, wrTask);
        EDiscovery_Internal_Task__c internalTask = [select Id, IT_Pulse_Project__c, OwnerId, Requested_Time__c,
                                                   IT_Headline__c, IT_Status__c, Task_Type__c, Instructions__c
                                                   from EDiscovery_Internal_Task__c limit 1];
        // validate below that all fields were populated appropriately on the new record.
        system.assertNotEquals(null, internalTask);
        system.assertEquals(wrTask.Work_Request__r.Project__c, internalTask.IT_Pulse_Project__c);
        system.assertEquals(wrTask.Work_Request__r.Project__r.Primary_PM__c, internalTask.OwnerId);
        system.assertEquals(wrTask.Work_Request__r.Requested_Time__c, internalTask.Requested_Time__c);
        system.assertEquals('Deliverable QC of ' + wrTask.Work_Request__r.Name, internalTask.IT_Headline__c);
        system.assertEquals('Submitted', internalTask.IT_Status__c);
        system.assertEquals('Deliverable QC', internalTask.Task_Type__c);
        system.assertEquals('Deliverable QC of \n' + wrTask.Work_Request__r.Name + ' \nCompleted on \n ' + wrTask.Date_Finished__c, internalTask.Instructions__c);
    }
    
    // test that the ILM Project Closeout tasks send the right number of emails when their status is 
    // set to Sent to ServiceNow
    // Assert that emails were sent using changes to the result of Limits.getEmailInvocations()
    static testMethod void ILMTaskNotificationTest(){
        // list of ILM record type WR Tasks where department is Global Support Services
        list<EDiscovery_WR_Task__c> ilmGSSTasks = new list<EDiscovery_WR_Task__c>();
        // list of ILM record type WR Tasks where department is not Global Support Services
        list<EDiscovery_WR_Task__c> ilmnonGSSTasks = new list<EDiscovery_WR_Task__c>();
        createILMCloseoutTaskSettings();
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        container.createWorkRequestWithRecordType(1, 'ILM - Project Closeout', false);
        container.testWorkRequests[0].Requested_Time__c = system.now();
        insert container.testWorkRequests;
        container.findWorkRequestTasks();
        map<Id, string> wrTaskRecordTypeMap = Pulse_Utils.getSObjectRecordTypeMap('EDiscovery_WR_Task__c');
        container.createApplicationDatabases(true);        
        container.createApplicationDatabaseAssignments(true);
        // populate the two lists initialized above. the GSS tasks will only generate
        // a single email when updated together to Sent to ServiceNow. the other list 
        // will generate an email per task updated to Sent to ServiceNow.
        for(EDiscovery_WR_Task__c each : container.testWorkRequestTasks){
            system.debug(each);
            if(wrTaskRecordTypeMap.get(each.RecordTypeId) == 'ILM'){
                if(each.Department__c == 'Pulse_ILM_Team'){
                    ilmnonGSSTasks.add(each);
                } else {
                    ilmGSSTasks.add(each);
                }
            }
        }
        // two of the tasks are GSS Department and ILM record type
        system.assertEquals(2, ilmGSSTasks.size());
        // three of the tasks are ILM Team Department and ILM record type
        // only two of them are set to send emails out.
        system.assertEquals(3, ilmnonGSSTasks.size());
        test.startTest();
        integer emailsSent;
        integer emailExpected;
        for(EDiscovery_WR_Task__c eachWRTask : ilmGSSTasks){
            eachWRTask.Status__c = 'Sent to ServiceNow';
        }
        update ilmGSSTasks;
        emailExpected = 1; // all the data for the two tasks are grouped into a single email message.
        emailsSent = Limits.getEmailInvocations();
        system.assertEquals(emailExpected, emailsSent);
        for(EDiscovery_WR_Task__c eachWRTask : ilmnonGSSTasks){
            eachWRTask.Status__c = 'Sent to ServiceNow';
        }
        update ilmnonGSSTasks;
        emailExpected = 2;// We send two additional emails here, but they are sent with a single call so the limit only increases by 1
        emailsSent = Limits.getEmailInvocations();
        system.assertEquals(emailExpected, emailsSent);
        test.stopTest();
    }
    
    public static void createEMSTaskSettings(){
        list<WR_Task_Settings__c> allTaskSettings = new list<WR_Task_Settings__c>{
            	new WR_Task_Settings__c(Name = 'T-0001', Record_Type__c = 'EMS Third Party Data Load', Status__c = 'Not Started', Task_Order__c = 10, 
                                    Task_Type__c = 'Rel Third Party Load - Load and Self QC', 
                                    Priority__c = 'Standard', Task_Record_Type__c = 'Standard'),
            	new WR_Task_Settings__c(Name = 'T-0002', Record_Type__c = 'EMS Third Party Data Load', Status__c = 'Not Started', Task_Order__c = 20, 
                                    Task_Type__c = 'Del - Final Management QC', 
                                    Priority__c = 'Standard', Task_Record_Type__c = 'Standard')
            };
        insert allTaskSettings;
    }
    
    public static void createILMCloseoutTaskSettings(){
        list<WR_Task_Settings__c> allTaskSettings = new list<WR_Task_Settings__c>{
            	new WR_Task_Settings__c(Name = 'T-0001', Department__c = 'ILM', Record_Type__c = 'ILM - Project Closeout', Status__c = 'Not Started', Task_Order__c = 10, 
                                    Task_Type__c = '1.00 – Initiation | Confirm requirements and identify data sources', 
                                    Priority__c = 'Standard', Task_Record_Type__c = 'Standard'),
            	new WR_Task_Settings__c(Name = 'T-0002', Department__c = 'Global Support Services', Record_Type__c = 'ILM - Project Closeout', Status__c = 'Not Started', Task_Order__c = 20, 
                                    Task_Type__c = '1.01 - Initiation | Remove External Users (Hosting: Relativity and DMX)', 
                                    Priority__c = 'Standard', Task_Record_Type__c = 'ILM'),
            	new WR_Task_Settings__c(Name = 'T-0003', Department__c = 'Global Support Services', Record_Type__c = 'ILM - Project Closeout', Status__c = 'Not Started', Task_Order__c = 30, 
                                    Task_Type__c = '1.02 – Initiation | Update Billing Page (Assign to LSG if Rel C). Update Pulse Project Status and Pulse Application Database Status', 
                                    Priority__c = 'Standard', Task_Record_Type__c = 'ILM'),
            	new WR_Task_Settings__c(Name = 'T-0004', Department__c = 'ILM', Record_Type__c = 'ILM - Project Closeout', Status__c = 'Not Started', Task_Order__c = 10, 
                                    Task_Type__c = '1.03 - Initiation | Check Crosslinks', 
                                    Priority__c = 'Standard', Task_Record_Type__c = 'Standard'),
            	new WR_Task_Settings__c(Name = 'T-0005', Department__c = 'ILM', Record_Type__c = 'ILM - Project Closeout', Status__c = 'Not Started', Task_Order__c = 170, 
                                    Task_Type__c = '3.00 DMX Archive | Submit Processing and/or Hosting archive request to IT	', 
                                    Priority__c = 'Standard', Task_Record_Type__c = 'ILM'),
            	new WR_Task_Settings__c(Name = 'T-0006', Department__c = 'ILM', Record_Type__c = 'ILM - Project Closeout', Status__c = 'Not Started', Task_Order__c = 240, 
                                    Task_Type__c = '4.06 Deletion-Processing / Hosting | DMX: Submit a ServiceNow ticket to IT to delete if needed', 
                                    Priority__c = 'Standard', Task_Record_Type__c = 'ILM'),
            	new WR_Task_Settings__c(Name = 'T-0007', Department__c = 'ILM', Record_Type__c = 'ILM - Project Closeout', Status__c = 'Not Started', Task_Order__c = 280, 
                                    Task_Type__c = '4.10 Deletion-Processing / Hosting | Equivio databases: Submit a ServiceNow ticket to IT to delete if needed', 
                                    Priority__c = 'Standard', Task_Record_Type__c = 'ILM'),
            	new WR_Task_Settings__c(Name = 'T-0008', Department__c = 'ILM', Record_Type__c = 'ILM - Project Closeout', Status__c = 'Not Started', Task_Order__c = 320, 
                                    Task_Type__c = '5.00 Deletion-Network Share | Submit paths to IT for deletion	', 
                                    Priority__c = 'Standard', Task_Record_Type__c = 'Standard')
            };
        insert allTaskSettings;
    }
    
}