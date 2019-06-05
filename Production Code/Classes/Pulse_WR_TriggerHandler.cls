/* ----------------------------------------------------------------------------------------------------------------- 
 Name = Pulse_WR_TriggerHandler
 Created = 2018
 Description = This Apex Class is used to handle the WR trigger Before and After Changes
               The below code controls:
                     * Validations surrounding WR status changes
                     * Builds WR tasks and has logic calling the WR Task Custom Settings
                     * Controls some notifications involving WR status Changes
                     Test Class = Pulse_WorkRequestTrigger_Test
 Modifications:
               02/21/2019 - Modified to comment out any references or calls that involve Review Billing Quantities 
               02/21/2019 - Added ILM Project Closeout Data Disposition validation rule
               02/21/2019 - Replaces Home Office Project with Security Clearance Project
               02/21/2019 - Added Status Change Notifications 
               02/22/2019 - User Story 331856 - When cloning a WR need to null out the Estimated_Complete_Time__c
               05/28/2019 - User Story 344164 - Tech Debt Clean up
                          - Added two new Metadata objects 
                            -- Pulse_WR_Record_Type_Names__mdt - used to select record type names that notifications are sent on
                            -- Pulse_WR_Notification_Statuses__mdt - used to select wr statuses that notifications are sent on
-------------------------------------------------------------------------------------------------------------------*/
public class Pulse_WR_TriggerHandler {
    public static boolean secondRun = false;
    public static void handleInsertTrigger(list<EDiscovery_WorkRequest__c> triggerNew, boolean isBefore){
        if(isBefore){
            // process Cloned Work Request. Validate that clone is associated to same Project
            // and clear out fields meant to track request status.
            processClonedWR(triggerNew);
            // update the headline field of the work request with either ITAR and HIPAA flags if necessary
            updateWorkRequestHeadline(triggerNew);
        } else {
            // create necessary Work Request Tasks based on Record Type.
            createWorkRequestTasks(triggerNew);
            // add Billable Items
            addBillableItems(triggerNew);
        }
    }
    
    public static void handleUpdateTrigger(list<EDiscovery_WorkRequest__c> triggerNew, map<Id, EDiscovery_WorkRequest__c> oldMap, boolean isBefore){
        if(isBefore){
            validateStatusChanges(oldMap, triggerNew);
            validateOwnerChanges(oldMap, triggerNew);
        } else {
            // send email notifications to applicable groups when a work requests
            // status is changed.
            sendWorkRequestNotifications(triggerNew, oldMap);
            /*list<EDiscovery_WorkRequest__c> AutoStatWRs = GetAutoStatWRs(triggerNew);
            if(AutoStatWRs.size() > 0) {
                Pulse_BillingLogic_Class billingClass = new Pulse_BillingLogic_Class();
                billingClass.ProcessAutoStatWRs(AutoStatWRs);
            }*/
        }
    }
    /*private static list<EDiscovery_WorkRequest__c> GetAutoStatWRs(list<EDiscovery_WorkRequest__c> WRs) {
        list<EDiscovery_WorkRequest__c> wrsToProcess = new list<EDiscovery_WorkRequest__c>();
        
        for(EDiscovery_WorkRequest__c wr : WRs) {
            if(wr.WR_Record_Type_Formula_Field__c == 'Monthly Auto Stats Collection') {
                wrsToProcess.add(wr);
            }
        }
        return wrsToProcess;
    }*/
    // for each Cloned WorkRequest in the trigger verify that it has the same Project as the parent
    //  null out some fields and set the Work_Request_Cloned_From__c field
    private static void processClonedWR(list<EDiscovery_WorkRequest__c> triggerNew){
        Id parentId = null;
        set<Id> parentWRIds = new set<Id>();
        // grab the ids of any parent Work Requests on cloned records
        for(EDiscovery_WorkRequest__c wr : triggerNew){
            if(wr.isClone()) parentWRIds.add(wr.getCloneSourceId());
        }
        
        // if there were any cloned records found build a map of
        // parent work requests and loop through the trigger records
        // a second time to null out fields and populate Work_Request_Cloned_From__c.
        if(parentWRIds.size() > 0){
            map<Id, EDiscovery_WorkRequest__c> parentWRMap = new map<Id, EDiscovery_WorkRequest__c>([Select Id, Name, Project__c from EDiscovery_WorkRequest__c where id = :parentWRIds]);
            
            for(EDiscovery_WorkRequest__c each : triggerNew){
                if(!each.isClone()) continue;
                EDiscovery_WorkRequest__c parentWr = parentWRMap.get(each.getCloneSourceId());
                if(parentWr.Project__c != each.Project__c){
                    each.addError('Cloning a WR to a different project is not allowed!');
                }else {
                    each.Work_Request_Cloned_From__c = parentWr.Name;
                    each.Ops_Done_Date__c = null;
                    each.Submitted_Time__c = null;
                    each.Invoiced_Date__c = null;
                    each.Ready_for_Invoice__c = null;
                    each.Ready_for_Sales_Review__c = null;
                    each.Billing_Summary_Created__c = null;
                    each.Estimated_Complete_Time__c = null;
                    each.DTI_Express_Request__c = false;
                    each.Bill_With_Other_Work_Requests__c = 'No';
                    each.Invoice_Number__c = '';
                    each.Invoice_Total__c = null;
                    each.P_L_Month__c = '';               
                }
            }
        }
    }
    
    // add HIPAA or ITAR or Country restriction text tags to Work Request Headline field
    private static void updateWorkRequestHeadline(list<EDiscovery_WorkRequest__c> triggerNew){
        set<string> projIds = Pulse_Utils.getFieldValueSet(triggerNew, 'Project__c');
        map<Id, EDiscovery_Project__c> projectMap = new map<Id, EDiscovery_Project__c>([select Id, ITAR_Project__c, Security_Clearance_Project__c, HIPAA_Project__c, billing_system__c, Country_Restriction__c
                                                                                      from EDiscovery_Project__c where Id in : projIds]);
        
        // update the WR headline to include the Country Restriction, ITAR and HIPAA flags if necessary 
        for(EDiscovery_WorkRequest__c each : triggerNew) {
            EDiscovery_Project__c project = projectMap.get(each.Project__c);

            // If the work request inserted has a Project check to see if we need to append a Project type to the Headline field and do so.
            if(project != null){
                if(project.ITAR_Project__c == 'Yes' && !each.Headline__c.startsWithIgnoreCase('*** ITAR ***') && !each.Headline__c.containsIgnoreCase('*** ITAR ***')) {
                    each.Headline__c = '*** ITAR *** ' + each.Headline__c;
                } else if(!String.isEmpty(project.Country_Restriction__c) && !each.Headline__c.startsWithIgnoreCase('*** ')  && !each.Headline__c.containsIgnoreCase(' Restricted ***')) {
                    each.Headline__c = '*** ' + project.Country_Restriction__c + ' Restricted *** ' + each.Headline__c;
                } else if(project.HIPAA_Project__c == 'Yes' && !each.Headline__c.startsWithIgnoreCase('*** HIPAA ***')  && !each.Headline__c.containsIgnoreCase('*** HIPAA ***')) {
                    each.Headline__c = '*** HIPAA *** ' + each.Headline__c;
                } else if(project.Security_Clearance_Project__c == 'Yes' && !each.Headline__c.startsWithIgnoreCase('*** Security Clearance Project ***')  && !each.Headline__c.containsIgnoreCase('*** Security Clearance Project ***')) {
                    each.Headline__c = '*** Security Clearance Required *** ' + each.Headline__c;
                }
            }
        }
    }
    
