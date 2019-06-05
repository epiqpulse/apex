/*
 *  Class:          Pulse_WRTask_Emailbuilder
 *  Test Class:     Pulse_WRTaskTrigger_Test
 * 
 *  Date:           Developer:      Notes:
 *  03/08/2019      JDaru           Updated code to use a new metadata
 *                                  object to determine the To and Cc 
 *                                  for the notification emails that get sent.     
*/
public class Pulse_WRTask_EmailBuilder {
    /* Build email messages for specific Work Request task
     * updates.
    */
    
    // send updates for ILM Closeout WR Tasks updated with Status = Sent to ServiceNow
    public static void ILMTaskUpdateNotifications(list<EDiscovery_WR_Task__c> ilmTasks){
        set<string> taskTypes = new set<string>();
        set<string> departments = new set<string>();
        set<string> wrIds = new set<string>();
        map<Id, string> parentTypeMap = new map<Id, string>();
        set<string> ownerIds = Pulse_Utils.getFieldValueSet(ilmTasks, 'OwnerId');
        map<Id, string> ownerNameMap = buildOwnerMap(ownerIds);
        map<string, Pulse_Closeout_Department_Queue__mdt> deptNotificationMap = buildDeptEmailMap();
        populateInfoSets(ilmTasks, taskTypes, departments, wrIds, parentTypeMap);
        // group the WR Tasks by Department + WRid so we can decide to send a single email for the Global Support tasks
        map<string, list<EDiscovery_WR_Task__c>> ilmTasksGrouped = groupILMTasks(ilmTasks);
        map<Id, list<Application_Database_Assignments__c>> appDBAssignments = buildAppDBMap(wrIds);
        // Build the necessary emails
        list<Messaging.SingleEmailMessage> messages = buildUpdateMessages(ilmTasksGrouped, ownerNameMap, appDBAssignments, deptNotificationMap, parentTypeMap);
        // Send the emails out
        Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
        system.debug('sent ' + results.size() + ' emails');
        if (results[0].success) {
            System.debug('The email was sent successfully.');
        } else {
            System.debug('The email failed to send: '
                  + results[0].errors[0].message);
        }
    }

    // build a map that stores the metadata where notifications should be emailed based on department
    public static map<string, Pulse_Closeout_Department_Queue__mdt> buildDeptEmailMap() {
        map<string, Pulse_Closeout_Department_Queue__mdt> deptEmailMap = new map<string, Pulse_Closeout_Department_Queue__mdt>();
        for(Pulse_Closeout_Department_Queue__mdt deptRecord : [select Department__c, To_Email__c, Cc_Email__c from Pulse_Closeout_Department_Queue__mdt]) {
            deptEmailMap.put(deptRecord.Department__c, deptRecord);
        }

        return deptEmailMap;
    }
    
    // build a map of id to name that will hold both users and queues since both can be the owners of a task.
    public static map<Id, string> buildOwnerMap(set<string> ownerIds){
        map<Id, string> ownerNameMap = new map<Id, string>();
        set<string> queueIds = new set<string>();
        set<string> userIds = new set<string>();
        for(string each : ownerIds){
            if(each.startsWith('005')){
                userIds.add(each);
            } else {
                queueIds.add(each);
            }
        }
        list<Group> queues = [select Id, Name from Group where Type = 'Queue' and Id in : queueIds];
        if(queues != null){
            for(Group eachQueue : queues) ownerNameMap.put(eachQueue.Id, eachQueue.Name);
        }
        list<User> users = [select Id, Name from User where Id in : userIds];
        if(users != null){
            for(User eachUser : users) ownerNameMap.put(eachUser.Id, eachUser.Name);
        }
        
        return ownerNameMap;
    }

    
    // group all the tasks by their Department + their WR Id
    public static map<string, list<EDiscovery_WR_Task__c>> groupILMTasks(list<EDiscovery_WR_Task__c> ilmTasks){
        map<string, list<EDiscovery_WR_Task__c>> ilmTasksGrouped = new map<string, list<EDiscovery_WR_Task__c>>();
        for(EDiscovery_WR_Task__c each : ilmTasks){
            if(ilmTasksGrouped.get(each.Department__c + string.valueOf(each.Work_Request__c)) == null){ 
                ilmTasksGrouped.put(each.Department__c + string.valueOf(each.Work_Request__c), new list<EDiscovery_WR_Task__c>());
            }
            ilmTasksGrouped.get(each.Department__c + string.valueOf(each.Work_Request__c)).add(each);
        }
        return ilmTasksGrouped;
    }
    
