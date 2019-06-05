public class Pulse_WRTask_TriggerHandler {
    public static boolean secondRun = false;
    
    public static void handleUpdateTrigger(list<EDiscovery_WR_Task__c> triggerNew, map<Id, EDiscovery_WR_Task__c> oldMap, boolean isBefore){
        if(isBefore){
            validateStatusChanges(oldMap, triggerNew);
        } else {
            updateCurrentTask(triggerNew);
            finishedTaskActivities(triggerNew, oldMap);
        }
    }

    private static void finishedTaskActivities(list<EDiscovery_WR_Task__c> triggerNew, map<Id, EDiscovery_WR_Task__c> oldMap){
        list<EDiscovery_WR_Task__c> serviceNowUpdateTasks = new list<EDiscovery_WR_Task__c>();
        // get work request Ids from the task list and use that to build a map of work request Id to work request.
        set<string> wrIds = Pulse_Utils.getFieldValueSet(triggerNew, 'Work_Request__c');
        map<Id, EDiscovery_WorkRequest__c> wrMap = new map<Id, EDiscovery_WorkRequest__c>([select Id, Name, Project__c, Project__r.Primary_PM__c,
                                                                                           Requested_Time__c, RecordType.Name 
                                                                                           from EDiscovery_WorkRequest__c 
                                                                                           where Id in : wrIds]);
        list<EDiscovery_Internal_Task__c> qcFinishedTasks = new list<EDiscovery_Internal_Task__c>();
        for(EDiscovery_WR_Task__c each : triggerNew){
            EDiscovery_WR_Task__c original = oldMap.get(each.Id);
            if(each.Status__c == 'Sent to ServiceNow' && oldmap.get(each.Id).Status__c != each.Status__c){
                serviceNowUpdateTasks.add(each);
            } else if(each.Task_Type__c == 'Del - Final Management QC' && each.Status__c == 'Finished' && original.Status__c != each.Status__c){
                EDiscovery_WorkRequest__c wr = wrMap.get(each.Work_Request__c);
                qcFinishedTasks.add(new EDiscovery_Internal_Task__c(
                                        IT_Pulse_Project__c = wr.Project__c,
                                        OwnerId = wr.Project__r.Primary_PM__c,
                                        Requested_Time__c = wr.Requested_Time__c,
                                        IT_Headline__c = 'Deliverable QC of ' + wr.Name,
                                        IT_Status__c = 'Submitted',
                                        Task_Type__c = 'Deliverable QC',
                                        Instructions__c = 'Deliverable QC of \n' + wr.Name + ' \nCompleted on \n ' + each.Date_Finished__c));
            }
        }
        if(serviceNowUpdateTasks.size() > 0) Pulse_WRTask_EmailBuilder.ILMTaskUpdateNotifications(serviceNowUpdateTasks);
        if(qcFinishedTasks.size() > 0) insert qcFinishedTasks;
    }
    
    private static void updateCurrentTask(list<EDiscovery_WR_Task__c> triggerNew){
        list<EDiscovery_WorkRequest__c> wrToUpdate = new list<EDiscovery_WorkRequest__c>();
        // build a map of Queu Id and Name
        map<string, string> queueMap = GetQueueMap();
        // get the Work Request Ids from the trigger context and query the Work Requests and
        // all tasks associated to the Work Requests
        set<string> wrIds = Pulse_Utils.getFieldValueSet(triggerNew, 'Work_Request__c');
        list<EDiscovery_WorkRequest__c> wrList = [Select Id, OwnerId, Current_Task__c, ESI_Available__c,
                                                  Current_Task_Status__c, Current_Task_Owner__c
                                                  from EDiscovery_WorkRequest__c 
                                                  where Id in : wrIds];
        list<EDiscovery_WR_Task__c> wrTaskList = [select Id, OwnerId, Task_Order__c, Task_Type__c, 
                                                   Status__c, Date_Assigned__c, Work_Request__c 
                                                   from EDiscovery_WR_Task__c 
                                                   WHERE Work_Request__c in :wrIds 
                                                   and Status__c != 'Finished'
                                                   and Status__c != 'Cancelled'
                                                   order by Task_Order__c];
    	// sort the Work Request tasks into a map with the Work Request Id as key
        map<Id, EDiscovery_WR_Task__c> wrTaskMap = new map<Id, EDiscovery_WR_Task__c>();
        for(EDiscovery_WR_Task__c wrTask : wrTaskList){
            if(wrTaskMap.get(wrTask.Work_Request__c) == null) wrTaskMap.put(wrTask.Work_Request__c, wrTask);
        }
        // get a map of all users that are owners of any associated Task
    	set<string> userIds = Pulse_Utils.getFieldValueSet(wrTaskList, 'OwnerId');
        map<Id, User> userMap = new map<Id, User>([select Name, FirstName, LastName from User where Id in : userIds]);
        // below we loop through the Work Requests and the associated Tasks to update the Current Task information on 
        // the work request
        for(EDiscovery_WorkRequest__c wr : wrList){
            boolean updateNeeded = false;
            EDiscovery_WR_Task__c currentTask;
            User wrTaskOwner;
            if(wrTaskMap.get(wr.Id) == null){ // null in map means all tasks are complete
                if(wr.Current_Task__c != 'All Tasks Finished or Cancelled' || // check that updates are needed
                  	wr.Current_Task_Status__c != 'Finished' ||
                  	wr.Current_Task_Owner__c != ''){
                	wr.Current_Task__c = 'All Tasks Finished or Cancelled'; // update the fields if necessary and update boolean
                    wr.Current_Task_Status__c = 'Finished';
                    wr.Current_Task_Owner__c = '';
                    updateNeeded = true;
                }
            }else{
                currentTask = wrTaskMap.get(wr.Id);
                string taskOwner;
                if(queueMap.get(currentTask.OwnerId) != null){
                    taskOwner = queueMap.get(currentTask.OwnerId);
                } else {
                    wrTaskOwner = userMap.get(currentTask.OwnerId);
                    taskOwner = wrTaskOwner.FirstName + ' ' + wrTaskOwner.LastName;
                }
                if(wr.Current_Task__c != currentTask.Task_Type__c ||
                      wr.Current_Task_Status__c != currentTask.Status__c ||
                      wr.Current_Task_Owner__c != taskOwner){
    
                    wr.Current_Task__c = currentTask.Task_Type__c;
                    wr.Current_Task_Status__c = currentTask.Status__c;
                    wr.Current_Task_Owner__c = taskOwner;
                    // uncomment the following line to update the Owner of the Work Request to the current Tasks owner
                    // wr.OwnerId = currentTask.OwnerId;
                    updateNeeded = true;
                }
            }
            if(updateNeeded) wrToUpdate.add(wr);
        }
        if(!wrToUpdate.isEmpty()) update wrToUpdate;
    }
    
    Private static map<string, string> GetQueueMap(){
        Map<string, string> queueMap = new Map<string, string>();
        
        List<queueSobject> ESIqueues = [select QueueId, Queue.Name from queueSobject];
        
        for (queueSobject q : ESIqueues) {
            if(!queueMap.ContainsKey(q.QueueId))
                queueMap.put(q.QueueId, q.Queue.Name);
        }
        return queueMap;
    }

	private static void validateStatusChanges(map<Id, EDiscovery_WR_Task__c> oldMap, list<EDiscovery_WR_Task__c> triggerNew){
        map<Id, string> wrtRecordTypes = Pulse_Utils.getSObjectRecordTypeMap('EDiscovery_WR_Task__c');
        list<EDiscovery_WR_Task__c> cancelledWRTs = new list<EDiscovery_WR_Task__c>();
        list<EDiscovery_WR_Task__c> finishedWRTs = new list<EDiscovery_WR_Task__c>();
        list<EDiscovery_WR_Task__c> startedWRTs = new list<EDiscovery_WR_Task__c>();
        list<EDiscovery_WR_Task__c> serviceNowWRTs = new list<EDiscovery_WR_Task__c>();
        // get a set of Queue Ids for status change validations
        List<queueSobject> queues = [select QueueId, Queue.Name from queueSobject];
        set<string> queueIds = Pulse_Utils.getFieldValueSet(queues, 'QueueId');
        map<Id, string> wrtErrorsMap = new map<Id, string>();
        for(EDiscovery_WR_Task__c each : triggerNew){
            string wrtStatus = each.Status__c;
            // We're uninterested in work requests that aren't changing status so continue past those.
            if(wrtStatus == oldMap.get(each.Id).Status__c) continue;
            // update the Date Assigned if it is not populated and the task is not owned by a Queue
            boolean ownedByQueue = queueIds.contains(string.valueOf(each.OwnerId));
            each.Date_Assigned__c = (each.Date_Assigned__c == null && !ownedByQueue ? system.now() : each.Date_Assigned__c);
            // add the trigger Work Request Task to lists corresponding to the status they're going to.
            // we will validate the work request task in each list accordingly.
            switch on wrtStatus{
                when 'Started'{startedWRTs.add(each); }
                when 'Cancelled'{cancelledWRTs.add(each); }
                when 'Finished'{finishedWRTs.add(each); }
                when 'Sent to ServiceNow'{serviceNowWRTs.add(each); }
                When else{
                    // Work request Task was set to a status there is no special validation for
                    continue;
                }
            }
        }        

        if(!startedWRTs.isEmpty()) wrtUpdateStartedValidation(startedWRTs, oldMap, wrtErrorsMap);
        if(!cancelledWRTs.isEmpty()) wrtUpdateCancelledValidation(cancelledWRTs, wrtErrorsMap);
        if(!finishedWRTs.isEmpty()) wrtUpdateFinishedValidation(finishedWRTs, oldMap, queueIds, wrtErrorsMap);
        if(!serviceNowWRTs.isEmpty()) wrtUpdateServiceNowValidation(serviceNowWRTs, wrtErrorsMap);
        // add any applicable errors to the Trigger WR using the map we populated in the previous methods.
        for(EDiscovery_WR_Task__c updatedWRT : triggerNew){
            if(wrtErrorsMap.get(updatedWRT.Id) != null) system.debug(wrtErrorsMap.get(updatedWRT.Id));
            if(wrtErrorsMap.get(updatedWRT.Id) != null) updatedWRT.addError(wrtErrorsMap.get(updatedWRT.Id));
        }
    }
    
    private static void wrtUpdateStartedValidation(list<EDiscovery_WR_Task__c> startedWRTs, map<Id, EDiscovery_WR_Task__c> oldMap, map<Id, string> wrtErrorsMap){

        for(EDiscovery_WR_Task__c each : startedWRTs){
            boolean isError = false;
			EDiscovery_WR_Task__c original = oldMap.get(each.Id);            
			if(original.Status__c == 'Cancelled'){
                wrtErrorsMap.put(each.Id, 'Cannot Start a task that has been cancelled!');
                isError = true;
            }
            if(!isError){
                if(original.Status__c == 'Not Started'){
	                each.OwnerId = system.UserInfo.getUserId();                    
                }
                each.Date_Time_Started__c = (each.Date_Time_Started__c == null ? system.now() : each.Date_Time_Started__c);
            }
        }
    }
    
    private static void wrtUpdateCancelledValidation(list<EDiscovery_WR_Task__c> cancelledWRTs, map<Id, string> wrtErrorsMap){}
    
    private static void wrtUpdateFinishedValidation(list<EDiscovery_WR_Task__c> finishedWRTs, map<Id, EDiscovery_WR_Task__c> oldMap, 
                                                    set<string> queueIds, map<Id, string> wrtErrorsMap){

        for(EDiscovery_WR_Task__c each : finishedWRTs){
            boolean isError = false;
			EDiscovery_WR_Task__c original = oldMap.get(each.Id);
            if(original.Status__c != 'Started'){
                isError = true;
                wrtErrorsMap.put(each.Id, 'Cannot Finish a task that has not been started!');
            }
            if(queueIds.contains(string.valueOf(each.OwnerId))){
                isError = true;
                wrtErrorsMap.put(each.Id, 'Cannot Finish a task that is owned by a QUEUE!');
            }
            if(!isError){
                each.Date_Finished__c = (each.Date_Finished__c == null ? system.now() : each.Date_Finished__c);
                each.Task_Completed_By__c = system.UserInfo.getUserId();
            }
        }
    }
    
    private static void wrtUpdateServiceNowValidation(list<EDiscovery_WR_Task__c> serviceNowWRTs, map<Id, string> wrtErrorsMap){
        set<string> wrIds = Pulse_Utils.getFieldValueSet(serviceNowWRTs, 'Work_Request__c');
        list<Application_Database_Assignments__c> appDBAssignments = [select Id, Work_Request__c, Application_Database__c from Application_Database_Assignments__c where Work_Request__c in : wrIds];
        if(appDBAssignments != null && appDBAssignments.size() > 0) wrIds = Pulse_Utils.getFieldValueSet(appDBAssignments, 'Work_Request__c');
        for(EDiscovery_WR_Task__c each : serviceNowWRTs){
            if(appDBAssignments == null || appDBAssignments.size() == 0 || !wrIds.contains(each.Work_Request__c)){ 
                wrtErrorsMap.put(each.Id, 'The Work Request this Task is associated to does not have any Application Database Assignments.');
            }
        }
    }
}