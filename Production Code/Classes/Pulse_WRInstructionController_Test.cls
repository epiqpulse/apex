@isTest
private class Pulse_WRInstructionController_Test {

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
        
        list<Work_Request_Instruction__c> WRInstructions = new list<Work_Request_Instruction__c>();
        Work_Request_Instruction__c WRI = new Work_Request_Instruction__c();
        WRI.Work_Request__c = wr.Id;
        WRI.Instruction_Order__c = 10;
        WRInstructions.add(WRI);
        
        Work_Request_Instruction__c WRI2 = new Work_Request_Instruction__c();
        WRI2.Work_Request__c = wr.Id;
        WRI2.Instruction_Order__c = 20;
        WRInstructions.add(WRI2);
        
        Work_Request_Instruction__c WRI3 = new Work_Request_Instruction__c();
        WRI3.Work_Request__c = wr.Id;
        WRI3.Instruction_Order__c = 30;
        WRInstructions.add(WRI3);
            
        insert WRInstructions;
        
        test.startTest();
   
        PageReference pageRef = Page.Pulse_WRInstructionView;
        pageRef.getParameters().put('id',WRI2.id);
        Test.setCurrentPage(pageRef);
        
        ApexPages.StandardController con = new ApexPages.StandardController(WRI);
        Pulse_WRInstructionController mycon = new Pulse_WRInstructionController(con);

        mycon.getCheckNext();
        mycon.getCheckPrevious();
        mycon.getCheckLast();
        
        mycon.doNext();
        mycon.doPrevious();
        mycon.doFirst();
        
        test.stopTest();
        
        //System.assert(WRI.id,pageRef.);
    }
    
}