    // build email messages for each task, ilm WR Task 1.01 and 1.02 were both updated to Sent to ServiceNow, only send one email
    // with both tasks information.
    public static list<Messaging.SingleEmailMessage> buildUpdateMessages(map<string, list<EDiscovery_WR_Task__c>> ilmTasksGrouped, 
                                                                         map<Id, string> ownerNameMap, 
                                                                         map<Id, list<Application_Database_Assignments__c>> appDBAssignments, 
                                                                         map<string, Pulse_Closeout_Department_Queue__mdt> deptNotificationMap,
                                                                         map<Id, string> parentTypeMap){

        list<Messaging.SingleEmailMessage> messages = new list<Messaging.SingleEmailMessage>();
        // build messages according to what group owns it and what Database Assignment records exist for the WR 
        // update 03/08/2019: new custom metadata record retrieved based on Department that holds the recipient information                                                                    
        for(string eachKey : ilmTasksGrouped.keySet()){
            list<EDiscovery_WR_Task__c> taskGroup = ilmTasksGrouped.get(eachKey);
            list<EDiscovery_WR_Task__c> tasksSentTogether = new list<EDiscovery_WR_Task__c>();
            list<EDiscovery_WR_Task__c> tasksSentSeparate = new list<EDiscovery_WR_Task__c>();
            Pulse_Closeout_Department_Queue__mdt notificationRecipients = new Pulse_Closeout_Department_Queue__mdt();
            if(taskGroup[0].Department__c == 'Global_Support_Services'){
                if(deptNotificationMap.get(taskGroup[0].Department__c) != null) {
                    notificationRecipients = deptNotificationMap.get(taskGroup[0].Department__c);
                }
            } else {
                if(deptNotificationMap.get(taskGroup[0].Department__c) != null) {
                    notificationRecipients = deptNotificationMap.get(taskGroup[0].Department__c);
                }
            }
            for(EDiscovery_WR_Task__c eachTask : taskGroup){
                if(eachTask.Task_Type__c.startsWith('1.01') || eachTask.Task_Type__c.startsWith('1.02')){
                    tasksSentTogether.add(eachTask);
                } else {
                    tasksSentSeparate.add(eachTask);
                }
            }
            if(tasksSentTogether.size() > 0) {
                messages.add(createSingleEmailForTasks(tasksSentTogether, ownerNameMap, appDBAssignments, notificationRecipients, parentTypeMap));
            }
            if(tasksSentSeparate.size() > 0) {
                messages.addAll(createMultipleEmailsForTasks(tasksSentSeparate, ownerNameMap, appDBAssignments, notificationRecipients, parentTypeMap));
            }
        }

        return messages;
    }
    
    // take in a list of Tasks, a map of Work Request Id => Database Assignments and the WR Task Settings and build an email notification
    // for the tasks updated to Sent to ServiceNow
    public static Messaging.SingleEmailMessage createSingleEmailforTasks(list<EDiscovery_WR_Task__c> taskGroup, 
                                                                         map<Id, string> ownerNameMap, 
                                                                         map<Id, list<Application_Database_Assignments__c>> appDBAssignments, 
                                                                         Pulse_Closeout_Department_Queue__mdt notificationRecipients,
                                                                         map<Id, string> parentTypeMap){
        list<Application_Database_Assignments__c> appDBAList = appDBAssignments.get(taskGroup[0].Work_Request__c);
        // intro
        string emailBody =  'The following ' +
                            (taskGroup.size() == 1? 'ILM task has ' : 'ILM tasks have ') +
                            'been assigned from Pulse and submitted to ServiceNow. <br/>';
        // Task details 
        for(EDiscovery_WR_Task__c task : taskGroup){
            emailBody += '<br/>Task Type: ' + task.Task_Type__c + '<br/>Task Owner: ' + ownerNameMap.get(task.OwnerId) + '<br/>Task Notes: ' + task.Task_Notes__c + '<br/>';                                                                         
        }                                                                     
          
        // WR Section
        emailBody += buildEmailWRInfoSection(appDBAList[0]);
        // App DB section loop through assignments and add info for each
        emailBody += buildEmailAppDBInfoSection(appDBAList, true, false, null, null);
        // final section of email body
        emailBody += '<br/><u>Information Required Upon Completion</u><br/>';
        emailBody += '<br/>1.   ServiceNow Service Request # <br/>';
        emailBody += '<br/>Please contact ILMDeletionTeam@epiqglobal.com with any questions and notify ILM team when task is complete.<br/>';
        
        Messaging.SingleEmailMessage newMessage = new Messaging.SingleEmailMessage();
        newMessage.setSubject(parentTypeMap.get(taskGroup[0].Id) + ' Work Request Task (Initiation by GSS)');
        newMessage.setHtmlBody(emailBody);
        newMessage.setToAddresses(new list<string>{notificationRecipients.To_Email__c});
        if(!string.isBlank(notificationRecipients.Cc_Email__c)){
            newMessage.setCcAddresses(new list<string>{notificationRecipients.Cc_Email__c});
        }
        return newMessage;
    }
    
