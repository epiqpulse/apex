@isTest
//Test Class to cover the Pulse_WorkRequestTrigger which is handled in the Pulse_WR_TriggerHandler

public class Pulse_WorkRequestTrigger_Test {
    
    //Method that makes a work request and makes sure the WR Tasks are created
    static testMethod void WRTaskUpdatesTestOne() {

        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        list<WR_Task_Settings__c> WRTaskSettings = Pulse_Test_Helpers.CreateTaskSettings(5);
        container.createWorkRequests(true);
        container.findWorkRequestTasks();
        test.startTest();

        EDiscovery_WR_Task__c task = container.testWorkRequestTasks[0];
        task.Department__c = 'Test dept';
        task.Status__c = 'Started';
        update task;
        task.OwnerId = userInfo.getUserId();
        update task;
        task.Status__c = 'Finished';
        update task;
        test.stopTest();
    }
    
    //Method that makes a work request and makes sure the WR Tasks are created
    static testMethod void WRTaskUpdatesTestTwo() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        list<WR_Task_Settings__c> WRTaskSettings = Pulse_Test_Helpers.CreateTaskSettings(5);
        container.createWorkRequests(true);
        container.findWorkRequestTasks();
        test.startTest();
        EDiscovery_WR_Task__c task = container.testWorkRequestTasks[0];
        task.Department__c = 'Test dept';
        task.Status__c = 'Started';
        update task;
        task.Status__c = 'Not Started';
        update task;
        test.stopTest();
    }
    
    // test that the Work request trigger appropriately sets the Headline field based on the 
    // value of either ITAR_Project__c or HIPAA_Project__c on the parent Project.
    static testMethod void testWorkRequestHeadline() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(3, false);
        container.discoPros[0].ITAR_Project__c = 'Yes';
        container.discoPros[1].HIPAA_Project__c = 'Yes';
        container.discoPros[2].Country_Restriction__c = 'Germany';
        insert container.discoPros;
        test.startTest();
        container.createWorkRequests(false);
        for(EDiscovery_WorkRequest__c each : container.testWorkRequests) each.Headline__c = '_testHeadline_';
        insert container.testWorkRequests;
        test.stopTest();
        // add counts and assert that half of the Work Requests have each Headline to assert each are present
        integer countHIPAA = 0;
        integer countITAR = 0;
        integer countRestricted = 0;
        // query for the inserted Work Requests and assert that the Headline__c field for each was populated appropriately
        // also increment each count when hit to assert later for positive values.
        for(EDiscovery_WorkRequest__c each : [select Id, Project__r.ITAR_Project__c, Project__r.HIPAA_Project__c, Headline__c, Project__r.Country_Restriction__c
                                              from EDiscovery_WorkRequest__c where Id in : container.testWorkRequests]){
            if(each.Project__r.ITAR_Project__c == 'Yes'){
                countITAR++;
                system.assert(each.Headline__c.startsWithIgnoreCase('*** ITAR ***'));
            } else if(each.Project__r.HIPAA_Project__c == 'Yes'){
                countHIPAA++;
                system.assert(each.Headline__c.startsWithIgnoreCase('*** HIPAA ***'));
            } else if(each.Project__r.Country_Restriction__c == 'Germany'){
                countRestricted++;
                system.assert(each.Headline__c.startsWithIgnoreCase('*** Germany Restricted ***'));
            } else {
                // each of the Projects found in the test should meet one of the two above criteria
                system.assert(false);
            }
        }
        system.assertEquals(countHIPAA, countITAR);
        system.assertEquals(countHIPAA, countRestricted);
        system.assertEquals(container.testWorkRequests.size()/3, countHIPAA);
        system.assertEquals(container.testWorkRequests.size()/3, countITAR);
        system.assertEquals(container.testWorkRequests.size()/3, countRestricted);

    }
    
    //test method to send WR Notifications
    private static testMethod void testSubmitWR()
    {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        list<RecordType> RecordTypes = Pulse_Test_Helpers.CreateGeneralRecordType();
        list<EDiscovery_WorkRequest__c> WorkRequests = new list<EDiscovery_WorkRequest__c>();
        
        container.discoPros[0].Project_Email_Distribution_List_Name__c = 'testNotify@epiqglobal.com';
        container.discoPros[0].Primary_PM_email_address__c = 'testNotify@epiqglobal.com';
        container.discoPros[0].Secondary_PM_email_address__c = 'testNotify@epiqglobal.com';
        container.discoPros[0].Alternate_PM_email_address__c = 'testNotify@epiqglobal.com';
        container.discoPros[0].Primary_LSS_email_address__c = 'testNotify@epiqglobal.com';
        update container.discoPros[0];
        
         // Insert WR Task Settings
        list<WR_Task_Settings__c> WRtaskSettings;
        WRtaskSettings = new list<WR_Task_Settings__c>();
        WR_Task_Settings__c ts1 = new WR_Task_Settings__c();
        ts1.Name = 'T-0001';
        ts1.Task_Type__c = 'TestType1';
        ts1.Task_Order__c = 10;
        ts1.Status__c = 'Not Started';
        ts1.Record_Type__c = 'DMX - Prefiltering';
        ts1.Department__c = 'Processing';
        ts1.Task_Record_Type__c = 'Standard';
        WRtaskSettings.add(ts1);
        
        WR_Task_Settings__c ts2 = new WR_Task_Settings__c();
        ts2.Name = 'T-0002';
        ts2.Task_Type__c = 'TestType2';
        ts2.Task_Order__c = 10;
        ts2.Status__c = 'Not Started';
        ts2.Record_Type__c = 'DMX - Processing';
        ts2.Department__c = 'Processing';
        ts2.Task_Record_Type__c = 'Standard';
        WRtaskSettings.add(ts2);
        
        WR_Task_Settings__c ts3 = new WR_Task_Settings__c();
        ts3.Name = 'T-0003';
        ts3.Task_Type__c = 'TestType3';
        ts3.Task_Order__c = 10;
        ts3.Status__c = 'Not Started';
        ts3.Record_Type__c = 'ESI - General';
        ts3.Department__c = 'Processing';
        ts3.Task_Record_Type__c = 'Standard';
        WRtaskSettings.add(ts3);
        
        WR_Task_Settings__c ts4 = new WR_Task_Settings__c();
        ts4.Name = 'T-0004';
        ts4.Task_Type__c = 'TestType';
        ts4.Task_Order__c = 10;
        ts4.Status__c = 'Not Started';
        ts4.Record_Type__c = 'EMS Relativity Processing';
        ts4.Department__c = 'Processing';
        ts4.Task_Record_Type__c = 'Rel Processing - Intake Setup';
        WRtaskSettings.add(ts4);
      
        insert WRtaskSettings;
        
        
        EDiscovery_WorkRequest__c wr2 = new EDiscovery_WorkRequest__c();
        wr2.OwnerID = userInfo.getUserId();
        wr2.Project__c = container.discoPros[0].Id;
        wr2.RecordTypeId = RecordTypes[0].Id;  
        wr2.Name__c = 'ControllerTest';
        wr2.Sub_Department__c = 'Processing';
        wr2.Work_Request_Status__c = 'Pre-Submission';
        wr2.ESI_Available__c = 'Yes';
        insert wr2;
        
        TriggerHandler.isFirstTime = true;
        
        EDiscovery_WR_Task__c task2 = new EDiscovery_WR_Task__c();
        task2.OwnerID = userInfo.getUserId();
        task2.Due_Date__c = System.today().addDays(2);
        task2.Task_Type__c = 'TestType2';
        task2.Work_Request__c = wr2.id;
        task2.Status__c = 'Not Started';
        //task2.RecordTypeId = 
        
        insert task2;

        Quality_Control_Entry__c qce2 = new Quality_Control_Entry__c();
        qce2.Work_Request__c = wr2.Id;
        qce2.pass_or_fail__c = 'Pass';
        //qce2.Wr_Task__c = task2.id;
        insert qce2;
        
       
        test.startTest();
        wr2 = [SELECT id, Work_Request_Status__c FROM EDiscovery_WorkRequest__c WHERE id = :wr2.id];
        //Pulse_WR_Workflow_Controller.SubmitWR( wr2.Id );      
        wr2.Work_Request_Status__c = 'Submitted';
        TriggerHandler.isFirstTime = true;
        update wr2;
        test.stopTest();
    }
    
    //test method for trigger that validates all WR Tasks must be completed/cancelled before completing WR
    static testMethod void WRTaskValidationTest() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        container.createWorkRequests(true);
        container.findWorkRequestTasks();
        Pulse_Utils.setFieldToValue(container.testWorkRequests, 'Work_Request_Status__c', 'Cancelled');
        update container.testWorkRequests;        
    }
    

    //test method for cloned WRs processClonedWR
    static testMethod void wrClonedTriggerTest()    {
        // create all necessary setup records and a single Project using the test container
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1);
        // create WorkRequest objects associated to the Project 
        container.createWorkRequests(true);
        
        Test.startTest();
        EDiscovery_WorkRequest__c parentRec= container.testWorkRequests[0];
                
        EDiscovery_WorkRequest__c childRec = parentRec.clone(false,false,false,false);
        insert childRec;
        
        Test.stopTest();
        /*
        System.debug('The Child Cloned From Should Be = ' +[Select Name from EDiscovery_WorkRequest__c where id = :parentRec.Id limit 1].Name);
        System.debug('The Child ID = ' + childRec.Id);
        System.debug('Is The Child A Clone? = ' + childRec.isClone());        
        System.debug('The Child Clone Source From ID = ' + childRec.getCloneSourceId());
        System.debug('The Child Cloned From = ' + childRec.Work_Request_Cloned_From__c);
        System.debug('The Parent ID = ' + parentRec.Id);
        */        
        System.assertEquals(parentRec.Id,childRec.getCloneSourceId(), 'The IDs did not match');
     }

    // test that the validations for updating a WR to Complete all successfully block the update

    static testMethod void TestWRStatusValidationComplete(){
        Pulse_Test_Helpers.Test_Container container = wrValidationSetup();
        // you cannot complete a WR with open tasks, so all tasks will need to be completed
        updateWRTasks(container);
        test.startTest();
        container.testWorkRequests[0].Work_Request_Status__c = 'Complete';
        try{// This update will fail. Missing a QCE record











            update container.testWorkRequests[0];
            // add failure assertion to break test if update succeeds.
            system.assert(false, 'This update was expected to fail. There is no QCE record.');
        }catch(Exception exc2){
            system.assert(exc2.getMessage().contains('This Work Request must have a QCE record associated to this Work Request to be Completed.'));
            // Create a QCE record associated to the Work Request.
            container.createQceEntries(1, true);
            container.testWorkRequests[0].Work_Request_Status__c = 'Complete';
        }
        try{// second update will succeed.
            update container.testWorkRequests[0];
        }catch(Exception exc3){
            // add failure assertion to break test if update fails.
            system.assert(false, 'This update was expected to succeed. Sell Amount is positive and there is a QCE record.');
        }
        test.stopTest();
    }
    
    static testMethod void TestWRStatusValidationUpdateBillingQuantities(){
        Pulse_Test_Helpers.Test_Container container = wrValidationSetup('Field Office - Copying');
        
        test.startTest();
        container.testWorkRequests[0].Work_Request_Status__c = 'Update Billing Quantities';
        try{// first update will fail. Missing a positive sell amount and a QCE record
            update container.testWorkRequests[0];
            // add failure assertion to break test if update succeeds.
            system.assert(false, 'This update was expected to fail. There is no QCE record.');
        }catch(Exception exc1){
            system.debug(exc1.getMessage());
            system.assert(exc1.getMessage().contains('This Work Request must have a QCE record associated to this Work Request to be set to Update Billing Quantites.'));
            // Create a QCE record associated to the Work Request.
            container.createQceEntries(1, true);
            container.testWorkRequests[0].Work_Request_Status__c = 'Update Billing Quantities';
        }
        try{// second update will succeed.
            update container.testWorkRequests[0];
        }catch(Exception exc2){
            // add failure assertion to break test if update fails.
            system.assert(false, 'This update was expected to succeed. There is a QCE record.');
        }
        test.stopTest();
    }    
 
 static testMethod void TestWRStatusValidationReviewBillingQuantities(){
        Pulse_Test_Helpers.Test_Container container = wrValidationSetup();
        
        test.startTest();
        container.testWorkRequests[0].Work_Request_Status__c = 'Review Billing Quantities';
        try{// second update will succeed.
            update container.testWorkRequests[0];
        }catch(Exception exc1){
            // add failure assertion to break test if update fails.
            system.debug(exc1.getMessage());
        }
        test.stopTest();
    }    
    
    
 static testMethod void TestWRStatusValidationReviewed(){
        Pulse_Test_Helpers.Test_Container container = wrValidationSetup();
        
        test.startTest();
        container.testWorkRequests[0].Work_Request_Status__c = 'Reviewed';
        try{//First update should succeed
            update container.testWorkRequests[0];
        }catch(Exception exc1){
            system.debug(exc1.getMessage());
        }
        test.stopTest();
    }    
 
    static testMethod void TestWRStatusValidationReadyforInvoiceTest1(){
        Pulse_Test_Helpers.Test_Container container = wrValidationSetup();
        test.startTest();
        container.testWorkRequests[0].Work_Request_Status__c = 'Ready For Invoice';
        try{// first update will fail. One of the tasks Statuses is not complete
            update container.testWorkRequests[0];
            system.assert(false, 'This update was expected to fail. The associated Tasks are not all Complete.');
            // add failure assertion to break test if update succeeds.
        }catch(Exception exc1){
            system.assert(exc1.getMessage().contains('All WR Tasks Must be Finished or Cancelled to Cancel or Complete this WR'));
        }
        updateWRTasks(container);
        container.testWorkRequests[0].Work_Request_Status__c = 'Ready For Invoice';
        try{// second update will fail. Ops Done Date not set
            update container.testWorkRequests[0];
            system.assert(false, 'This update was expected to fail. The Ops Done Date is not set.');
            // add failure assertion to break test if update succeeds.
        }catch(Exception exc1){
            system.assert(exc1.getMessage().contains('Cannot set WR to Ready for Invoice if Ops Done Date is blank!'));
        }
    container.testWorkRequests[0].Ops_Done_Date__c = Date.today();
        container.testWorkRequests[0].Work_Request_Status__c = 'Ready For Invoice';
        try{// third update will fail. Work Request status is not 'Complete'
            update container.testWorkRequests[0];
            system.assert(false, 'This update was expected to fail. The Work Request was not Completed first.');
            // add failure assertion to break test if update succeeds.
        }catch(Exception exc1){
            system.assert(exc1.getMessage().contains('Cannot set a WR that is not Completed to Ready for Invoice status!'));
        }
        test.stopTest();
    }
        
    // setup the same test as above, adding all changes necessary to pass the
    // validations that lead up to the check for Status -> Complete, leaving
    // the Time Entry approval validation to check here
   static testMethod void TestWRStatusValidationReadyforInvoiceTest2(){
        Pulse_Test_Helpers.Test_Container container = wrValidationSetup();
        updateWRTasks(container);
        container.testBillableItems[0].Sell_Amount__c = 1.4;
        update container.testBillableItems;
        container.createQceEntries(1, true);
        container.testWorkRequests[0].Ops_Done_Date__c = Date.today();
        container.testWorkRequests[0].Work_Request_Status__c = 'Complete';
    update container.testWorkRequests;
        container.createProjectTimeActivities(1, true);
        container.createTimeEntries(1, false);
        container.testTimeEntries[0].Sta__c = 'Transfer Failed';
        container.testTimeEntries[0].Work_Request__c = container.testWorkRequests[0].Id;
        insert container.testTimeEntries;
        test.startTest();
        container.testWorkRequests[0].Work_Request_Status__c = 'Ready For Invoice';
        try{// first update will fail. One of the tasks Statuses is not complete
            update container.testWorkRequests[0];
            system.assert(false, 'This update was expected to fail. The Work Request has an unapproved/untransferred Time Entry.');
            // add failure assertion to break test if update succeeds.
        }catch(Exception exc1){
            system.debug(exc1.getMessage());
            system.assert(exc1.getMessage().contains('Cannot set a WR to RFI if there are any non-approved or non-transferred time entries'));
        }
        container.testTimeEntries[0].Sta__c = 'Approved';
        update container.testTimeEntries;
        container.testWorkRequests[0].Work_Request_Status__c = 'Ready For Invoice';
        try{// first update will fail. One of the tasks Statuses is not complete
            update container.testWorkRequests[0];
            // add failure assertion to break test if update succeeds.
        }catch(Exception exc1){
            system.debug(exc1.getMessage());
            system.assert(false, 'This update was expected to succeed. The Work Request has no unapproved/untransferred Time Entries.');
        }
        test.stopTest();
    }    
    