    private static void validateStatusChanges(map<Id, EDiscovery_WorkRequest__c> oldMap, list<EDiscovery_WorkRequest__c> triggerNew){
        map<Id, string> wrRecordTypes = Pulse_Utils.getSObjectRecordTypeMap('EDiscovery_WorkRequest__c');
        // retrieve a set of Work Request Ids where there are associated tasks that 
        // are not 'Finished' or 'Cancelled'. Doing this here because there are 4 
        // separate status values on the Work Request where this will be used.
        set<string> wrWithUnfinishedTasks = getWRWithUnfinishedTasks(triggerNew);
        list<EDiscovery_WorkRequest__c> completedWRs = new list<EDiscovery_WorkRequest__c>();
        list<EDiscovery_WorkRequest__c> ubqWRs = new list<EDiscovery_WorkRequest__c>();
        list<EDiscovery_WorkRequest__c> wipWRs = new list<EDiscovery_WorkRequest__c>();
       // list<EDiscovery_WorkRequest__c> rbqWRs = new list<EDiscovery_WorkRequest__c>();
        list<EDiscovery_WorkRequest__c> rfiWRs = new list<EDiscovery_WorkRequest__c>();
        list<EDiscovery_WorkRequest__c> revWRs = new list<EDiscovery_WorkRequest__c>();
        list<EDiscovery_WorkRequest__c> subWRs = new list<EDiscovery_WorkRequest__c>();
        list<EDiscovery_WorkRequest__c> cancelledWRs = new list<EDiscovery_WorkRequest__c>();
        list<EDiscovery_WorkRequest__c> invoicedWRs = new list<EDiscovery_WorkRequest__c>();
        map<Id, string> wrErrorsMap = new map<Id, string>();
        for(EDiscovery_WorkRequest__c eachWR : triggerNew){
            string wrStatus = eachWR.Work_Request_Status__c;

            // We're uninterested in work requests that aren't changing status so continue past those.
            if(wrStatus == oldMap.get(eachWR.Id).Work_Request_Status__c) continue;
            // add the trigger Work Requests to lists corresponding to the status they're going to.
            // we will validate the work requests in each list accordingly.
            switch on wrStatus{
                when 'Complete'{ completedWRs.add(eachWR); }
                when 'Update Billing Quantities'{ ubqWRs.add(eachWR); }
                when 'WIP'{ wipWRs.add(eachWR); }
                // when 'Review Billing Quantities'{ rbqWRs.add(eachWR); }
                when 'Ready For Invoice'{ rfiWRs.add(eachWR); }
                when 'Reviewed'{ revWRs.add(eachWR); }
                when 'Submitted'{ subWRs.add(eachWR); }
                when 'Cancelled'{ cancelledWrs.add(eachWR); }                
                when 'Invoiced'{ invoicedWrs.add(eachWR); }                
                when else{
                    // Work request was set to a status there is no special validation for
                    continue;
                }
            }
        }

        if(!completedWRs.isEmpty()) wrCompleteValidation(completedWRs, wrRecordTypes,  wrErrorsMap, wrWithUnfinishedTasks);
        if(!ubqWRs.isEmpty()) wrUpdateBillingQuantityValidation(ubqWRs, wrRecordTypes, wrErrorsMap);
        if(!wipWRs.isEmpty()) wrUpdateWipValidation(wipWRs);
       // if(!rbqWRs.isEmpty()) wrUpdateReviewBillingQuantitiesValidation(rbqWRs, wrRecordTypes);
        if(!rfiWRs.isEmpty()) wrupdateReadyForInvoiceValidation(rfiWRs, wrErrorsMap, OldMap, wrRecordTypes, wrWithUnfinishedTasks);
        if(!revWRs.isEmpty()) wrupdateReviewedValidation(revWRs);
        if(!cancelledWrs.isEmpty()) wrCancelledValidation(cancelledWrs, wrErrorsMap, wrWithUnfinishedTasks);
        if(!invoicedWrs.isEmpty()) wrInvoicedValidation(invoicedWrs, wrErrorsMap, wrWithUnfinishedTasks);
        if(!subWRs.isEmpty()) wrSubmittedValidation(subWRs, oldMap, wrRecordTypes, wrErrorsMap);
        
        // add any applicable errors to the Trigger WR using the map we populated in the previous methods.
        for(EDiscovery_WorkRequest__c updatedWR : triggerNew){
            system.debug('Putting an error on? ' + (wrErrorsMap.get(updatedWR.Id) != null));
            if(wrErrorsMap.get(updatedWR.Id) != null) system.debug(wrErrorsMap.get(updatedWR.Id));
            if(wrErrorsMap.get(updatedWR.Id) != null) updatedWR.addError(wrErrorsMap.get(updatedWR.Id));
        }
    }
    
    private static void wrCancelledValidation(list<EDiscovery_WorkRequest__c> cancelWRs, map<Id, string> wrErrorsMap, set<string> wrWithUnfinishedTasks){
        for(EDiscovery_WorkRequest__c each : cancelWRs){
            boolean errorFree = true;
            if(wrWithUnfinishedTasks.contains(each.Id)){
                system.debug('task requirement failed');
                errorFree = false;
                wrErrorsMap.put(each.Id, 'All WR Tasks Must be Finished or Cancelled to Cancel or Complete this WR');
            }
        }
    }
    
    private static void wrInvoicedValidation(list<EDiscovery_WorkRequest__c> invoicedWRs, map<Id, string> wrErrorsMap, set<string> wrWithUnfinishedTasks){
        for(EDiscovery_WorkRequest__c each : invoicedWRs){
            boolean errorFree = true;
            if(wrWithUnfinishedTasks.contains(each.Id)){
                system.debug('task requirement failed');
                errorFree = false;
                wrErrorsMap.put(each.Id, 'All WR Tasks Must be Finished or Cancelled to Cancel or Complete this WR');
            }
        }
    }
    