    public static list<Messaging.SingleEmailMessage> createMultipleEmailsForTasks(list<EDiscovery_WR_Task__c> taskGroup, 
                                                                                  map<Id, string> ownerNameMap, 
                                                                                  map<Id, list<Application_Database_Assignments__c>> appDBAssignments, 
                                                                                  Pulse_Closeout_Department_Queue__mdt notificationRecipients,
                                                                                  map<Id, string> parentTypeMap){
        list<Messaging.SingleEmailMessage> newMessages = new list<Messaging.SingleEmailMessage>();
        list<Application_Database_Assignments__c> appDBAList = appDBAssignments.get(taskGroup[0].Work_Request__c);
        for(EDiscovery_WR_Task__c task : taskGroup){
            list<string> recordTypeFilterList = new list<string>();
            string subjectBody;
            // intro
            string emailBody =  'The following ILM task has been assigned from Pulse and submitted to ServiceNow. <br/>';
            // Task details 
            emailBody += '<br/>Task Type: ' + task.Task_Type__c + '<br/>Task Owner: ' + ownerNameMap.get(task.OwnerId) + '<br/>Task Notes: ' + task.Task_Notes__c + '<br/>';                                                                                                                                          
            // WR Section
            emailBody += buildEmailWRInfoSection(appDBAList[0]);
            // App DB section loop through assignments and add info for each
            // for the 4.10 Task the App DB intro is different, so we pass a false
            // boolean to indicate it is not using the DMX intro line.
            if(task.Task_Type__c.startsWith('4.01.05 Deletion-Processing')){
                recordTypeFilterList = new list<string>{'DMX13', 'DMX14_Processing','Relativity_Hosting', 'Relativity_Processing'};
                emailBody += buildEmailAppDBInfoSection(appDBAList, false, false, null, recordTypeFilterList);
            } else if(task.Task_Type__c.startsWith('4.01.06 Deletion-Processing')){
                recordTypeFilterList = new list<string>{'Relativity_Hosting', 'Relativity_Processing'};
                emailBody += buildEmailAppDBInfoSection(appDBAList, false, false, null, recordTypeFilterList);
            } else if(task.Task_Type__c.startsWith('3.00')){
                recordTypeFilterList = new list<string>{'DMX13', 'DMX14_Processing'};
                emailBody += buildEmailAppDBInfoSection(appDBAList, true, true, 'Pending Archive', recordTypeFilterList);
            } else{
                recordTypeFilterList = new list<string>{'DMX13', 'DMX14_Processing'};
                emailBody += buildEmailAppDBInfoSection(appDBAList, true, true, 'Pending Deletion', recordTypeFilterList);
            }
            // final section of email body
            emailBody += '<br/><u>Information Required Upon Completion</u><br/>';
            emailBody += '<br/>1.   ServiceNow Service Request # <br/>';
            
            // add unique completion tasks and set appropriate subject string
            if(task.Task_Type__c.startsWith('3.00')){
                emailBody += '<br/>2.   DMX Archive Location <br/>';
                emailBody += '<br/>3.   Summmary of Archives: IT will add Summary of Archives on TSM Server (occupancy view) that is normally added as ES5 SR remark. <br/>';
                emailBody += '<br/>4.   Total Size <br/>';
                subjectBody = parentTypeMap.get(task.Id) + ' Work Request Task (DMX Archive)';
            } else {
                emailBody += '<br/>2.   Database Deleted Date: <br/>';
                emailBody += '<br/>3.   Data Deletion Comments: <br/>';
                emailBody += '<br/>4.   Volume Deleted (GB): <br/>';
                emailBody += '<br/>5.   Server Data Volume Deleted (GB): <br/>';
                emailBody += '<br/>6.   Server Data Deleted: <br/>';
                if(task.Task_Type__c.startsWith('4.01.01')){
                    subjectBody = parentTypeMap.get(task.Id) + ' Work Request Task (DMX Processing and/or Hosting Deletion)';
                } else if(task.Task_Type__c.startsWith('4.01.06 Deletion-Processing / Hosting | Nex')){
                    subjectBody = parentTypeMap.get(task.Id) + ' Work Request Task (NexLP Database Deletion)';
                } else {
                    subjectBody = parentTypeMap.get(task.Id) + ' Work Request Task (Equivio Database Deletion)';
                }
            }
            
            emailBody += '<br/>Please contact ILMDeletionTeam@epiqglobal.com with any questions and notify ILM team when task is complete.<br/>';
            
            Messaging.SingleEmailMessage newMessage = new Messaging.SingleEmailMessage();
            newMessage.setSubject(subjectBody);
            newMessage.setHtmlBody(emailBody);
            newMessage.setToAddresses(new list<string>{notificationRecipients.To_Email__c});
            if(!string.isBlank(notificationRecipients.Cc_Email__c)){
                newMessage.setCcAddresses(new list<string>{notificationRecipients.Cc_Email__c});
            }
            newMessages.add(newMessage);
        }
        return newMessages;
    }
    
