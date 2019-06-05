/*
 *      Class:          Pulse_InternalWRTrigger_Handler
 *
 *      Test:           Pulse_InternalWR_Test
 *
 *      Description:    Holds the functional code called by the trigger on Internal_Work_Request__c
 *                  -   Currently creates any Internal_WR_Task__c marked as default in the metadata
 *                      record based on the Internal_Work_Requests Recordtype some exclusions are done
 *                      to handle the OE records where all three recordtypes have slightly different
 *                      defaults.
 *
 *                  Also handles the validations that exist around setting a particular status on the
 *                  Internal_Work_Request__c similar in implementation to the EDiscovery_WorkRequest__c
 *    
 *      Date            Version         Author              Summary of Changes  
 *
 *      1/31/2019         1.0           Jerry Daru          Newly Created
 *
 *
*/
public class Pulse_InternalWRTrigger_Handler {

    // entry method for insert trigger firing
    public static void HandleInsertTrigger(list<Internal_Work_Request__c> triggerNew, boolean isBefore) {
        if(isBefore) {
            // null out timestamp field values on cloned Internal Work Requests
            clearoutFieldsOnClone(triggerNew);
        } else {
            // create tasks marked as default for the Internal Work Requests Recordtype
            createDefaultTasksBasedOnRT(triggerNew);
        }
    }
    // entry method for update trigger firing
    public static void HandleUpdateTrigger(list<Internal_Work_Request__c> triggerNew, map<Id, Internal_Work_Request__c> oldMap) {
        // validate Internal_Work_Request records meet any requirements
        // necessary for  the status they are being put in.
        validateStatusChanges(triggerNew, oldMap);
    }
    
    // clear out the timestamp fields and update the cloned from field on the newly created cloned Internal Work Request
    public static void clearoutFieldsOnClone(list<Internal_Work_Request__c> triggerNew) {
        for(Internal_Work_Request__c eachIWR : triggerNew) {
            if(!eachIWR.isClone()) continue;
            eachIWR.Ops_Done_Date__c = null;
            eachIWR.Submitted_Time__c = null;
            eachIWR.Ready_for_Invoice__c = null;
            eachIWR.Status__c = 'Pre-Submission';
            eachIWR.Internal_Work_Request_Cloned_From__c = eachIWR.getCloneSourceId();
        }
    }
    
    // build two lists of custom metadata records (one for each Recordtype group CI or OE)
    // two lists are used because OR is not allowed in queries against metadata records
    // use the appropriate list to construct the new Internal_WR_Tasks and insert them.
    public static void createDefaultTasksBasedOnRT(list<Internal_Work_Request__c> triggerNew) {
        list<Internal_WR_Task__c> defaultTasks = new list<Internal_WR_Task__c>();
        set<string> recordTypes = Pulse_Utils.getFieldValueSet(triggerNew, 'Record_Type__c');
        list<Internal_WR_Task_Setting__mdt> CIDefaultTasks = [select Task_Name__c, Task_Order__c, Default_Owner__c, 
                                                              Default_Owner_Name__c, Default_Task__c, Owner_Type__c 
                                                              from Internal_WR_Task_Setting__mdt where CI_Task__c = true And Default_Task__c = true order by Task_Order__c];
        list<Internal_WR_Task_Setting__mdt> OEDefaultTasks = [select Task_Name__c, Task_Order__c, Default_Owner__c, 
                                                              Default_Owner_Name__c, Default_Task__c, Owner_Type__c 
                                                              from Internal_WR_Task_Setting__mdt where OE_Task__c = true And Default_Task__c = true order by Task_Order__c];
        for(Internal_Work_Request__c iWorkRequest : triggerNew){
            if(iWorkRequest.Record_Type__c.startsWith('CI')) {
                 defaultTasks.addAll(createDefaultTasks(iWorkRequest, CIDefaultTasks));
            } else if(iWorkRequest.Record_Type__c.startsWith('OE')) {
                 defaultTasks.addAll(createDefaultOETasks(iWorkRequest, OEDefaultTasks));
            }
        }
        if(!defaultTasks.isEmpty()) insert defaultTasks;
    }
    
    // take single Internal_Work_Request record and applicable list of metadata records and create the Internal_WR_Task records
    public static list<Internal_WR_Task__c> createDefaultTasks(Internal_Work_Request__c iWorkRequest, list<Internal_WR_Task_Setting__mdt> tasksToCreate) {
        // get the recordtype Id for the CI Internal WR Tasks
        Id recordTypeId = getRecordTypeforTask('CI');
        map<string, Id> userOwners = new map<string, Id>();
        map<string, Id> queueOwners = new map<string, Id>();
        list<Internal_WR_Task__c> newTasks = new list<Internal_WR_Task__c>();
        for(Internal_WR_Task_Setting__mdt defaultSetting : tasksToCreate){
            Decimal taskOrder = 10*defaultSetting.Task_Order__c;
            newTasks.add(new Internal_WR_Task__c(Internal_Work_Request__c = iWorkRequest.Id, Task_Type__c = defaultSetting.Task_Name__c, 
                                                 RecordTypeId = recordTypeId, Task_Order__c = taskOrder));
        }
        return newTasks;
    }
        