    private static void validateOwnerChanges(map<Id, EDiscovery_WorkRequest__c> oldMap, list<EDiscovery_WorkRequest__c> triggerNew){
        map<Id, string> wrRecordTypes = Pulse_Utils.getSObjectRecordTypeMap('EDiscovery_WorkRequest__c');
        list<EDiscovery_WorkRequest__c> FoOwnerChgs = new list<EDiscovery_WorkRequest__c>();
        map<Id, string> wrErrorsMap = new map<Id, string>();
        for(EDiscovery_WorkRequest__c each : triggerNew){
            string wrOwner = each.Ownerid;
            // We're uninterested in work requests that aren't changing Owner so continue past those.
            if(wrOwner == oldMap.get(each.Id).ownerid) continue;
            // add the trigger Work Requests to lists corresponding to the status they're going to.
            // we will validate the work requests in each list accordingly.
            switch on wrOwner{
                when '00G0Z000004yRgHUAU'{FoOwnerChgs.add(each); }
                                                             
                when else{
                    // Work request was set to a status there is no special validation for
                    continue;
                }
            }
        }
        
        if(!FoOwnerChgs.isEmpty()) wrFoOwnerValidation(FoOwnerChgs, wrRecordTypes, wrErrorsMap);
                // add any applicable errors to the Trigger WR using the map we populated in the previous methods.
        for(EDiscovery_WorkRequest__c updatedWR : triggerNew){
            system.debug('Putting an error on? ' + (wrErrorsMap.get(updatedWR.Id) != null));
            if(wrErrorsMap.get(updatedWR.Id) != null) system.debug(wrErrorsMap.get(updatedWR.Id));
            if(wrErrorsMap.get(updatedWR.Id) != null) updatedWR.addError(wrErrorsMap.get(updatedWR.Id));
        }
    }

    private static void wrCompleteValidation(list<EDiscovery_WorkRequest__c> completedWRs, map<Id, string> wrRecordTypes, map<Id, string> wrErrorsMap, set<string> wrWithUnfinishedTasks){

        // get ids and create a map of owners so we can populate Completed By Division field on Work Request.
        set<string> ownerIDSet = Pulse_Utils.getFieldValueSet(completedWRs, 'OwnerId');
        map<Id, User> ownerMap = new map<Id, User>([select Id, Division from User where Id in : ownerIDSet]);
        // get a list of Work Requests recordtypes that require QCE entries, use the formula field on Work Request
        // to determine if the Work Request fulfills the requirement.

        list<string> CompQceRequired = CompQceRequiredRecordTypes();

        // loop through the list of Work Requests sent and add errors if their id's are not found in the set from the Billable Item list.
        for(EDiscovery_WorkRequest__c each : completedWRs){
            boolean errorFree = true;
            string error = '';
            string recordType = wrRecordTypes.get(each.RecordTypeId);

            if(each.QCE_Entries__c < 1 && CompQceRequired.contains(recordType) && recordtype.startswith('Field')){
                errorFree = addErrorToMap(each.Id, 'This Work Request must have a QCE record associated to this Work Request to be Completed.', wrErrorsMap);


            }
            if(wrWithUnfinishedTasks.contains(each.Id)){

                if(wrErrorsMap.keySet().contains(each.Id)){
                    error = wrErrorsMap.get(each.Id) + ' All WR Tasks Must also be Finished or Cancelled to Complete this WR.';
                  errorFree = addErrorToMap(each.Id, error, wrErrorsMap);
                } else {
                  errorFree = addErrorToMap(each.Id, 'All WR Tasks Must be Finished or Cancelled to Cancel or Complete this WR.', wrErrorsMap);
                }
            }
            if((recordType == 'Project Closeout' || recordType == 'ILM - Project Closeout') && wrNeedsShareVolumePopulated(each)){
                if(wrErrorsMap.keySet().contains(each.Id)){
                    error = wrErrorsMap.get(each.Id) + ' This Work Request also requires a value in the fields in the Share Data Disposition section.';
                  errorFree = addErrorToMap(each.Id, error, wrErrorsMap);
                } else {
                    error = 'Work Request Status cannot be set to \'Complete\' if a value is not set for the fields in the Share Data Disposition section.';
                  errorFree = addErrorToMap(each.Id, error, wrErrorsMap);
                }              
            }
            if(errorFree) populateWRCompletionFields(each, ownerMap, RecordType);
        }
        
    }
    
    // return a set of string Ids from a list of incomplete Tasks. This is used for validating several status that
    // are not allowed if the Tasks are not cancelled or finished.    
    private static set<string>getWRWithUnfinishedTasks(list<EDiscovery_WorkRequest__c> triggerWRs){
        list<EDiscovery_WR_Task__c> incompleteWRTasks = [select Id, Work_Request__c from EDiscovery_WR_Task__c 
                                                          where Work_Request__c in : triggerWRs
                                                          and Status__c not in ('Finished', 'Cancelled')];

        return Pulse_Utils.getFieldValueSet(incompleteWRTasks, 'Work_Request__c');
    }

    private static set<string> getWorkRequestWithPendingTimeEntries(list<EDiscovery_WorkRequest__c> updateWRs){
        list<Time_Entry__c> unapprovedTime = [select Id, Work_Request__c from Time_Entry__c 
                                                          where Work_Request__c in : updateWRs
                                                          and Sta__c in ( 'Transfer Failed', 'Pending Approval')];
                                                          

        return Pulse_Utils.getFieldValueSet(unapprovedTime, 'Work_Request__c');
    }    
    
    // populate the Ops Done Date if it is blank, the Billing Summary Created if it is Field Office, and the Work Request Completed by Division fields
    private static void populateWRCompletionFields(EDiscovery_WorkRequest__c wr, map<Id, User> ownerMap, string recordType){
        wr.Ops_Done_Date__c = (wr.Ops_Done_Date__c != null ? wr.Ops_Done_Date__c : Datetime.now());
        if(ownerMap.get(wr.OwnerId) != null) wr.Work_Request_Completed_By_Division__c = ownerMap.get(wr.OwnerId).Division;
        if(recordType.startsWith('Field')) wr.Billing_Summary_Created__c = Datetime.now();
    }
    
    private static boolean wrNeedsShareVolumePopulated(EDiscovery_WorkRequest__c wr){
        return (wr.Collection_Share_Volume_Deleted_GB__c == null || wr.Export_Share_Volume_Deleted_GB__c == null || 
               wr.Processing_Share_Volume_Deleted_GB__c == null || wr.FTP_Share_Volume_Deleted_GB__c == null);
    }
    
    private static list<string> UbqQceRequiredRecordTypes(){
        return new list<string>{'Field Office - Copying','Field Office - ESI','Field Office - General',
                                'Field Office - Printing','Field Office - Scanning'};
    }
    
    private static list<string> CompQceRequiredRecordTypes(){
        return new list<string>{'Field BDS Work Request'};
    }
    
