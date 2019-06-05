public class Pulse_IWRTaskTrigger_Handler {
    
    // populate the default owner on a Internal_WR_Task based on the metadata
    // setting.
    public static void HandleInsert(list<Internal_WR_Task__c> triggerNew) {
        populateDefaultFieldValues(triggerNew);
    }
    
    public static void HandleUpdate(list<Internal_WR_Task__c> triggerNew, map<Id, Internal_WR_Task__c> oldMap) {
        validateStatusChanges(triggerNew, oldMap);
    }

    public static void populateDefaultFieldValues(list<Internal_WR_Task__c> triggerNew) {
        set<string> parentIds = Pulse_Utils.getFieldValueSet(triggerNew, 'Internal_Work_Request__c');
        map<Id, Internal_Work_Request__c> parentIWRs = new map<Id, Internal_Work_Request__c>([select Id, Requested_Time__c, Recordtype.Name from
                                                                                              Internal_Work_Request__c where Id in : parentIds]);
        system.debug(parentIWRs);
        map<string, Id> defaultOwnerMap = getDefaultOwnerMap();
     
        for(Internal_WR_Task__c triggerTask : triggerNew) {
     		Internal_Work_Request__c parent = parentIWRs.get(triggerTask.Internal_Work_Request__c);
            if(defaultOwnerMap.get(triggerTask.Task_Type__c) != null) {
                triggerTask.ownerId = defaultOwnerMap.get(triggerTask.Task_Type__c);
            }
            if(parent.Requested_Time__c != null) triggerTask.Due_Date__c = parent.Requested_Time__c;
        }
        
        
    }
    
    // will hold any validations necessary based on the status of the Task and also handle populating fields when certain
    // status are chosen.
    public static void validateStatusChanges(list<Internal_WR_Task__c> triggerNew, map<Id, Internal_WR_Task__c> oldMap) {
        map<Id, string> validationErrorsMap = new map<Id, string>();
        list<Internal_WR_Task__c> startedTaskList = new list<Internal_WR_Task__c>();
        list<Internal_WR_Task__c> finishedTaskList = new list<Internal_WR_Task__c>();
        system.debug('trigger validate status changes');
        system.debug(triggerNew);
        for(Internal_WR_Task__c internalWRT : triggerNew){
            string iwrtStatus = internalWRT.Status__c;
            // skip records whose status is not changing, we are not interested in those here.
            if(iwrtStatus == oldMap.get(internalWRT.Id).Status__c) continue;
                
            switch on iwrtStatus {
                when 'Started'{  startedTaskList.add(internalWRT); }
                when 'Finished'{ finishedTaskList.add(internalWRT); }         
                when else{
                    // internal work request task was set to a status there is no
                    // special validation or actions for
                    continue;
                }
            }
        }
        
        if(!startedTaskList.isEmpty()) validateStartedTasks(startedTaskList, validationErrorsMap);
        if(!finishedTaskList.isEmpty()) validateFinishedTasks(finishedTaskList, oldMap, validationErrorsMap);
        
        for(Internal_WR_Task__c IWRTask: triggerNew){
            if(validationErrorsMap.keySet().contains(IWRTask.Id)){
                IWRTask.addError(validationErrorsMap.get(IWRTask.Id));
            }
        }
    }
    
    public static map<string, Id> getDefaultOwnerMap() {
        map<string, Id> ownerMap = new map<string, Id>();
        map<string, string> tasktoOwnerName = new map<string, string>();
        list<Group> queueList = new list<Group>();
        list<User> userList = new list<User>();
        system.debug('getting default owner map');
        list<Internal_WR_Task_Setting__mdt> taskSettings = [select Task_Name__c, Default_Owner_Name__c, Default_Task__c, Owner_Type__c 
                                                              from Internal_WR_Task_Setting__mdt where Default_Owner__c = true];
        set<string> userNames = new set<string>();
        set<string> queueNames = new set<string>();
        for(Internal_WR_Task_Setting__mdt eachIWRTSetting : taskSettings) {
            system.debug(eachIWRTSetting);
            tasktoOwnerName.put(eachIWRTSetting.Task_Name__c, eachIWRTSetting.Default_Owner_Name__c);
            if(eachIWRTSetting.Owner_Type__c == 'User') userNames.add(eachIWRTSetting.Default_Owner_Name__c);
            if(eachIWRTSetting.Owner_Type__c == 'Queue') queueNames.add(eachIWRTSetting.Default_Owner_Name__c);
        }
        system.debug(tasktoOwnerName);
        system.debug(userNames);
        system.debug(queueNames);
        if(!queueNames.isEmpty()) queueList = [select Id, Name from Group where Name in : queueNames and Type = 'Queue'];
        if(!userNames.isEmpty()) userList = [select Id, Name from User where Name in : userNames];
        for(Internal_WR_Task_Setting__mdt setting : taskSettings) {
        	if(!queueList.isEmpty() && setting.Owner_Type__c == 'Queue') {
            	for(Group queueRecord : queueList) {
                	if(tasktoOwnerName.get(setting.Task_Name__c) == queueRecord.Name) {
                    	ownerMap.put(setting.Task_Name__c, queueRecord.Id);
                	}
            	}
        	}
        	if(!userList.isEmpty() && setting.Owner_Type__c == 'User') {
            	for(User userRecord : userList){
                	if(tasktoOwnerName.get(setting.Task_Name__c) == userRecord.Name) {
                    	ownerMap.put(setting.Task_Name__c, userRecord.Id);
                	}
            	}
        	}
        }
        system.debug(ownerMap);
        return ownerMap;
    }
    
    // any validation around Started status will go here along with any post validation field updates
    public static void validateStartedTasks(list<Internal_WR_Task__c> startedIWRTasks, map<Id, string> validationErrorsMap) {
        for(Internal_WR_Task__c iwrTask : startedIWRTasks) {
            iwrTask.Task_Started__c = DateTime.Now();
            iwrTask.OwnerId = UserInfo.getUserId();
        }
    }
    
    // any validation around Completed status will go here along with any post validation field updates
    public static void validateFinishedTasks(list<Internal_WR_Task__c> finishedIWRTasks, map<Id, Internal_WR_Task__c> oldMap, map<Id, string> validationErrorsMap) {
        for(Internal_WR_Task__c iwrTask : finishedIWRTasks) {
            if(oldMap.get(iwrTask.Id).Status__c != 'Started'){
                 validationErrorsMap.put(iwrTask.Id, 'You cannot finish a task that has not been started.');
            } else {
            	iwrTask.Task_Completed__c = DateTime.Now();
                iwrTask.Task_Completed_By__c = UserInfo.getUserId();
            }
        } 
    }
	
}