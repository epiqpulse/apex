@isTest
private class Pulse_Te_Update_Approved_Batch_Test {
    static testMethod void PulseTimeEntryApprovedUpdateBatchTest(){
        // Lines below here determine the days so that a time entry can be created in the prior month
        Date LastMonth = date.today().addmonths(-1);
        Date FirstOfLastMonth = date.newInstance(Lastmonth.year(), lastmonth.month(), 1);
        Integer numberOfDays = Date.daysInMonth(FirstOfLastMonth.year(), FirstOfLastMonth.month());
        Date LastDayOfLastMonth = Date.newInstance(FirstOfLastMonth.year(), FirstOfLastMonth.month(), numberOfDays);
        
        // Integer here is used to send to the test helpers for number of projects
        Integer NumberOfApproved = 1;
        
        
        //Insert a project with number of approved items
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(NumberOfApproved);
        
        //Select the record type for standard time entry
        list<RecordType> RecordTypes = [Select Id, SObjectType, Name, IsActive, DeveloperName 
                                From RecordType Where SObjectType = 'Time_Entry__c' AND Name IN ('Standard Time Entry')];
             
       //Call the test helper container for create time entry 
       //False is passed so that data fields can then be updated and then insert here instead of the Test Helper Class
       container.createTimeEntries(1, false);
       container.testTimeEntries[0].date__c = LastDayOfLastMonth;
       container.testTimeEntries[0].recordtypeid = RecordTypes[0].id;
       container.testTimeEntries[0].hours__c = 5;
       container.testTimeEntries[0].sta__c = 'Pending Approval';
       insert container.testTimeEntries;
       
       //Begin the test where the batch job will select pending approval time entries from prior month and update to approved
       test.startTest();
         Pulse_Te_Update_Approved_Batch obj = new Pulse_Te_Update_Approved_Batch();
         DataBase.executeBatch(obj);
       test.stopTest();
      
       //Post Test Processing - Select time entries from the test container check how many items were approved and assert
       List<Time_Entry__c> postBatchApprovedList = [select Id, sta__c from Time_Entry__c where Id in : container.testTimeEntries];
             
       integer Approved = 0;
       system.assertEquals(NumberOfApproved, postBatchApprovedList.size());
       for(Time_Entry__c postBatchApproved : postBatchApprovedList){
           if(postBatchApproved.Sta__c == 'Approved') Approved += 1;
       }
       system.assertequals(1,Approved);
    }
}