    // For the Internal Work Request, go through the default tasks and add them based on Record Type
    public static list<Internal_WR_Task__c> createDefaultOETasks(Internal_Work_Request__c iWorkRequest, list<Internal_WR_Task_Setting__mdt> tasksToCreate) {
        // get the recordtype Id for the OE Internal WR Tasks
        Id recordTypeId = getRecordTypeforTask('OE');
        map<string, Id> userOwners = new map<string, Id>();
        map<string, Id> queueOwners = new map<string, Id>();
        list<Internal_WR_Task__c> newTasks = new list<Internal_WR_Task__c>();
        Decimal taskOrder = 10;
        for(Internal_WR_Task_Setting__mdt defaultSetting : tasksToCreate){
            // Only Enhancement Requests need approval
            if(iWorkRequest.Record_Type__c != 'OE - Enhancement Request' && defaultSetting.Task_Name__c == 'Request Approval') continue;
            // Issue Escalation Internal Work Requests do not get Create/Update Source Control
            if(iWorkRequest.Record_Type__c == 'OE - Issues Escalation' && defaultSetting.Task_Name__c == 'Create/Update Source Control') continue;
            newTasks.add(new Internal_WR_Task__c(Internal_Work_Request__c = iWorkRequest.Id, Task_Type__c = defaultSetting.Task_Name__c, 
                                                 RecordTypeId = recordTypeId, Task_Order__c = taskOrder));
            taskOrder += 10;
        }
        return newTasks;
    }
    
    // gets the map of recordtype Ids => name and returns the id whose value starts with the string
    // passed into the method. Returns null if none are matching.
    public static Id getRecordTypeforTask(string rtName) {
        map<Id, String> rtMap = Pulse_Utils.getSObjectRecordTypeMap('Internal_WR_Task__c');
        for(Id eachRTId : rtMap.keySet()){
            if(rtMap.get(eachRTId).startsWith(rtName)) return eachRTId;
        }
        
        return null;
    }


    // validation method runs through the records in the trigger skipping ones where the status is not changing and
    // sorts the remaining into lists based on the status they are moving to
    public static void validateStatusChanges(list<Internal_Work_Request__c> triggerNew, map<Id, Internal_Work_Request__c> oldMap) {
        map<Id, string> validationErrorsMap = new map<Id, string>();
        set<string> iwrWithUnfinishedTasks = new set<string>();
        set<string> iwrWithTimeEntries = new set<string>();
        map<Id, Id> iwrNewOwnerMap = new map<Id, Id>();
        list<Internal_Work_Request__c> cancelledIWR = new list<Internal_Work_Request__c>();
        list<Internal_Work_Request__c> submittedIWR = new list<Internal_Work_Request__c>();
        list<Internal_Work_Request__c> completedIWR = new list<Internal_Work_Request__c>();
        list<Internal_Work_Request__c> readyForInvoiceIWR = new list<Internal_Work_Request__c>();
        list<Internal_Work_Request__c> invoicedIWR = new list<Internal_Work_Request__c>();
        for(Internal_Work_Request__c eachIWR : triggerNew) {
            string iwrStatus = eachIWR.Status__c;
            system.debug('Internal WR Status: ' + iwrStatus);
            // We're uninterested in internal work requests that aren't changing status so continue past those.
            if(iwrStatus == oldMap.get(eachIWR.Id).Status__c) continue;
            // add the trigger Internal Work Requests to lists corresponding to the status they're going to.
            // we will validate the internal work requests in each list accordingly.
            switch on iwrStatus{
                when 'Cancelled'{  cancelledIWR.add(eachIWR); }
                when 'Submitted'{ submittedIWR.add(eachIWR); }
                when 'Complete'{ completedIWR.add(eachIWR); }
                when 'Ready For Invoice'{ readyForInvoiceIWR.add(eachIWR); }          
                when 'Invoiced'{ invoicedIWR.add(eachIWR); }          
                when else{
                    // internal work request was set to a status there is no special validation for
                    continue;
                }
            }
        }
        // if any of the status requiring all tasks to be complete were chosen populate a
        // set of id strings with all Internal_Work_Requests that have unfinished tasks associated to them.
        if(!cancelledIWR.IsEmpty() || !submittedIWR.IsEmpty() || !completedIWR.IsEmpty() || !invoicedIWR.IsEmpty()) {
            iwrWithUnfinishedTasks = findUnfinishedIWR(triggerNew, iwrNewOwnerMap);
            iwrWithTimeEntries = findIWRWithTimeEntries(triggerNew);
        }

        // run the necessary validations based on which lists have records and store any issues found in a map that
        // is used later to add the appropriate errors to each record.
        if(!cancelledIWR.isEmpty()) validateCancelledIWR(cancelledIWR, iwrWithUnfinishedTasks, validationErrorsMap);
        if(!submittedIWR.isEmpty()) validateSubmittedIWR(submittedIWR, iwrNewOwnerMap, validationErrorsMap);
        if(!completedIWR.isEmpty()) validateCompletedIWR(completedIWR, iwrWithUnfinishedTasks, iwrWithTimeEntries, validationErrorsMap);
        if(!invoicedIWR.isEmpty()) validateInvoicedIWR(invoicedIWR, iwrWithUnfinishedTasks, validationErrorsMap);
        if(!readyForInvoiceIWR.isEmpty()) validateReadyForInvoiceIWR(readyForInvoiceIWR, oldMap, validationErrorsMap);
        
        if(validationErrorsMap.keySet().size() > 0){
            updateErroredRecords(triggerNew, validationErrorsMap);
        }
    }
        
