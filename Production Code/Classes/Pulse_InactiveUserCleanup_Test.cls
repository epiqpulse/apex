@isTest
public class Pulse_InactiveUserCleanup_Test {

    // Test run of the user deactivation batch, the code had to be updated to automatically 
    // deactivate 2/3 of the created users that enter the batch due to the fact that there
    // is not a good way to simulate LastLoginDate on the user record.
    public static testMethod void testUserDeactivation(){
        Integer numberOfUsers = 10;
        Batch_Run_Settings__mdt userBatchSettings = Pulse_Utils.getBatchSettingsMDT('InactiveUserCleanup');
        system.debug(userBatchSettings);
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createUsers(numberOfUsers, 'Pulse Operations', true);
        DateTime created = DateTime.Now().addDays(-1);
        for(User testUser : container.testUsers){
            Test.setCreatedDate(testUser.Id, created);
            created = created.addDays(-10);
        }
        container.testUsers = [Select Id, IsActive, FirstName, LastName, EmployeeNumber, Profile.Name, 
                                UserName, CreatedDate, LastLoginDate from User where Id in : container.testUsers];
        system.debug(container.testUsers[0]);
        system.debug(container.testUsers.size());
        test.startTest();
        Pulse_InactiveUserCleanup_Batch cleanupBatch = new Pulse_InactiveUserCleanup_Batch(container.testUsers);
        Id batchExecution = Database.executeBatch(cleanupBatch);
        test.stopTest();
        AsyncApexJob apexJob = [select ExtendedStatus, JobItemsProcessed, Status, NumberofErrors, TotalJobItems from AsyncApexJob where Id = : batchExecution];
        system.assertEquals('Completed', apexJob.Status);
        system.debug(apexJob);
        List<User> postBatchUserList = [select Id, IsActive, LastLoginDate from User where Id in : container.testUsers];
        Integer stillActive = 0;
        system.assertEquals(numberOfUsers, postBatchUserList.size());
        for(User postBatchUser : postBatchUserList){
            if(postBatchUser.IsActive) stillActive += 1;
        }
        system.assertEquals(6, stillActive);
    }

    // Test to simulate a failed run of the batch, after the constructor
    // is called we set a TestVisible boolean that throws a custom 
    // exception before the record update is performed.
    public static testMethod void testUserDeactivationFailure(){
        Integer numberOfUsers = 10;
        Batch_Run_Settings__mdt userBatchSettings = Pulse_Utils.getBatchSettingsMDT('InactiveUserCleanup');
        system.debug(userBatchSettings);
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createUsers(numberOfUsers, 'Pulse Operations', true);
        DateTime created = DateTime.Now().addDays(-1);
        for(User testUser : container.testUsers){
            Test.setCreatedDate(testUser.Id, created);
            created = created.addDays(-10);
        }
        container.testUsers = [Select Id, IsActive, FirstName, LastName, EmployeeNumber, Profile.Name, 
                                UserName, CreatedDate, LastLoginDate from User where Id in : container.testUsers];
        system.debug(container.testUsers[0]);
        system.debug(container.testUsers.size());
        test.startTest();
        Pulse_InactiveUserCleanup_Batch cleanupBatch = new Pulse_InactiveUserCleanup_Batch(container.testUsers);
        cleanupBatch.testFailure = true;
        Id batchExecution = Database.executeBatch(cleanupBatch);
        test.stopTest();
        AsyncApexJob apexJob = [select ExtendedStatus, JobItemsProcessed, Status, NumberofErrors, TotalJobItems from AsyncApexJob where Id = : batchExecution];
        system.assertEquals('Completed', apexJob.Status);
    }

    // test that the standard controller appropriately pulls info from the metadata row for this batch
    static testMethod void testStandardBatchController(){
        Pulse_InactiveUserCleanup_Batch testBatch = new Pulse_InactiveUserCleanup_Batch();
        system.debug(testBatch);
        Batch_Run_Settings__mdt batchSettings = Pulse_Utils.getBatchSettingsMDT('InactiveUserCleanup');
        system.assertEquals(testBatch.batchSize, batchSettings.Batch_Size__c);
        if(batchSettings.Batch_Record_Age__c < 30){
            system.assertEquals(30, testBatch.cutoffDays);
        } else {
            system.assertEquals(testBatch.cutoffDays, batchSettings.Batch_Record_Age__c);
        }
    }

    // test Inactive User batch scheduler
    static testMethod void testInactiveUserScheduler(){
        test.startTest();
        Pulse_InactiveUserCleanup_Scheduler obj = new Pulse_InactiveUserCleanup_Scheduler();
        String chron = '0 0 3 2 * ?';
        String scheduleId = system.schedule('Inactive User Batch', chron, obj);
        test.stopTest();
        CronTrigger chronTrigger =[select Id from CronTrigger where Id = : scheduleId]; 
        system.assert(chronTrigger != null);
    }

}