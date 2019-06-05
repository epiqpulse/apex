@isTest
private class Pulse_WRTaskController_Test {

    private static testMethod void testButtons() {
        
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        list<RecordType> RecordTypes = Pulse_Test_Helpers.CreateRecordTypeList();
        list<EDiscovery_WorkRequest__c> WorkRequests = new list<EDiscovery_WorkRequest__c>();
    
        list<Id> wrIds = new list<Id>();
        EDiscovery_WorkRequest__c wr = new EDiscovery_WorkRequest__c();
        wr.OwnerID = userInfo.getUserId();
        wr.Project__c = container.discoPros[0].Id;
        wr.RecordTypeId = RecordTypes[0].Id;  
        wr.Name__c = 'ControllerTest';
        wr.Work_Request_Status__c = 'Pre-Submission';
        WorkRequests.add(wr);
        
        insert WorkRequests;
        
   
        list<EDiscovery_WR_Task__c> WRTasks = new list<EDiscovery_WR_Task__c>();
        EDiscovery_WR_Task__c WRT = new EDiscovery_WR_Task__c();
        WRT.Work_Request__c = wr.Id;
        WRT.Task_Order__c = 10;
        WRT.Task_Type__c = 'Task1';
        WRTasks.add(WRT);
        
        EDiscovery_WR_Task__c WRT2 = new EDiscovery_WR_Task__c();
        WRT2.Work_Request__c = wr.Id;
        WRT2.Task_Order__c = 20;
        WRT2.Task_Type__c = 'Task2';
        WRTasks.add(WRT2);
        
        EDiscovery_WR_Task__c WRT3 = new EDiscovery_WR_Task__c();
        WRT3.Work_Request__c = wr.Id;
        WRT3.Task_Order__c = 30;
        WRT3.Task_Type__c = 'Task3';
        WRTasks.add(WRT3);
            
        insert WRTasks;
        
        test.startTest();
   
        PageReference pageRef = Page.Pulse_WRTaskview;
        pageRef.getParameters().put('id',WRT2.id);
        Test.setCurrentPage(pageRef);
        
        ApexPages.StandardController con = new ApexPages.StandardController(WRT2);
        Pulse_WRTaskController mycon = new Pulse_WRTaskController(con);

        mycon.getCheckNext();
        mycon.getCheckPrevious();
        mycon.getCheckLast();
        
        mycon.doNext();
        mycon.doPrevious();
        mycon.doFirst();
        
        test.stopTest();
    }
    

    
    private static testMethod void testNew() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        CreateEMSTaskSettings('EMS Special / Non-Standard', 2);
        container.createWorkRequestWithRecordType(1, 'EMS Special / Non-Standard', false);

        container.testWorkRequests[0].OwnerID = userInfo.getUserId();
        container.testWorkRequests[0].Requested_Time__c = system.now();
        container.testWorkRequests[0].Name__c = 'EMSControllerTest';
        container.testWorkRequests[0].Work_Request_Status__c = 'Pre-Submission';
        
        insert container.testWorkRequests;
        
        test.startTest();
        
        PageReference pageRef = Page.Pulse_New_EMS_WRTask;
        pageRef.getParameters().put('Id', container.testWorkRequests[0].Id);
        pageRef.getParameters().put('RetURL', '/home/home.jsp');
        pageRef.getParameters().put('CF00N0Z00000H3Adq_lkid', container.testWorkRequests[0].Id);
        Test.setCurrentPage(pageRef);
        
        ApexPages.StandardController con = new ApexPages.StandardController(container.testWorkRequests[0]);
        Pulse_WRTaskController mycon = new Pulse_WRTaskController(con);
        
        PageReference pr = mycon.redirect();
        
        test.stopTest();
        
    }
        
     private static void CreateEMSTaskSettings(string recordType, integer numSettings) {
     // will create the same number of settings for record type ESI - General and DMX - Processing 
        list<WR_Task_Settings__c> WRtaskSettings = new list<WR_Task_Settings__c>();
        
        for(integer i = 0; i < numSettings; i++) {
            WRtaskSettings.add(new WR_Task_Settings__c(
                                Name = 'T-' + string.valueOf(i + 1),
                                Task_Type__c = 'Test ' + string.valueOf(i + 1),
                                Task_Order__c = (i + 1) * 10,
                                Status__c = 'Not Started',
                                Record_Type__c = 'EMS Special / Non-Standard',
                                Department__c = 'Hosting'));
        }
        insert WRtaskSettings;
     }
    
}