    // Update Billing Quantities only requires that the record have an associated QCE. 
    private static void wrUpdateBillingQuantityValidation(list<EDiscovery_WorkRequest__c> ubqWRs, map<Id, string> wrRecordTypes, map<Id, string> wrErrorsMap){
       list<string>UbqQceRequired = UbqQceRequiredRecordTypes();
       for(EDiscovery_WorkRequest__c each : ubqWRs){
            string recordType = wrRecordTypes.get(each.RecordTypeId);
            boolean errorFree = true;
            if(each.QCE_Entries__c < 1 && UbqQceRequired.contains(recordType) && recordtype.startswith('Field')){
                system.debug('qce requirement failed');
                errorFree = false;
                wrErrorsMap.put(each.Id, 'This Work Request must have a QCE record associated to this Work Request to be set to Update Billing Quantites.');
            }
        }
    }
    
    private static void wrUpdateWipValidation(list<EDiscovery_WorkRequest__c> wipWRs){
        for(EDiscovery_WorkRequest__c each : wipWRs){
            each.wip_start_time__c = (each.wip_start_time__c != null ? each.wip_start_time__c : Datetime.now());
        }
    }
    
    private static void wrUpdateReviewedValidation(list<EDiscovery_WorkRequest__c> revWRs){}
    
    //private static void wrUpdateReviewBillingQuantitiesValidation(list<EDiscovery_WorkRequest__c> rbqWRs, map<Id, string> wrRecordTypes){
    //    for(EDiscovery_WorkRequest__c each : rbqWRs){
    //        string recordType = wrRecordTypes.get(each.RecordTypeId);
    //        each.Review_Billing_Time__c = (each.Review_Billing_Time__c != null ? each.Review_Billing_Time__c : Datetime.now());
            // 11-19-18 Case 00027488 no longer update Ops_Done_Date__c for status other than 'Complete'
            //if(each.Ops_Done_Date__c == null && recordtype.startswith('Field'))
              //each.Ops_Done_Date__c = Datetime.now();
    //    }
    //}
    
   private static void wrUpdateReadyForInvoiceValidation(list<EDiscovery_WorkRequest__c> rfiWRs, map<Id, string> wrErrorsMap, 
                                                         map<Id, EDiscovery_WorkRequest__c> oldMap, map<id, string> wrRecordTypes, set<string> wrWithUnfinishedTasks){
        set<string> ownerIDSet = Pulse_Utils.getFieldValueSet(rfiWRs, 'OwnerId');
        map<Id, User> ownerMap = new map<Id, User>([select Id from User where Id in : ownerIDSet]);
        set<string> projIds = Pulse_Utils.getFieldValueSet(rfiWRs, 'Project__c');
        map<Id, EDiscovery_Project__c> projectMap = new map<Id, EDiscovery_Project__c>([select Id, ITAR_Project__c, HIPAA_Project__c, Billing_System__c
                                                                                      from EDiscovery_Project__c where Id in : projIds]);
        system.debug('projectmap');
        system.debug(ProjectMap);
        set<string> wrWithUnapprovedTime = getWorkRequestWithPendingTimeEntries(rfiWRs);
        system.debug(wrWithUnapprovedTime);
        for(EDiscovery_WorkRequest__c each : rfiWRs){ 
            string oldWRStatus = oldMap.get(each.Id).Work_Request_Status__c;
            string recordType = wrRecordTypes.get(each.RecordTypeId);
                        
            boolean errorFree = true; 
            
            system.debug(each.work_request_status__c);
            system.debug(oldwrstatus);
            
            if((each.Work_Request_Status__c == 'Ready for Invoice' && OldWRStatus != 'Complete') && (recordtype.startswith('Field'))){
               system.debug('current work request status is not complete');
               errorFree = false;
               wrErrorsMap.put(each.id, 'Cannot set a WR that is not Completed to Ready for Invoice status!');
            }
            
            if(each.Ops_Done_Date__c == null && recordtype.startswith('Field')){
               system.debug('Ops Done Date is blank');
               errorFree = false;
               wrErrorsMap.put(each.id, 'Cannot set WR to Ready for Invoice if Ops Done Date is blank!');
            }
            
            if(wrWithUnfinishedTasks.contains(each.Id)){
                system.debug('task requirement failed');
                errorFree = false;
                wrErrorsMap.put(each.Id, 'All WR Tasks Must be Finished or Cancelled to Cancel or Complete this WR');
            }
            
            if(wrWithUnapprovedTime.contains(each.Id)){
                system.debug('approved time requirement failed');
                 errorFree = false;
                wrErrorsMap.put(each.Id, 'Cannot set a WR to RFI if there are any non-approved or non-transferred time entries');
            }
            
            if(errorFree) populateWRReadyForInvoiceFields(each, ownerMap, projectMap, RecordType);
        }    
    }
    
    private static void populateWRReadyForInvoiceFields(EDiscovery_WorkRequest__c wr, map<Id, User> ownerMap, map<Id, EDiscovery_Project__c> ProjectMap, string recordType){
        wr.Work_Request_Status__c = 'Ready for Invoice';
        wr.Ready_for_Invoice__c = Datetime.now();
        
        list<queueSobject> ESIqueues = [select QueueId, Queue.DeveloperName from queueSobject Where Queue.DeveloperName in('ESI_Finance', 'US_DTI_Finance')];
               
        if(ProjectMap.get(wr.project__c).Billing_System__c == 'SAP'){
           for (queueSobject q : ESIqueues) {
             if(q.Queue.DeveloperName == 'ESI_FINANCE'){
                             wr.OwnerId = q.QueueId;
             }
           }
        }     
        else{
           for (queueSobject q : ESIqueues) {
             if(q.Queue.DeveloperName == 'US_DTI_Finance'){
                             wr.OwnerId = q.QueueId;
             }
           }
        }         
    }
    
    private static void wrFoOwnerValidation(list<EDiscovery_WorkRequest__c> FoTechSupportWRs, map<Id, string> wrRecordTypes, map<Id, string> wrErrorsMap){
        system.debug('dod I get to owner validation');
        for(EDiscovery_WorkRequest__c each : FoTechSupportWRs){
            each.Date_Added_to_FO_Tech_Support_Queue__c = Datetime.now();
        }
    }
    