    // populate the set of id strings for any Internal_Work_Request that has unfinished Internal_WR_Task__c
    // records associated to it. Also add values to the newOwner map so when an Internal Work Request is submitted
    // the owner of that record can be updated to the owner of the first incomplete task.
    public static set<string> findUnfinishedIWR(list<Internal_Work_Request__c> triggerNew, map<Id, Id> iwrNewOwnerMap) {
        set<string> iwrIds = new set<string>();
        for(Internal_WR_Task__c iwrTask : [select Internal_Work_Request__c, OwnerId, Task_Order__c  from Internal_WR_Task__c where Internal_Work_Request__c in : triggerNew 
                                           and Status__c not in ('Cancelled', 'Finished') order by Task_Order__c]){
            iwrIds.add(string.valueOf(iwrTask.Internal_Work_Request__c));
            if(iwrNewOwnerMap.get(iwrTask.Internal_Work_Request__c) == null) iwrNewOwnerMap.put(iwrTask.Internal_Work_Request__c, iwrTask.OwnerId);
        }

        return iwrIds;
    }
    
    // populate a set of string ids of all Internal Work Requests that have Time Entries associated.
    public static set<string> findIWRWithTimeEntries(list<Internal_Work_Request__c> triggerNew) {
        list<Time_Entry__c> iwrTimeEntries = [select Id, Internal_Work_Request__c from Time_Entry__c where Internal_Work_Request__c in : triggerNew];
        if(iwrTimeEntries.size() > 0) {
            return Pulse_Utils.getFieldValueSet(iwrTimeEntries, 'Internal_Work_Request__c');
        } else {
            return new set<string>();
        }
    }
    
    // currently for 'Complete' there is only validation based on unfinished tasks and Submitted Date needing a value, 
    // we also populate Ops Done Date if there isn't an error
    public static void validateCompletedIWR(list<Internal_Work_Request__c> completedIWR, set<string> iwrWithUnfinishedTasks, 
                                            set<string> iwrWithTimeEntries, map<Id, string> validationErrorsMap) {
        checkForCompletedTasks(completedIWR, 'Complete', iwrWithUnfinishedTasks, validationErrorsMap);
        for(Internal_Work_Request__c eachIWR : completedIWR) {
            if(eachIWR.Record_Type__c != 'CI Work Request'){
              system.debug('EachIWR rec type name = ' + eachIWR.record_Type__c);
              checkForTimeEntries(eachIWR, iwrWithTimeEntries, validationErrorsMap);
            }
            checkIWRForSubmittedDate(eachIWR, validationErrorsMap);
            if(!validationErrorsMap.keySet().contains(eachIWR.Id) && eachIWR.Ops_Done_Date__c == null) eachIWR.Ops_Done_Date__c = DateTime.Now();                                          
        }
    }
    
    // check that the Internal Work Request has Time Entries before allowing it to be completed.
    public static void checkForTimeEntries(Internal_Work_Request__c completedIWR, set<string> iwrWithTimeEntries, map<Id, string> validationErrorsMap) {
        string errorMessage = (validationErrorsMap.get(completedIWR.Id) != null ? validationErrorsMap.get(completedIWR.Id) : '');
        if(!iwrWithTimeEntries.contains(string.valueOf(completedIWR.Id))) {
            errorMessage = errorMessage + 'Completing an Internal Work Request requires at least one Time Entry. ';
            validationErrorsMap.put(completedIWR.Id, errorMessage);
        }
    }
    