    // add the information for DMX13 and/or DMX14 Application Database Assignments to the body of the email
    // 11-15-18 adding logic to only show app dbs in certain statuses for some task notifications
    // 11-19-18 added additional logic to check record type of App DB as well
    public static string buildEmailAppDBInfoSection(list<Application_Database_Assignments__c> appDBAList, boolean dmxAppDBSection,
                                                   boolean shareConditionally, string requiredStatus, list<string> appDBRecordTypes){
        string emailBody = '';
        if(dmxAppDBSection){
            emailBody += '<br/><u>Application Database - DMX13 and/or DMX14</u><br/>';
        } else {
            emailBody += '<br/><u>Application Database - Equivio</u><br/>';
        }
        system.debug(appDBAList.size());
        system.debug(appDBRecordTypes);
        for(Application_Database_Assignments__c eachAppDBA : appDBAList){
            string appStatus = eachAppDBA.Application_Database__r.Application_Database_Status__c;
            string recordType = eachAppDBA.AppDB_Record_Type__c;
            // skip record if we are only sharing based on status and the criteria isn't met
            // or if applicable recordtypes were provided and this criteria isn't met
            if((shareConditionally && appStatus != requiredStatus) || (appDBRecordTypes != null && !appDBRecordTypes.contains(recordType))){
            	continue;
            } 
	        string appLink = System.URL.getSalesforceBaseURL().toExternalForm() + '/' + eachAppDBA.Application_Database__c;
            emailBody += '<br/>Record Type: ' + eachAppDBA.AppDB_Record_Type__c + '<br/>';
         	emailBody += 'Application Databases ID: <a href="' + appLink + '">' + eachAppDBA.Application_Database__r.Name + '</a><br/>';
            emailBody += 'Application Database Status: ' + eachAppDBA.Application_Database__r.Application_Database_Status__c + '<br/>';
           	emailBody += 'Database Name: ' + eachAppDBA.AppDB_Database_Name__c + '<br/>';
            emailBody += 'Environment Location: ' + eachAppDBA.Application_Database__r.Environment_Location__c + '<br/>';
        }
        
        return emailBody;
    }
    