    private static void wrSubmittedValidation(list<EDiscovery_WorkRequest__c> subWRs, map<Id, EDiscovery_WorkRequest__c> oldMap, 
                                                map<Id, string> wrRecordTypes, map<Id, string> wrErrorsMap){
        set<string> wrWithMediaAssignments = getMediaAssignmentProof(subWRs);
        set<string> wrWithAppDBAssignments = getAppDBAssignmentProof(subWRs);   
        for(EDiscovery_WorkRequest__c eachWR : subWRs){
            boolean errorFree = true;
            string recordType = wrRecordTypes.get(eachWR.RecordTypeId);
     






            if(eachWR.project__r.Primary_PM__c == '' && eachWR.Work_Request_Status__c == 'Submitted' && eachWR.Project__r.Delivery_Location__c != 'SEA DC' && 
               eachWR.project__r.RecordType.Name != 'Field Office Project'){
               errorFree = false;
               wrErrorsMap.put(eachWR.Id, 'Delivery Location for this WR must be SEA DC to be Submitted.');            
            }
            
            // 11/12/2018 removed DMX - Rel Lite ECA MTH/Release record type from list requiring media record 
            if(recordtype == 'DMX - Prefiltering' || recordtype == 'DMX - Processing' || recordtype == 'DMX - Rel Lite ECA'|| recordtype == 'DMX - Rel Lite ECA w/ Prefiltering' || recordtype == 'Hosting - 3rd Party Load (NA)'){
               // check for media assignments
               if(!wrWithMediaAssignments.contains(string.valueOf(eachWR.Id))){


                  errorFree = false;
                  wrErrorsMap.put(eachWR.Id, 'This WR Type requires at least 1 Media Assignment Record.');
               }   
            }    

            // 04/04/2019 ILM Closeout and Archive Recordtypes require Database Assignments to be Submitted.
            if(recordtype == 'ILM - Project Closeout' || recordtype == 'ILM - Single Database Archive/Deletion'){
               // check for App DB Assignments
               if(!wrWithAppDBAssignments.contains(string.valueOf(eachWR.Id))){
                  errorFree = false;
                  wrErrorsMap.put(eachWR.Id, 'This WR Type requires at least 1 Application Database Assignment Record.');
               }   
            }    
                      
            if(errorFree) populateWRSubmittedFields(eachWR, oldMap.get(eachWR.Id), RecordType);
        }
    }

    // get set of Work Request Ids that have Media Assignments if any.
    private static set<string> getMediaAssignmentProof(list<EDiscovery_WorkRequest__c> subWRs) {
        list<EDiscovery_MediaAssignment__c> assignments = [select WorkRequest__c from EDiscovery_MediaAssignment__c where WorkRequest__c in : subWRs];
        if(assignments.size() > 0){
            return Pulse_Utils.getFieldValueSet(assignments, 'WorkRequest__c');
        } else {
            return new set<string>();
        }
    }

    // get set of Work Request Ids that have Application Database Assignments if any.
    private static set<string> getAppDBAssignmentProof(list<EDiscovery_WorkRequest__c> subWRs) {
        list<Application_Database_Assignments__c> assignments = [select Work_Request__c from Application_Database_Assignments__c where Work_Request__c in : subWRs];
        if(assignments.size() > 0){
            return Pulse_Utils.getFieldValueSet(assignments, 'Work_Request__c');
        } else {
            return new set<string>();
        }
    }

    // method updates error map with the information from the new validation and returns false
    // for the records error status.
    private static boolean addErrorToMap(Id wrId, string error, map<Id, string> wrErrorsMap){
        wrErrorsMap.put(wrId, error);
        return false;
    }
    
    private static void populateWRSubmittedFields(EDiscovery_WorkRequest__c wr, EDiscovery_WorkRequest__c originalWR, string recordType){
        system.debug('populate WR Submitted');
        
        //set 
        List<EDiscovery_WR_Task__c> NSTasks = new List<EDiscovery_WR_Task__c>();
        NSTasks = [SELECT OwnerId FROM EDiscovery_WR_Task__c  WHERE Work_Request__c = :wr.Id AND Status__c = 'Not Started' limit 1];
        for(EDiscovery_WR_Task__c wrt: NSTasks){
          system.debug('NS Task Owner Id = ' + wrt.ownerid);
          system.debug('pm only = ' + wr.pm_only__c);
          if(wr.PM_Only__c <> 'Yes' && originalWR.Work_Request_Status__c == 'Pre-Submission')
            wr.OwnerId = wrt.OwnerId;
            system.debug('after owner assignment = ' + wr.OwnerId);
        }
        
        if(wr.Submitted_Time__c == null)
          wr.Submitted_Time__c = System.now();
    }
    