    // check that the OE Internal Work Request has a value in Estimated Level of Effort before allowing it to be completed.
    public static void checkForEstimatedLOE(Internal_Work_Request__c completedIWR, set<string> iwrWithTimeEntries, map<Id, string> validationErrorsMap) {
        string errorMessage = (validationErrorsMap.get(completedIWR.Id) != null ? validationErrorsMap.get(completedIWR.Id) : '');
        if(completedIWR.Record_Type__c.startsWith('OE') && completedIWR.Estimated_Level_of_Effort__c == null) {
            errorMessage = errorMessage + 'Estimated Level of Effort must be filled out to complete an OE Internal Work Request. ';
            validationErrorsMap.put(completedIWR.Id, errorMessage);
        }
    }
    
    // check that the Internal Work Request has a value in Submitted date.
    public static void checkIWRForSubmittedDate(Internal_Work_Request__c iwr, map<Id, String> validationErrorsMap) {
        string errorMessage = (validationErrorsMap.get(iwr.Id) != null ? validationErrorsMap.get(iwr.Id) : '');
        if(iwr.Submitted_Time__c == null) errorMessage = errorMessage + 'This Internal Work Request has no Submitted Time. Please Submit before completing. ';
        if(errorMessage != '') validationErrorsMap.put(iwr.Id, errorMessage);
    }
    
    // currently for 'Cancelled' there is only validation based on unfinished tasks
    public static void validateCancelledIWR(list<Internal_Work_Request__c> cancelledIWR, set<string> iwrWithUnfinishedTasks, 
                                            map<Id, string> validationErrorsMap) {
        checkForCompletedTasks(cancelledIWR, 'Cancelled', iwrWithUnfinishedTasks, validationErrorsMap);
    }
    
    // currently for 'Submitted' there is no validation done in code, but we will populate the timestamp field
    public static void validateSubmittedIWR(list<Internal_Work_Request__c> submittedIWR, map<Id, Id> iwrNewOwnerMap, map<Id, string> validationErrorsMap) {
        for(Internal_Work_Request__c eachInternalWR : submittedIWR) {
            eachInternalWR.Submitted_Time__c = DateTime.Now();
            if(iwrNewOwnerMap.get(eachInternalWR.Id) != null) eachInternalWR.OwnerId = iwrNewOwnerMap.get(eachInternalWR.Id);
        }
    }
    
    // currently for 'Invoiced' there is only validation based on unfinished tasks
    public static void validateInvoicedIWR(list<Internal_Work_Request__c> invoicedIWR, set<string> iwrWithUnfinishedTasks, 
                                            map<Id, string> validationErrorsMap) {
        checkForCompletedTasks(invoicedIWR, 'Invoiced', iwrWithUnfinishedTasks, validationErrorsMap);
    }
    
    // 'Ready for Invoice' status requires that the Internal_Work_Request__c first be 'Complete'
    public static void validateReadyForInvoiceIWR(list<Internal_Work_Request__c> readyForInvoiceIWR, 
                                                  map<Id, Internal_Work_Request__c> oldMap, map<Id, String> validationErrorsMap) {
        
        for(Internal_Work_Request__c rfiIWR : readyForInvoiceIWR) {
            if(oldMap.get(rfiIWR.Id).Status__c != 'Complete') {
                validationErrorsMap.put(rfiIWR.Id, 'Internal Work Requests must be marked Complete before being set to Ready for Invoice.');
            } else {
                rfiIWR.Ready_for_Invoice__c = DateTime.Now();
            }
        }       
    }
    
    // this method performs the error map update for any status whose validation includes having no unfinished tasks
    // the records are looped through and if their id is in the set created earlier an error message is created
    // that references the status they would have been set to.
    public static void checkForCompletedTasks(list<Internal_Work_Request__c> updatedIWRrecords, string newStatus, 
                                              set<string> iwrWithUnfinishedTasks, map<Id, string> validationErrorsMap) {
        for(Internal_Work_Request__c updatedIWR : updatedIWRRecords) {
            if(iwrWithUnfinishedTasks.contains(string.valueOf(updatedIWR.Id))) {
                validationErrorsMap.put(updatedIWR.Id, 'Internal Work Requests cannot be set to ' + 
                                        newStatus + ' unless all of their Internal WR Tasks are either Finished or Cancelled. ');
            }
        }
    }
    
    // take the map of Id => error message created and use that to add errors to all the necessary Internal_Work_Request records
    // in the trigger list.
    public static void updateErroredRecords(list<Internal_Work_Request__c> triggerNew, map<Id, string> validationErrorsMap) {
        for(Internal_Work_Request__c iWorkRequest : triggerNew) {
            if(validationErrorsMap.get(iWorkRequest.Id) != null) {
                iWorkRequest.addError(validationErrorsMap.get(iWorkRequest.Id));
            }
        }
    }

}