    // add the information for the Work Request to the body of the email using an application Database Assignment
    // queried with parent field information
    public static string buildEmailWRInfoSection(Application_Database_Assignments__c appDBA){
        string wrLink = System.URL.getSalesforceBaseURL().toExternalForm() + '/' + appDBA.Work_Request__c;
        string projLink = System.URL.getSalesforceBaseUrl().toExternalForm() + '/' + appDBA.Work_Request__r.Project__c;
        string emailBody = '<br/><u>Pulse Work Request Details</u><br/><br/>';
        DateTime requestedTime = appDBA.Work_Request__r.Requested_Time__c;
        string ampm = (requestedTime.hour() > 11 && requestedTime.hour() < 24 ? 'PM' : 'AM');
        string reqDate = requestedTime.month() +'/'+ requestedTime.day()+'/'+requestedTime.year() + ' ';
        string reqTime = requestedTime.time().hour() + ':' + requestedTime.time().minute() + ' ';
        emailBody += 'Work Request: <a href="' + wrLink + '">' + appDBA.Work_Request__r.Name + '</a><br/>';
        emailBody += 'Delivery Location: ' + appDBA.Work_Request__r.Delivery_Location__c + '<br/>';
        // 11-19-18 added hyperlink for Project that mimics WR and App DB hyperlinks
        emailBody += 'Project #: <a href="' + projLink + '">' + appDBA.Work_Request__r.Project__r.Name + '</a><br/>';
        emailBody += 'ESI ProjectCode: ' + appDBA.Work_Request__r.Project__r.ESI_Project_Code__c + '<br/>';
        emailBody += 'Project Name: ' + appDBA.Work_Request__r.Project_and_Name__c + '<br/>';
        emailBody += 'Work Request - Created By: ' + appDBA.Work_Request__r.CreatedBy.Name + '<br/>';
        emailBody += 'Work Request - Requested Time: ' +reqDate + reqTime + ampm + '<br/><br/>';
        // 11-16-18 added bolding and additional line breaks surrounding PM Instructions. Also added two
        // new fields below it.
        emailBody += 'PM Instructions: <b>' + appDBA.Work_Request__r.PM_Instructions__c + '</b><br/><br/>';
		emailBody += 'Processing Data Disposition: ' + appDBA.Work_Request__r.Processing_Data_Disposition__c + '<br/>';
        emailBody += 'Hosting Data Disposition: ' + appDBA.Work_Request__r.Hosting_Data_Disposition__c + '<br/>';
        return emailBody;
    }
    
    // build a map if app db assignments to Work requests, this will be used to add information to the email body.
    public static map<Id, list<Application_Database_Assignments__c>> buildAppDBMap(set<string> wrIds){
        map<Id, list<Application_Database_Assignments__c>> appDBAssignments = new map<Id, list<Application_Database_Assignments__c>>();
        list<Application_Database_Assignments__c> appDBAs = [select Id, Application_Database__c, AppDB_Database_Name__c, Work_Request__c, 
                                                             AppDB_Record_Type__c, Application_Database__r.Environment_Location__c,
                                                             Application_Database__r.Name, Application_Database__r.Application_Database_Status__c,
                                                             /* Work Request and Project info */
                                                             Work_Request__r.Name, Work_Request__r.Project__r.Name, Work_Request__r.Project__c,
                                                             Work_Request__r.PM_Instructions__c, Work_Request__r.Project__r.ESI_Project_Code__c,
                                                             Work_Request__r.CreatedBy.Name, Work_Request__r.Requested_Time__c,
                                                             Work_Request__r.Project_and_Name__c, Work_Request__r.Delivery_Location__c,
                                                             Work_Request__r.Processing_Data_Disposition__c, Work_Request__r.Hosting_Data_Disposition__c
                                                             from Application_Database_Assignments__c where Work_Request__c in : wrIds];
        // loop through the soql query results and populate the map that will get returned 
        for(Application_Database_Assignments__c each : appDBAs){
            if(appDBAssignments.get(each.Work_Request__c) == null) appDBAssignments.put(each.Work_Request__c, new list<Application_Database_Assignments__c>());
            appDBAssignments.get(each.Work_Request__c).add(each);
        }
        
        return appDBAssignments;
    } 
    
    // populate the string sets that will be used to identify the WR Settings and WR needed.
    public static void populateInfoSets(list<EDiscovery_WR_Task__c> ilmTasks, set<string> taskTypes, set<string> departments, set<string> wrIds, map<Id, string> parentTypeMap){
        for(EDiscovery_WR_Task__c each : 	[select Id, Task_Type__c, Department__c, Work_Request__c, 
                                          	Work_Request__r.WR_Record_Type_Formula_Field__c 
            								from EDiscovery_WR_Task__c where Id in : ilmTasks]){
            taskTypes.add(each.Task_Type__c);
            departments.add(each.Department__c);
            wrIds.add(string.valueOf(each.Work_Request__c));
            parentTypeMap.put(each.Id, each.Work_Request__r.WR_Record_Type_Formula_Field__c);
        }
    }
        
}