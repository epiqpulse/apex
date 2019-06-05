@isTest
private class Pulse_WR_Workflow_Controller_Test 
{
    private static testMethod void testSubmitWR()
    {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        list<RecordType> RecordTypes = Pulse_Test_Helpers.CreateRecordTypeList();
        list<EDiscovery_WorkRequest__c> WorkRequests = new list<EDiscovery_WorkRequest__c>();
      
        // Insert WR Task Settings
        list<WR_Task_Settings__c> WRtaskSettings;
        WRtaskSettings = new list<WR_Task_Settings__c>();
        WR_Task_Settings__c ts1 = new WR_Task_Settings__c();
        ts1.Name = 'T-0001';
        ts1.Task_Type__c = 'Test';
        ts1.Task_Order__c = 1;
        ts1.Status__c = 'Not Started';
        ts1.Record_Type__c = 'ESI - General';
        ts1.Department__c = '';
      
        WRtaskSettings.add(ts1);
        insert WRtaskSettings;
          
        list<Id> wrIds = new list<Id>();
        EDiscovery_WorkRequest__c wr = new EDiscovery_WorkRequest__c();
        wr.OwnerID = userInfo.getUserId();
        wr.Project__c = container.discoPros[0].Id;
        wr.RecordTypeId = RecordTypes[0].Id;  
        wr.Name__c = 'ControllerTest';
        wr.Work_Request_Status__c = 'Pre-Submission';
        WorkRequests.add(wr);
      
        EDiscovery_WorkRequest__c wr2 = new EDiscovery_WorkRequest__c();
        wr2.OwnerID = userInfo.getUserId();
        wr2.Project__c = container.discoPros[0].Id;
        wr2.RecordTypeId = RecordTypes[0].Id;  
        wr2.Name__c = 'ControllerTest';
        wr2.Work_Request_Status__c = 'Complete';
        WorkRequests.add(wr2);
          
        EDiscovery_WorkRequest__c wr3 = new EDiscovery_WorkRequest__c();
        wr3.OwnerID = userInfo.getUserId();
        wr3.Project__c = container.discoPros[0].Id;
        wr3.RecordTypeId = RecordTypes[0].Id;  
        wr3.Name__c = 'ControllerTest';
        wr3.Work_Request_Status__c = 'Pre-Submission';
        WorkRequests.add(wr3);
      
        insert WorkRequests;
        Quality_Control_Entry__c qce1 = new Quality_Control_Entry__c();
        qce1.Work_Request__c = wr.Id;
        qce1.Pass_or_Fail__c = 'Pass';
        insert qce1;
        Quality_Control_Entry__c qce2 = new Quality_Control_Entry__c();
        qce2.Work_Request__c = wr3.Id;
        qce2.Pass_or_Fail__c = 'Pass';
        insert qce2;
        
        for(EDiscovery_WorkRequest__c wrs : WorkRequests) {
            wrIds.add(wrs.Id);
        }
        // Insert WR Tasks
        list<EDiscovery_WR_Task__c> WRtasks = new list<EDiscovery_WR_Task__c>();
        WRTasks = [select Id, Task_Type__c, Work_Request__c, Status__c from EDiscovery_WR_Task__c where Work_Request__c in :wrIds];
        //system.debug('*!*!*! WRTasks: ' + WRTasks);
        
        EDiscovery_WR_Task__c task = new EDiscovery_WR_Task__c();
        task.OwnerID = userInfo.getUserId();
        task.Due_Date__c = System.today().addDays(2);
        task.Task_Type__c = 'TestType';
        task.Work_Request__c = wr.id;
        task.Status__c = 'Not Started';
        WRtasks.add(task);
          
        EDiscovery_WR_Task__c task2 = new EDiscovery_WR_Task__c();
        task2.OwnerID = userInfo.getUserId();
        task2.Due_Date__c = System.today().addDays(2);
        task2.Task_Type__c = 'TestType2';
        task2.Work_Request__c = wr2.id;
        task2.Status__c = 'Finished';
        WRtasks.add(task2);          
        
        EDiscovery_WR_Task__c task3 = new EDiscovery_WR_Task__c();
        task3.OwnerID = userInfo.getUserId();
        task3.Due_Date__c = System.today().addDays(2);
        task3.Task_Type__c = 'TestType3';
        task3.Work_Request__c = wr3.id;
        task3.Status__c = 'Cancelled';
        WRtasks.add(task3);
        
        insert WRtasks;
        
        test.startTest();
//        Pulse_WR_Workflow_Controller.SubmitWR( wr.Id );        
        
//        Pulse_WR_Workflow_Controller.MarkWR_RFI( wr2.Id );
        
        Pulse_WR_Workflow_Controller.CancelWR( wr3.Id );
        
        PageReference pageRef = Page.Take_Selected_WR_Tasks;
        pageRef.getParameters().put('id',task.id);
        Test.setCurrentPage(pageRef);
        
        ApexPages.StandardSetController con = new ApexPages.StandardSetController(WRTasks);
        con.setSelected(WRTasks);
        Pulse_WR_Workflow_Controller mycon = new Pulse_WR_Workflow_Controller(con);
        mycon.OwnSelectedTasks();
        mycon.StartSelectedTasks();
        mycon.FinishSelectedTasks();
        mycon.UpdateTasks();
        
        test.stopTest();
    }

