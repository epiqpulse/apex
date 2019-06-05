/* 
   Name:              PulseTEUpdateApproved.cls
   Description:       This Batch Class will pull data from the Time_Entry__c based on previous months date and Sta__c = Pending Approval
                      It will then update the Sta__c to "Approved"
                                            
                      Job will be scheduled to run on the 2nd day of month at 3 AM?
   
    Date              Version         Author                      Summary of Changes
    Test Class:       Pulse_Te_Update_Approved_Batch_Test
    Scheduler:        Pulse_Te_Update_Approved_sch
    BatchRunSettings: 
    Metadata:         BatchSettingsMDT('AutoApproveTime') - currently used for email recepients but can be used for batch sizing
      
-------------------------------------------------------------------------------------------------------------------------
    12/24/2018      1.0             Darren Davenport              Initial Release  
    02/21/2019      2.0             Darren Davenport              Revamed to call a queable class 
                                                                  Removed reporting from here since queued
                                                                  web call is slower than report - status is not correct. 
--------------------------------------------------------------------------------------------------------------------------
*/
global class Pulse_Te_Update_Approved_Batch implements Database.Batchable<sObject>,Database.AllowsCallouts,Database.Stateful{
    set<Id> queueJobIds = new set<Id>();   /* Variable used for queued job */
    
    global List<Time_Entry__c> teapprove = new List<Time_Entry__c>(); /* list used for updating time entries to approved or draft status */
    global List<Time_Entry__c> teapprover = new List<Time_Entry__c>(); /* list used for re-selecting Time Updates After batch completed */
    
    public Integer batchSize = 1; // Using a btach size of more than 1 will throw an errors when making webservice call
    Batch_Run_Settings__mdt AutoApproveTimeSettings; 
    
    /* Date Calculations used to determine previous month used in query below */
    Date LastMonth = date.today().addmonths(-1);
    Date FirstOfLastMonth = date.newInstance(Lastmonth.year(), lastmonth.month(), 1);
    Integer numberOfDays = Date.daysInMonth(FirstOfLastMonth.year(), FirstOfLastMonth.month());
    Date LastDayOfLastMonth = Date.newInstance(FirstOfLastMonth.year(), FirstOfLastMonth.month(), numberOfDays);
    

    boolean gotupdates = false;
    private static boolean success = true;
    
    public Pulse_Te_Update_Approved_Batch() {
        AutoApproveTimeSettings = Pulse_Utils.getBatchSettingsMDT('AutoApproveTime');
        if(AutoApproveTimeSettings.Batch_Size__c <= batchSize) batchSize = Integer.valueOf(AutoApproveTimeSettings.Batch_Size__c);
    }

    global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('here I am query locator');
        if(Test.isRunningTest()){
           return Database.getQueryLocator([Select Id, Name, Date__c, Sta__c, project__r.name FROM Time_Entry__c WHERE Sta__c in('Pending Approval', 'Transfer Failed') AND Date__c = Last_month limit 1]);
        }
        else{
           return Database.getQueryLocator([Select Id, Name, Date__c, Sta__c, project__r.name FROM Time_Entry__c WHERE Sta__c in ('Pending Approval', 'Transfer Failed') AND Date__c = Last_month]);
        }
    }
    
    global void execute(Database.BatchableContext BC, list<Time_Entry__c> scope){
       set<Id> TeQIdSet = new set<Id>();  /* Id Set that will be sent to queable class */
       
       for(Time_Entry__c te:scope){
          if(te.sta__c == 'Transfer Failed'){
             te.sta__c = 'Draft';
             system.debug('updating to draft');
          }
          else {
            te.Sta__c = 'Approved';
            system.debug('Updating to Approved');
          }  
          teapprove.add(te);  
          TeQIdSet.add(te.Id);
          System.debug('add id to set to call time entry');
          system.debug('teapprove = ' + teapprove);
        }        
        try{
          // update teapprove;  /* update here was moved to the queue job class -- items updated here were not passed to the queue job */
          system.debug('TeQIdSet = ' + TeQIDSet);
          queueJobIds.add(system.enqueueJob(new Pulse_TimeEntryUpdate_Queue(TeQIdSet)));
          system.debug('After Calling webservice');
        }
        catch(exception e){
          success = false;


        }  
    }    
    
    global void finish(Database.BatchableContext BC){
       /* Finish Method will still send email to Darren Davenport just for confirmation that the job ran */ 
       /* Report should go to nonone else */
       
       teapprover = [Select Id, Name, Date__c, Sta__c, project__r.name, API_Error_Message__c FROM Time_Entry__c WHERE Id in : teapprove];

       list<string> emailRecipients = generateRecipientList();
       AsyncApexJob a = [Select Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CompletedDate, ExtendedStatus, ApexClass.Name, Createdby.Email, CreatedBy.Name
                         From AsyncApexJob Where Id = :BC.getJobId()];
       String emailBody = '';
       emailBody += 'The Batch Update of Time Entries from Pending Approval to Approved and Transfer Failed to Draft has processed<br/>';
       emailBody += 'Total Records Processed ' + a.JobItemsProcessed + '&nbsp' + '&nbsp' + '&nbsp' + 'Total of ' + a.TotalJobItems + '&nbsp' + '&nbsp'
                    + 'Batches with ' + a.NumberOfErrors + ' Failures.<br/>';
       
       string Id = '';
       string Name = '';
       date Date_Entered = null;
       string PrjName = '';
       string Status = '';
       string Time_Entry_Error = '';
       string table = '<Table>';
       table += '<tr><th>ID</th><th><th><th>TE Name</th><th><th><th>TE Date Entered</th>' +
                '<th><th><th>Project Name</th><th><th><th>Status</th></th><th><th><th>Time Entry Error</th></tr>';
       for(Time_Entry__c teap : teapprover){
          gotupdates = true;
          Id = teap.id;
          Name = teap.name;
          Date_Entered = teap.date__c;
          PrjName = teap.project__r.name;
          Status = teap.sta__c;
          Time_Entry_Error = teap.API_Error_Message__c;
          table += '<tr><td>'+ Id +'</td><td><td><td>'+ Name +'</td><td><td><td>'+ Date_Entered +
                   '</td><td><td><td>'+ PrjName + '</td></td><td><td><td>'+ Status + '</td></td>' +
                   '</td><td><td><td>' + Time_Entry_Error + '</td></tr>';
       }
       table += '</table><br/><br/>';
                     
       Messaging.SingleEmailMessage mail1=new Messaging.SingleEmailMessage();
       /* String[] toAddresses = new String[] {a.CreatedBy.Email, 'ddavenport4@kc.rr.com'}; */
       /* mail1.setToAddresses(toAddresses); */
       Messaging.SingleEmailMessage mail2 = new Messaging.SingleEmailMessage();
       mail1.setToAddresses(emailRecipients);
       mail1.setSubject('Time Entry Record Status Updated to Approved or Draft');
       if(gotupdates){
         emailBody += 'An attempt was made to update the below time entry records to Approved or Draft Status:<br/>';
         emailBody += table;
         mail1.setHtmlBody(emailBody);
       }
       else{
         emailBody += 'Batch Job Completed and No Pending Approval or Transfer Failed Time Entires were found:<br/>';
         mail1.setHtmlBody(emailBody); 
       }
       /* mail1.setHtmlBody(emailBody); */
       Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail1});

    }    
    
    public list<string> generateRecipientList(){
        set<string> recipients = new set<string>();
        string successRecipients = (AutoApproveTimeSettings.Success_Log_Recipients__c != null ? AutoApproveTimeSettings.Success_Log_Recipients__c : '');
        string failureRecipients = (AutoApproveTimeSettings.Failure_Log_Recipients__c != null ? AutoApproveTimeSettings.Failure_Log_Recipients__c : '');
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
            if(AutoApproveTimeSettings.Use_Success_Recipients__c && successRecipients != ''){
                for(string emailAddress : successRecipients.split(';')){
                    if(emailAddress.contains('.') && emailAddress.contains('@')) recipients.add(emailAddress);
                }
            }
        }

        return new list<string>(recipients);
    }
}