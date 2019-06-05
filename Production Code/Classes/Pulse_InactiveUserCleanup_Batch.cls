/* 
    Name:           Pulse_InactiveUserCleanup_Batch.cls
    Description:    Batch job run everyday to check user accounts last login date. Any active 
                    user account that has not logged in a specific timeframe will be deactivated.
                    At the end of the batch execution an email will be sent out that details what 
                    accounts were deactivated by the process on that day.

                    The batch is controlled by a metadata record so that the number of days inactive 
                    that leads to an account being deactivated can be updated without changing the 
                    below code, but there is a minimum enforced here of 30 days so that the batch cannot
                    be set to deactivate all users.
    Test Class:     Pulse_InactiveUserCleanup_Test
    Scheduler:      Pulse_InactiveUserCleanup_Scheduler
    BatchRunSettings
    Metadata:       InactiveUserCleanup
   
    Date            Version         Author              Summary of Changes  
-----------------------------------------------------------------------------------------------
    12/24/2018      1.0             Jerry Daru          Initial Release  
-----------------------------------------------------------------------------------------------*/
global class Pulse_InactiveUserCleanup_Batch implements Database.Batchable<sObject>, Database.Stateful {

    public Integer batchSize = 200; // standard batch size from Salesforce will prevent setting size to more than 200 which might throw an error.
    Boolean isTest;
    Batch_Run_Settings__mdt InactiveUserSettings;    
    Date today = DateTime.Now().dateGMT();
    public Integer cutoffDays = 30; // minimum setting for days inactive as a safety precaution against the possibility of deactivating all users
    List<User> testUserList = new List<User>();
    List<User> usersToBeDeactivated = new List<User>();
    string exceptionMessage;
    Id jobId;
    private static boolean success = true;
    // the below variable is accessible to unit tests and allows us to simulate a failed batch execution 
    @TestVisible private boolean testFailure = false;

    // standard constructor
    public Pulse_InactiveUserCleanup_Batch() {
        InactiveUserSettings = Pulse_Utils.getBatchSettingsMDT('InactiveUserCleanup');
        if(InactiveUserSettings.Batch_Record_Age__c >= cutoffDays) cutoffDays = Integer.valueOf(InactiveUserSettings.Batch_Record_Age__c);
        if(InactiveUserSettings.Batch_Size__c <= batchSize) batchSize = Integer.valueOf(InactiveUserSettings.Batch_Size__c);
        isTest = Test.isRunningTest();
    }

    // unit test constructor takes in list of records to restrict Batch to test generated Users 
    public Pulse_InactiveUserCleanup_Batch(list<User> testUsers){
        system.debug('test constructor with list size: ' + testUsers.size());
        InactiveUserSettings = Pulse_Utils.getBatchSettingsMDT('InactiveUserCleanup');
        if(InactiveUserSettings.Batch_Record_Age__c >= cutoffDays) cutoffDays = Integer.valueOf(InactiveUserSettings.Batch_Record_Age__c);
        if(InactiveUserSettings.Batch_Size__c <= batchSize && InactiveUserSettings.Batch_Size__c > 0) batchSize = Integer.valueOf(InactiveUserSettings.Batch_Size__c);
        isTest = Test.isRunningTest();
        testUserList = testUsers;
    }

    // the Query for this batch orders user records by LastLoginDate in ASC order with Nulls first
    // this way we first look at user accounts that have never been logged into and once those are 
    // processed the rest are eligible for deactivation since the query does not pick up records that should
    // be left alone on this run.
    global Database.QueryLocator start(Database.BatchableContext BC){
        string queryString = 'Select Id, IsActive, FirstName, LastName, EmployeeNumber, Profile.Name, ' + 
                                'UserName, CreatedDate, LastLoginDate from User ' + 
                                'where IsActive = true ' + 
                                'and Profile.Name like \'Pulse%\' ' +
                                'and EmployeeNumber != null ' +
                                'and (LastLoginDate = null Or LastLoginDate < LAST_N_DAYS:' + string.valueOf(cutoffDays) +') ';
        if(isTest) queryString += 'and Id in : testUserList ';
        queryString += 'order by LastLoginDate, CreatedDate ASC NULLS FIRST';
        system.debug(testUserList.size());
        for(User testUser : testUserList) system.debug(testUser);
        system.debug(queryString);
        system.debug(Database.query(queryString));
        return Database.getQueryLocator(queryString);
    }
    

    // Check the users returned by the query. If their
    // LastLoginDate is null, skip ones whose CreatedDate
    // is recent enough to not be deactivated. Otherwise
    // add the user account to the list of ones that will be 
    // deactivated this run through. The update to deactivate 
    // is done once the final chunk of the batch is running so
    // this batch is an all-or-nothing scenario.
    global void execute(Database.BatchableContext BC, list<User> ActiveUsers){
        if(jobId == null) jobId = BC.getJobId();
        system.debug('Active Users in batch: ' + ActiveUsers.size());
        for(User activeUser : ActiveUsers){
            system.debug(activeUser);
            system.debug(cutoffDays);
            system.debug(today);
            if(activeUser.LastLoginDate == null){
                system.debug('lastlogin was null');
                if(activeUser.CreatedDate.Date() >= today.addDays(-1*cutoffDays)){
                    system.debug('Account young enough to not deactivate.');
                    continue;
                }
            }
            system.debug('Deactivating this User.');
            activeUser.isActive = false;
            activeUser.System_Deactivated_Date__c = DateTime.Now();
            usersToBeDeactivated.add(activeUser);
        }

        ASyncApexJob thisBatchRun = [select Id, JobItemsProcessed, TotalJobItems from ASyncApexJob where Id = : jobId];
        system.debug(thisBatchRun);
        // attempt update if the list has Users and items Processed is one less than the total (that means we are on the last chunk of the batch)
        if(usersToBeDeactivated.size() > 0 && thisBatchRun.JobItemsProcessed == thisBatchRun.TotalJobItems - 1){
            system.debug('Deactivating ' + usersToBeDeactivated.size() + ' records.');
            try{
                if(testFailure == true) throw new InactiveUserBatchException('testing failure condition');
                update usersToBeDeactivated;
                system.debug('We did it');
            }catch(Exception exc){
                exceptionMessage = exc.getMessage();
                success = false;
                system.debug('I have terrible news, everybody.');
                system.debug(exceptionMessage);
            }
        }
    }
    
    // Potentially send a result email out based on the settings
    // for this batch in the related Metadata object row
    global void finish(Database.BatchableContext BC){
        buildResultMessage();
    }   

    // build the message we send based on whether the batch 
    // results were a success or a failure and if there were
    // any users actually deactivated.
    public void buildResultMessage(){
        list<string> emailRecipients = generateRecipientList();
        if(emailRecipients.size() > 0){
            Messaging.SingleEmailMessage emailSummary = new Messaging.SingleEmailMessage();
            if(success){
                emailSummary.setSubject('Inactive User Deactivation Batch Completion Summary');
            } else {            
                emailSummary.setSubject('Inactive User Deactivation Batch Error Summary');
            }
            emailSummary.setHtmlBody(generateResultEmailBody());
            if(success && usersToBeDeactivated.size() > 0) emailSummary.setFileAttachments(new Messaging.EmailFileAttachment[]{generateEmailAttachment()});
            emailSummary.setToAddresses(emailRecipients);
            system.debug(emailSummary);
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new list<Messaging.SingleEmailMessage>{emailSummary});
            system.debug(results);
        }
    }

    public string generateResultEmailBody(){
        string url = System.URL.getSalesforceBaseURL().toExternalForm() + '/';
        string reportLink = (InactiveUserSettings.Report_Id__c != null && InactiveUserSettings.Report_Id__c != ''? url + InactiveUserSettings.Report_Id__c : null);
        string emailBody = 'Users who have not been active in the last ' + cutoffDays + ' days are subject to deactivation by this batch process. ';
        if(success) {
            emailBody += 'The batch completed successfully and deactivated ' + usersToBeDeactivated.size() + ' users. <br/><br/>';
            if(usersToBeDeactivated.size() > 0){
                emailBody += 'A csv file with the deactivated users is attached. ';
                if(reportLink != null) emailBody += 'A report of users deactivated today can be found <a href="' + reportLink + '">Here</a>.<br/><br/>';
                emailBody += buildHtmlTable(usersToBeDeactivated); 
            }
        } else {
            emailBody += 'The batch did not complete successfully. ';
            emailBody += 'The following error was thrown during execution: <br/><br/>';
            emailBody += exceptionMessage;
        }
        return emailBody;
    }

    // create an html table to be displayed in the email body of all records deactivated
    public string buildHtmlTable(list<User> usersToBeDeactivated){
        string firstName = '';
        string lastName = '';
        string userName = '';
        string idString = '';
        string employeeNumber = '';
        string profileName = '';
        string lastLogin = '';
        // start table html and create first row with column headers
        string table = '<table>';
        table += '<tr><th>UserName</th><th>First Name</th><th>Last Name</th>' + 
                    '<th>Id</th><th>Employee Number</th>' +
                    '<th>Profile</th><th>Last Login</th></tr>';
        // loop through the list of deactivated users and create a row in the table for each one.
        for(User user : usersToBeDeactivated){
            userName = (user.UserName == null? '' : user.UserName);
            firstName = (user.FirstName == null? '' : user.FirstName);
            lastName = (user.LastName == null? '' : user.LastName);
            idString = string.valueOf(user.Id);
            employeeNumber = (user.EmployeeNumber == null? '' : string.valueOf(user.EmployeeNumber));
            profileName = user.Profile.Name;
            lastLogin = (user.LastLoginDate == null? '' : string.valueOf(user.lastLoginDate));
            table += '<tr><td>'+ userName +'</td><td>'+ firstName +'</td><td>'+ lastName +
                    '</td><td>'+ idString +'</td><td>'+ employeeNumber +
                    '</td><td>'+ profileName +'</td><td>'+ lastLogin + '</td></tr>';
        }
        // close out table html and return
        table += '</table><br/><br/>';

        return table;
    }

    // build the recipient list for the batch email based on if the batch result is success or not,
    // start with a set so that in the event of a failure users in both recipient fields on the metadata
    // will only be added to the email once.
    public list<string> generateRecipientList(){
        set<string> recipients = new set<string>();
        string successRecipients = (InactiveUserSettings.Success_Log_Recipients__c != null ? InactiveUserSettings.Success_Log_Recipients__c : '');
        string failureRecipients = (InactiveUserSettings.Failure_Log_Recipients__c != null ? InactiveUserSettings.Failure_Log_Recipients__c : '');
        if(success && successRecipients != ''){
            for(string emailAddress : successRecipients.split(';')){
                if(emailAddress.contains('.') && emailAddress.contains('@')) recipients.add(emailAddress);
            }
        } else if(!success){
            if(failureRecipients != ''){
                for(string emailAddress : failureRecipients.split(';')){
                    if(emailAddress.contains('.') && emailAddress.contains('@')) recipients.add(emailAddress);
                }
            }
            if(InactiveUserSettings.Use_Success_Recipients__c && successRecipients != ''){
                for(string emailAddress : successRecipients.split(';')){
                    if(emailAddress.contains('.') && emailAddress.contains('@')) recipients.add(emailAddress);
                }
            }
        }

        return new list<string>(recipients);
    }

    // generate the csv file that is added in the event of a success that actually updates Users
    public Messaging.EmailFileAttachment generateEmailAttachment(){
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();  
        attachment.setBody(Blob.valueOf(generateCSVValue()));  
        attachment.setContentType('text/csv');  
        attachment.setFileName('Users Deactivated ' + string.valueOf(Date.today()) + '.csv');  
        attachment.setinline(false);  
        return attachment;
    }

    // build the csv string for the attachment
    public string generateCSVValue(){
        string csv = 'Id,UserName,FirstName,LastName,EmployeeNumber,ProfileName,IsActive\n';
        string firstName = '';
        string lastName = '';
        string userName = '';
        string idString = '';
        string employeeNumber = '';
        string profileName = '';
        for(User user : usersToBeDeactivated){
            idString = string.valueOf(user.Id);
            userName = (user.UserName == null? '' : user.UserName);
            firstName = (user.FirstName == null? '' : user.FirstName);
            lastName = (user.LastName == null? '' : user.LastName);
            employeeNumber = (user.EmployeeNumber == null? '' : string.valueOf(user.EmployeeNumber));
            profileName = user.Profile.Name;
            csv += idString +  ',' + userName + ',' + firstName + ',' + lastName + ',' + employeeNumber + ',' + profileName + ',false\n';
        }
        system.debug(csv);
        return csv;
    }

    // custom exception class created so we can throw and process
    // an exception in the case of a failure.
    public class InactiveUserBatchException extends Exception {}
}