    // test updating a Work request through the generic button code.    
    private static testMethod void testGenericStatusButton(){
        string wrRecordType = 'Field Office Work Request';
        string newStatus = 'Submitted';
        string msg = 'WRequest workflow controller making fail: []';
        string tag = 'WRequest workflow controller '; 
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
            Pulse_WR_Workflow_Controller.updateWRStatus(string.valueOf(container.testWorkRequests[0].Id), newStatus);
            EDiscovery_WorkRequest__c updatedWR = [select Id, Work_Request_Status__c from EDiscovery_WorkRequest__c where Id in : container.testWorkRequests limit 1];
            system.assertEquals(newStatus, updatedWR.Work_Request_Status__c);
            Pulse_WR_Workflow_Controller.updateWRStatus(string.valueOf(container.testworkRequests[0].Id), 'Submitted');
            updatedWR = [select Id, Work_Request_Status__c from EDiscovery_WorkRequest__c where Id in : container.testWorkRequests limit 1];
            system.assertEquals(newStatus, updatedWR.Work_Request_Status__c);
            Pulse_Utils.trimErrorMessage(msg, tag);
        test.stopTest(); 
    }
    
        // test updating WR Owner.    
    private static testMethod void testOwnerUpdateButton(){
        string wrRecordType = 'Field Office Work Request';
        string newStatus = 'Submitted';
        string newOwner = '00G0Z000004yRgHUAU';
        string newOwner2 = '00G0Z000004yRgHUAU';
        string msg = 'WRequest workflow controller making fail: []';
        string tag = 'WRequest workflow controller '; 
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
            Pulse_WR_Workflow_Controller.updateWROwner(string.valueOf(container.testWorkRequests[0].Id), '00G0Z000004yRgHUAU');
            EDiscovery_WorkRequest__c updatedWR = [select Id, OwnerID, Work_Request_Status__c from EDiscovery_WorkRequest__c where Id in : container.testWorkRequests limit 1];
            system.assertEquals(newOwner, updatedWR.OwnerID);
            Pulse_WR_Workflow_Controller.updateWROwner(string.valueOf(container.testworkRequests[0].Id), '00G0Z000004yRg');
            updatedWR = [select Id, OwnerID, Work_Request_Status__c from EDiscovery_WorkRequest__c where Id in : container.testWorkRequests limit 1];
            system.assertEquals(newOwner2, updatedWR.OwnerID);
            Pulse_Utils.trimErrorMessage(msg, tag);
        test.stopTest(); 
    }
    
    private static testMethod void testTransferToOeButton(){
        string wrRecordType = 'ESI - Custom Reporting';
        string newStatus = 'Cancelled';
        string newOwner = '00G31000004WARd';
        string newOwner2 = '00G31000004WARd';
        string msg = 'WRequest workflow controller making fail: []';
        string tag = 'WRequest workflow controller '; 
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
        container.createProjectsWithRecordType(1, 'Data Center Project', true);
        container.createWorkRequestWithRecordType(1, 'ESI - Reporting', true);
        container.findWorkRequestTasks();
        
        test.startTest();
            Pulse_WR_Workflow_Controller.TransferToOE(string.valueOf(container.testWorkRequests[0].Id), '00G31000004WARd');
            EDiscovery_WorkRequest__c TransferToOEWR = [select Id, OwnerID, Work_Request_Status__c from EDiscovery_WorkRequest__c where Id in : container.testWorkRequests limit 1];
            system.assertEquals(newOwner, TransferToOeWR.OwnerID);
            Pulse_WR_Workflow_Controller.TransferToOE(string.valueOf(container.testworkRequests[0].Id), '00G31000004WARd');
            TransferToOEWR = [select Id, OwnerID, Work_Request_Status__c from EDiscovery_WorkRequest__c where Id in : container.testWorkRequests limit 1];
            system.assertEquals(newOwner2, TransferToOEWR.OwnerID);
            Pulse_Utils.trimErrorMessage(msg, tag);
        test.stopTest(); 
    }
}