static testMethod void TestWRStatusValidationWIP(){
        Pulse_Test_Helpers.Test_Container container = wrValidationSetup();
        
        test.startTest();
        container.testWorkRequests[0].Work_Request_Status__c = 'WIP';
        try{// first should succeed
            update container.testWorkRequests[0];
            // add failure assertion to break test if update succeeds.
        }catch(Exception exc1){
            system.debug(exc1.getMessage());
        } 
        test.stopTest();
    }       
    
    
    private static Pulse_Test_Helpers.Test_Container wrValidationSetup(){
        return wrValidationSetup('Field BDS Work Request');
    }
    
    private static Pulse_Test_Helpers.Test_Container wrValidationSetup(string rtName){
        list<WR_TASK_Settings__c> wrTaskSettings = new list<WR_Task_Settings__c>();
        integer noOfSettings = 2;
        for(integer x = 1; x <= noOfSettings; x++){
          wrTaskSettings.add(new WR_Task_Settings__c(
                                 Name = 'T-0000' + string.valueOf(x),
                                 Task_Type__c = 'Test Task' + string.valueOf(x),
                                 Task_Order__c = x * 10,
                                 Status__c = 'Not Started',
                                 Record_Type__c = rtName,
                                 Department__c = 'Test Department'
                              ));
        }
        
        insert wrTaskSettings;
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createProjectsWithRecordType(1, 'Field Office Project', true);
        updatePricingItems(container, rtName, 5);
        container.createWorkRequestWithRecordType(1, rtName, true);
        container.findPricingLibraries();
        container.findBillableItems();
        container.findWorkRequestTasks();
        return container;
    }
    
    // add to the Billable Types field so that Billable items will be created for the new WR
    private static void updatePricingItems(Pulse_Test_Helpers.Test_Container container, string WRRecordType, integer noOfBLI){
        for(Integer x = 0; x < noOfBLI; x++){
            string wrBT = container.testPricingItems[x].WR_Billable_Types__c + ';' + WRRecordType;
            container.testPricingItems[x].WR_Billable_Types__c = wrBT;
        }
        update container.testPricingItems;
    }
    
    // update all the WR Tasks to cancelled
    private static void updateWRTasks(Pulse_Test_Helpers.Test_Container container){
        for(EDiscovery_WR_Task__c each : container.testWorkRequestTasks){
            each.Status__c = 'Cancelled';
        }
        update container.testWorkRequestTasks;
    }

    static testMethod void testProjectCloseoutValidation(){
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        container.createWorkRequestWithRecordType(1, 'Project Closeout', true);
        container.findWorkRequestTasks();
        Pulse_Utils.setFieldToValue(container.testWorkRequestTasks, 'Status__c', 'Cancelled');
        update container.testWorkRequestTasks;
        // attempt to set the WR to 'Complete'
        try{
            container.testWorkRequests[0].Work_Request_Status__c = 'Complete';
            update container.testWorkRequests;
            system.assert(false, 'This should have failed due to the for data disposition fields being null');
        } catch(Exception exc){
            system.assert(exc.getMessage().contains('fields in the Share Data Disposition section.'));
        }
        // update the 4 fields required to have values and try to set status
        // to 'Complete' again. This time it will succeed.        
        try{
            container.testWorkRequests[0].Work_Request_Status__c = 'Complete';
            container.testWorkRequests[0].Collection_Share_Volume_Deleted_GB__c = 5.6;
            container.testWorkRequests[0].Processing_Share_Volume_Deleted_GB__c = 0.0;
            container.testWorkRequests[0].Export_Share_Volume_Deleted_GB__c = 0.0;
            container.testWorkRequests[0].FTP_Share_Volume_Deleted_GB__c = 0.0;
            update container.testWorkRequests;
        }catch(Exception exc){
            system.assert(false, exc.getMessage());
        }
        container.testWorkRequests[0].Work_Request_Status__c = 'Invoiced';
        update container.testWorkRequests;
    }
}