    private static void createWorkRequestTasks(list<EDiscovery_WorkRequest__c> triggerNew){
    
    //----------------------------------------------------------------------------------------------------------------
        //GETS RECORD TYPE FOR THE Work Request OBJECT
        
        // system.debug('*****     QUERY FOR RECORD TYPE     *****');
        Map<ID,Schema.RecordTypeInfo> rt_Map = EDiscovery_WorkRequest__c.sObjectType.getDescribe().getRecordTypeInfosById();
        String currentRT;
        String currentGeneralWorkRequestType;
        map<Id, EDiscovery_WR_Task__c> mapWrTask = new map<Id, EDiscovery_WR_Task__c>();
        list<WR_Task_Settings__c> wrTaskSettings = new list<WR_Task_Settings__c>();
        list<WR_Task_Settings__c> allTaskSettings = [SELECT Department__c, Record_Type__c, Status__c, Task_Order__c, Task_Type__c, General_Work_Request_Type__c, Priority__c, Task_Record_Type__c FROM WR_Task_Settings__c Order By Record_Type__c, Task_Order__c];
        system.debug(allTaskSettings);
        String deliveryLocation;
        String dept;
        list<EDiscovery_WR_Task__c> tasks = new list<EDiscovery_WR_Task__c>();
        list<Group> ESIqueues = [select Id, DeveloperName from Group where Type = 'Queue'];
        list<Id> wrIdsToUpdate = new list<Id>();
        // this is a list of delivery locations and the default queue per "department"
        list<Pulse_Delivery_Location_Queue__mdt> DL_Queues = [Select Delivery_Location__c, Department__c, Queue_Name__c FROM Pulse_Delivery_Location_Queue__mdt];
        map<string, string> mapSubDept = populateSubDepartmentMap();new map<string, string>();
        list<EDiscovery_WorkRequest__c> wrsToProcess = new list<EDiscovery_WorkRequest__c>();
        string subDept;
        
        list<Work_Request_Instruction__c> WRIs = new list<Work_Request_Instruction__c>();
        list<Pulse_WR_Instruction__mdt> WRInstructions = new list<Pulse_WR_Instruction__mdt>();
        list<Pulse_WR_Instruction__mdt> allWRInstructions = [SELECT WR_Record_Type__c, WR_Instruction__c, Order__c FROM Pulse_WR_Instruction__mdt Order By Order__c];
 
        
        // skip any Monthly User & Storage record types
        set<Id> ClonedIds = new set<Id>();
        map<string, Id> mapClonedWRs = new map<string, Id>();
        for(EDiscovery_WorkRequest__c wr : triggerNew) {        
            currentRT = rt_map.get(wr.recordTypeID).getName();
            if(!currentRT.containsIgnoreCase('Monthly User & Storage') && (!currentRT.containsIgnoreCase('Monthly Auto Stats Collection'))) {
                wrsToProcess.add(wr);
            }  
            if(wr.isClone()) {
                ClonedIds.add(wr.Id);
                mapClonedWRs.put(wr.Work_Request_Cloned_From__c, wr.Id);
            }
        }
        // no SOQL inside this for loop!!    
        for(EDiscovery_WorkRequest__c wr : wrsToProcess) {
            currentRT = rt_map.get(wr.recordTypeID).getName(); 
            deliveryLocation = wr.Delivery_Location__c;
            currentGeneralWorkRequestType = wr.General_Work_Request_Type__c;
            wrTaskSettings = getWRTaskSettings(allTaskSettings, currentRT, currentGeneralWorkRequestType);
            //system.debug(Schema.SObjectType.EDiscovery_WR_Task__c.getRecordTypeInfosByName().get(wrTaskSettings[0].Task_Record_Type__c).getRecordTypeId());
            //system.debug(Schema.SObjectType.EDiscovery_WR_Task__c.getRecordTypeInfosByName().get(wrTaskSettings[0].Record_Type__c).getRecordTypeId());

            if(currentRT == 'ESI - General' ) {
                subDept = wr.General_Work_Request_Type__c;
            } else if(currentRT == 'General'){
                   if(wr.General_Work_Request_Type__c == 'Other (Describe)')
                      subDept = 'Litigation Support';
                   else
                    subDept = wr.General_Work_Request_Type__c;
            } else {
                    subDept = mapSubDept.get(currentRT);
            }            
            wrIdsToUpdate.add(wr.Id);
            for (WR_Task_Settings__c setting : wrTaskSettings) 
            {              
                EDiscovery_WR_Task__c task = new EDiscovery_WR_Task__c();
                task.Task_Type__c = setting.Task_Type__c;
                task.Task_Order__c = setting.Task_Order__c;
                task.Work_Request__c = wr.Id;
                task.Status__c = setting.Status__c;
                task.Due_Date__c = wr.Requested_Time__c;
                system.debug('CKWRTRT: ' + setting.Task_Record_Type__c);
                if(setting.Task_Record_Type__c == null || setting.Task_Record_Type__c == ''){
                    task.RecordTypeId = Schema.SObjectType.EDiscovery_WR_Task__c.getRecordTypeInfosByName().get('Standard').getRecordTypeId();
                }
                else {
                    task.RecordTypeId = Schema.SObjectType.EDiscovery_WR_Task__c.getRecordTypeInfosByName().get(setting.Task_Record_Type__c).getRecordTypeId();
                }
                
                for(Pulse_Delivery_Location_Queue__mdt pdlq : DL_Queues) 
                {
                    //system.debug('pdlq dl and dept  = ' +   pdlq.Delivery_Location__c + pdlq.Department__c + setting.Department__c);              
                    if(pdlq.Department__c == setting.Department__c && pdlq.Delivery_Location__c == deliveryLocation ) {            
                        for (Group q : ESIqueues) {
                            if (q.DeveloperName == pdlq.Queue_Name__c) {
                                task.OwnerId = q.Id;
                                task.Department__c = pdlq.Queue_Name__c;
                                task.Sub_Department__c = pdlq.Queue_Name__c.replace('_', ' ');
                            }
                        }
                    }
                    else if(pdlq.Department__c == setting.Department__c && pdlq.Delivery_Location__c == 'Field Office') {
                        for (Group q : ESIqueues) {
                            if (q.DeveloperName == pdlq.Queue_Name__c) {
                                task.OwnerId = q.Id;
                                task.Department__c = pdlq.Queue_Name__c;
                                task.Sub_Department__c = pdlq.Queue_Name__c.replace('_', ' ');
                            }
                        }
                    
                    }
                }
                
                if(setting.Task_Order__c <= 10) {
                    if(!mapWRTask.containsKey(wr.Id)) {
                        mapWRTask.put(wr.Id, task);
                    }
                }
                tasks.add(task);
            }
            
            //add WR Instructions
            WRInstructions = getWRInstructionMDT(allWRInstructions, currentRT);
            for (Pulse_WR_Instruction__mdt WRI_mdt : WRInstructions) {
                Work_Request_Instruction__c WRI = new Work_Request_Instruction__c();
                WRI.RecordTypeID = Schema.SObjectType.Work_Request_Instruction__c.getRecordTypeInfosByName().get(WRI_mdt.WR_Instruction__c).getRecordTypeId();
                WRI.Instruction_Order__c = WRI_mdt.Order__c;
                WRI.Work_Request__c = wr.Id;

                WRIs.add(WRI);
            }
            
        }
        list<EDiscovery_WorkRequest__c> updateWRs = [select Id from EDiscovery_WorkRequest__c where Id in :wrIdsToUpdate];
        for(EDiscovery_WorkRequest__c wr : updateWRs) {
            if(mapWRTask.ContainsKey(wr.Id)) {                  
                EDiscovery_WR_Task__c task = mapWRTask.get(wr.Id);
                wr.Current_Task_Owner__c = task.Department__c;
                wr.Current_Task__c = task.Task_Type__c;
                wr.Current_Task_Status__c = task.Status__c;
                wr.Sub_Department__c = subDept;
            }
            if(ClonedIds.contains(wr.Id)) {
                wr.Work_Request_Status__c = 'Pre-Submission';
                wr.Submitted_Time__c = null;
                wr.Current_Task_Status__c = 'Not Started';
            }
            update wr;  
        }
        // INSERT WR TASKS 
        if(tasks.size() > 0)
        {
            insert tasks;
        }
        if(WRIs.size() > 0)
        {
            insert WRIs;
        }
    }
    
    private static map<string, string> populateSubDepartmentMap(){
        map<string, string> mapSubDept = new map<string, string>();
    
        for(Pulse_Record_Type_to_Sub_Departments__mdt subDepartment : [SELECT Record_Type__c, Sub_Department__c FROM Pulse_Record_Type_to_Sub_Departments__mdt]) {
            if(!mapSubDept.ContainsKey(subDepartment.Record_Type__c)) {
                mapSubDept.put(subDepartment.Record_Type__c, subDepartment.Sub_Department__c);
            }
        }
        return mapSubDept;
    }
    
    private static list<WR_Task_Settings__c> getWRTaskSettings(list<WR_Task_Settings__c> allTaskSettings, string rt, string generalWRType) {
        list<WR_Task_Settings__c> taskSettings = new list<WR_Task_Settings__c>();
        //system.debug(rt + ' ' + generalWRType);
        for(WR_Task_Settings__c setting : allTaskSettings) {
            if(setting.General_Work_Request_Type__c == generalWRType && setting.Record_Type__c == rt)
                taskSettings.add(setting);
        }
        system.debug('found ' + taskSettings.size());
        return taskSettings;
    }
    
    private static list<Pulse_WR_Instruction__mdt> getWRInstructionMDT(list<Pulse_WR_Instruction__mdt> allWRInstructions, string rt) {
        list<Pulse_WR_Instruction__mdt> WRInstructionsMDT = new list<Pulse_WR_Instruction__mdt>();
        list<String> lstRT;
        
        for(Pulse_WR_Instruction__mdt WRI_MDT : allWRInstructions) {
            lstRT = WRI_MDT.WR_Record_Type__c.split(';');
            for (String RecType: lstRT){
                if(RecType == rt)
                WRInstructionsMDT.add(WRI_MDT);
            }
        }
        
        return WRInstructionsMDT;
    } 
    
    private static void addBillableItems(list<EDiscovery_WorkRequest__c> triggerNew){
        map<Id, string> mRecordType = new map<Id, string>();    
        list<RecordType> RecordTypes = new list<RecordType>(
                [Select Id, SObjectType, Name, IsActive, DeveloperName From RecordType Where SObjectType = 'EDiscovery_WorkRequest__c' And IsActive = true]);
        
        for(RecordType rt : RecordTypes) {
            mRecordType.put(rt.Id, rt.Name);
        }
                
        Map<Id, String> mapOfWRAndRTName = new Map<Id,String>();
        string WRRecordTypes;
        map<string, string> ProjectList = new map<string, string>();
        map<string, string> WRLocations = new map<string, string>();
        
        for(EDiscovery_WorkRequest__c wr : triggerNew) {
            string rTypeName = mRecordType.get(wr.RecordTypeId);
            if(rTypeName != 'Monthly User & Storage' && rTypeName != 'Monthly Auto Stats Collection') {
                mapOfWRAndRTName.put(wr.id, mRecordType.get(wr.RecordTypeId));
                if(WRRecordTypes != null){
                    if(!WRRecordTypes.contains(rTypeName)) WRRecordTypes += ';' + rTypeName;
                }else{
                    WRRecordTypes = mRecordType.get(wr.RecordTypeId);
                }
                ProjectList.put(wr.Project__c, wr.Id);
                if(wr.Delivery_Location__c != null)
                    if(wr.Delivery_Location__c != 'Electronic Discovery - US' && wr.Delivery_Location__c != 'Electronic Discovery - Canada') {
                        if(wr.Delivery_Location__c.startswith('Electronic'))
                            WRLocations.put(wr.Id, mRecordType.get(wr.RecordTypeId));
                }
            }
        }
        string IntlRecordTypes;
        for(string loc : WRLocations.values()) {
            if(IntlRecordTypes != null)
                IntlRecordTypes += ';' + loc;
            else
                IntlRecordTypes = loc;
        }
        list<EDiscovery_PricingItems__c> IntlPricingItems = new list<EDiscovery_PricingItems__c>();
        list<EDiscovery_PricingItems__c> PricingItems = [select Id, Name, BillableItem__c, Unit__c, Resource_Code__c, Material_Code__c, WR_Billable_Types__c, Sort_Order__c From EDiscovery_PricingItems__c Where WR_Billable_Types__c includes (:WRRecordTypes)];    
        list<EDiscovery_BillableItems__c> BillableItems = new list<EDiscovery_BillableItems__c>();
        map<string, EDiscovery_PricingItems__c> pricingItemMap = new map<string, EDiscovery_PricingItems__c>();
        list<string> PINames = new list<string>();    

        if(IntlRecordTypes != null)
            IntlPricingItems = [select Id, Name, BillableItem__c, Unit__c, Resource_Code__c, Material_Code__c, Sort_Order__c From EDiscovery_PricingItems__c Where WR_Intl_Billable_Type__c includes (:IntlRecordTypes)];
        for(EDiscovery_PricingItems__c PI : PricingItems) {
            PINames.add(PI.Name);
            pricingItemMap.put(PI.Name, PI);
        }
        for(EDiscovery_PricingItems__c PI : IntlPricingItems) {
            PINames.add(PI.Name);
            pricingItemMap.put(PI.Name, PI);
        }
        list<EDiscovery_PricingLibrary__c> PLibItems = [select Id,Project__c, WRType__c, Pricing_Item_ID__c From EDiscovery_PricingLibrary__c 
                                                        where Project__c in : ProjectList.keyset() and Pricing_Item_ID__c in :PINames];

        // query plib items from pricing library where Pricing_Item_ID__c = PricingItems.Name
        // loop through plib items to create billable items
        for(EDiscovery_PricingLibrary__c PLib : PLibItems) {
            Decimal order = getOrderNumber(PLib, pricingItemMap);
            EDiscovery_BillableItems__c bi = new EDiscovery_BillableItems__c();
            bi.PricingLibrary__c = PLib.Id;
            bi.WorkRequest__c = ProjectList.get(PLib.Project__c);
            if(pricingItemMap.get(PLib.Pricing_Item_ID__c).ID != null)
               bi.PricingItem__c = pricingItemMap.get(PLib.Pricing_Item_ID__c).ID;            // if a non null order was found on the Pricing Item, populate the field on the Billable Item.

            if(order != null) bi.Sort_Order__c = order;
            BillableItems.add(bi);
            //}
        }
        if(BillableItems.size() > 0)
            insert BillableItems;
    }
    
    // find the sort order necessary for Billable
    private static Decimal getOrderNumber(EDiscovery_PricingLibrary__c PLib, map<string, EDiscovery_PricingItems__c> pricingItemMap){
        if(pricingItemMap.get(PLib.Pricing_Item_ID__c) != null){
            if(pricingItemMap.get(PLib.Pricing_Item_ID__c).Sort_Order__c != null){ 
                return pricingItemMap.get(PLib.Pricing_Item_ID__c).Sort_Order__c;
            }
        }
        
        return null;
    }
    
    private static void sendWorkRequestNotifications(list<EDiscovery_WorkRequest__c> triggerNew, map<Id, EDiscovery_WorkRequest__c> oldMap){
        
        if(!secondRun) {
            system.debug('inside sendworkrequestnotifications');
            system.debug('second run before setting to true' + Secondrun);
            secondRun = true;   
            List<EDiscovery_WorkRequest__c> WR_StatusChanged = new List<EDiscovery_WorkRequest__c>();
            List<Pulse_Delivery_Location_Queue__mdt> DLQs = new List<Pulse_Delivery_Location_Queue__mdt>();
            List<Messaging.SingleEmailMessage> mails =  new List<Messaging.SingleEmailMessage>();
            List<String> DeliveryLocations = new List<String>();
            List<Id> ProjectIds = new List<Id>();
            List<EDiscovery_Project__c> Projects = new List<EDiscovery_Project__c>();
            map<Id,Id> WRProjectMap = new map<Id,Id>();
            Map<ID,Schema.RecordTypeInfo> rt_Map = EDiscovery_WorkRequest__c.sObjectType.getDescribe().getRecordTypeInfosById();
            
            for(EDiscovery_WorkRequest__c wr : triggerNew) {
                if(wr.Work_Request_Status__c != oldMap.get(wr.Id).Work_Request_Status__c) {
                    // check WR values against list of statuses and applicable Record types to determine if the notification
                    // should be sent out.
                    system.debug(' wr record type id = ' + wr.recordtypeid);
                    system.debug('wrstatuscheck = ' + wrStatusCheck(wr.Work_Request_Status__c));
                    system.debug('wrRecordTypeCheck = ' + wrRecordTypeCheck(rt_map.get(WR.recordTypeID).getName()));
                    if(wrStatusCheck(wr.Work_Request_Status__c) && wrRecordTypeCheck(rt_map.get(WR.recordTypeID).getName())) { 
                        system.debug('Do I get here to send notice');
                        WR_StatusChanged.add(wr);
                        DeliveryLocations.add(wr.Delivery_Location__c);
                        WRProjectMap.put(wr.Id, wr.Project__c);
                    }
                }
            }

            if (WR_StatusChanged.size() == 1) {
                system.debug('wr status change size = ' + WR_StatusChanged.size());
                system.debug('WRProjectMap.values = ' + WRProjectMap.values());
                DLQs = [select Delivery_Location__c,Department__c,Queue_Name__c,Email__c from Pulse_Delivery_Location_Queue__mdt WHERE Delivery_Location__c IN :DeliveryLocations];
                Projects = [select id, Delivery_Location__c, Project_Email_Distribution_List_Name__c, Primary_PM_email_address__c, Secondary_PM_email_address__c, Primary_LSS_email_address__c, Alternate_PM_email_address__c from EDiscovery_Project__c WHERE Id IN :WRProjectMap.values()];
                
                for(EDiscovery_WorkRequest__c wr : WR_StatusChanged)  {
            
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    List<String> sendTo = addProjectRecipientsToList(wr, Projects, DLQs);
                    
                    if (sendTo.size() > 0) {
                        system.debug('send to size is > 1');
                        //system.debug('sendto: ' + sendTo);
                        //sendTo.add(UserInfo.getUserEmail());
                        mail.setToAddresses(sendTo);
                        system.debug('mail to is being set to = ' + sendTo);
                        mail.setReplyTo('no-reply@epiqglobal.com');
                        mail.setSenderDisplayName('WR Notifications');
                        mail.setSubject(wr.Project_Code__c + '|' + wr.WorkRequest__c + ': Status has been changed to ' + wr.Work_Request_Status__c);
                        String body = 'This email is to notify you that the Status has changed to ' + wr.Work_Request_Status__c + ' for ' + '<a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+wr.id+'">'+wr.WorkRequest__c+'</a>' + '<br/><br/>Project: ' + wr.Project_and_Name__c + '-' + wr.Project_Code__c + '<br/>Headline: ' + wr.Headline__c + '<br/>Requested Time: ' + wr.Requested_Time__c;
                        mail.setHtmlBody(body);
                        mail.saveAsActivity = false;
                        mails.add(mail);
                        Messaging.sendEmail(mails);
                    }
                }                
            }
        }            
    }

    // check that the WRs new status is one that we send notifications for 
    public static boolean wrStatusCheck(string wrStatus) {
        /* User Story 344164 */
        boolean applicableStatus;
        applicableStatus = false;
        List<Pulse_WR_Notification_Statuses__mdt> applicableStatusMap = new List<Pulse_WR_Notification_Statuses__mdt>([select WR_Notification_Status__c
                                                                                                                       from Pulse_WR_Notification_Statuses__mdt
                                                                                                                       where WR_Notification_Status__c = :wrStatus]);
        for(Pulse_WR_Notification_Statuses__mdt pwrns : applicableStatusMap) {
           applicableStatus = true;
        }
        return applicableStatus;
        /* User Story 344164 */
    }

    // check that the WR whose status is being update is one of the 
    // recordtypes that notification is applicable to
    public static boolean wrRecordTypeCheck(string rtName){
        /* User Story 344164 */
        boolean applicableRt;
        applicableRt = false;
        system.debug('checking rt');
        List<Pulse_WR_Record_Type_Names__mdt> applicableRTmap = new List<Pulse_WR_Record_Type_Names__mdt>([select Record_Type_Name__c, Record_Type_Id__c
                                                                                                           from Pulse_WR_Record_Type_Names__mdt
                                                                                                           where Record_Type_Name__c = :rtName]);
        for(Pulse_WR_Record_Type_Names__mdt pwrrt : applicableRTmap) {
           applicableRt = true;
        }
        return applicableRt;
        /* User Story 344164 */
    }

    
    // build recipient list from Work Request Department and Project
    private static list<string> addProjectRecipientsToList(EDiscovery_WorkRequest__c wr, list<EDiscovery_Project__c> Projects, list<Pulse_Delivery_Location_Queue__mdt> DLQs){
        List<String> SubDepts = new List<String>();
        system.debug('project list = ' + Projects.size()); 
        list<string> sendTo = new list<string>();
        // find Sub Departments to send to
        if (wr.Work_Request_Status__c <> 'Ready for Invoice') {
            if (wr.Sub_Department__c <> null) {
                SubDepts = wr.Sub_Department__c.split(';');
                for (String SubDept: SubDepts) {
                    for (Pulse_Delivery_Location_Queue__mdt DLQ : DLQs) {
                        if (SubDept == DLQ.Department__c && wr.Delivery_Location__c == DLQ.Delivery_Location__c) {
                            if (DLQ.Email__c <> null){
                                sendTo.add(DLQ.Email__c); 
                            }
                        }
                    }
                }
            } 
        }
        // find project distribution list to send to.
        for (EDiscovery_Project__c prj : Projects){
            system.debug('inside project distribution section');
            if(prj.Delivery_Location__c != null) {
                if (prj.id == wr.Project__c) { //&& prj.Delivery_Location__c.Contains('Electronic Discovery')){
                    if (prj.Project_Email_Distribution_List_Name__c <> null) {
                        sendTo.add(prj.Project_Email_Distribution_List_Name__c);
                    }
                    if (prj.Primary_PM_email_address__c <> null) {
                        sendTo.add(prj.Primary_PM_email_address__c);
                    }
                    if (prj.Secondary_PM_email_address__c <> null) {
                        sendTo.add(prj.Secondary_PM_email_address__c);
                    }
                    if (prj.Primary_LSS_email_address__c <> null) {
                        sendTo.add(prj.Primary_LSS_email_address__c);
                    }
                    if (prj.Alternate_PM_email_address__c <> null) {
                        sendTo.add(prj.Alternate_PM_email_address__c);
                    }
                }
            }
        }
        return sendTo;
    }
}