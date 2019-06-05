/*
    THIS TRIGGER AUTO CREATES THE WR TASK FOR THE WORK REQUEST.
    IT LOOKS AT THE CUSTOM SETTINGS
    TO DETERMINE WHICH WR TASKS GET CREATED WITH THE WR

    ALSO 

    THIS TRIGGER AUTO POPULATES THE Sub Department Field FOR THE WORK REQUEST.
    IT LOOKS AT THE CUSTOM SETTINGS: "Pulse Record Type to Sub Department"
    TO DETERMINE THE Sub Department based upon Record Type
    
*/

trigger Pulse_WRTaskTrigger on EDiscovery_WorkRequest__c (after insert) {

//----------------------------------------------------------------------------------------------------------------
    //GETS RECORD TYPE FOR THE Work Request OBJECT
    
    // system.debug('*****     QUERY FOR RECORD TYPE     *****');
    
    Map<ID,Schema.RecordTypeInfo> rt_Map = EDiscovery_WorkRequest__c.sObjectType.getDescribe().getRecordTypeInfosById();
    String currentRT;
    String currentGeneralWorkRequestType;
    map<Id, EDiscovery_WR_Task__c> mapWrTask = new map<Id, EDiscovery_WR_Task__c>();
    list<WR_Task_Settings__c> wrTaskSettings = new list<WR_Task_Settings__c>();
    list<WR_Task_Settings__c> allTaskSettings = [SELECT Department__c, Record_Type__c, Status__c, Task_Order__c, Task_Type__c, General_Work_Request_Type__c, Priority__c FROM WR_Task_Settings__c Order By Record_Type__c, Task_Order__c];
    String deliveryLocation;
    String dept;
    list<EDiscovery_WR_Task__c> tasks = new list<EDiscovery_WR_Task__c>();
    list<queueSobject> ESIqueues = [select QueueId, Queue.DeveloperName from queueSobject];
    list<Id> wrIdsToUpdate = new list<Id>();
    // this is a list of delivery locations and the default queue per "department"
    list<Pulse_Delivery_Location_Queues__c> DL_Queues = [Select Delivery_Location__c, Department__c, Queue_Name__c FROM Pulse_Delivery_Location_Queues__c];
    map<string, string> mapSubDept = new map<string, string>();
    list<EDiscovery_WorkRequest__c> wrsToProcess = new list<EDiscovery_WorkRequest__c>();
    string subDept;
    
    private list<WR_Task_Settings__c> getWRTaskSettings(string rt, string generalWRType) {
        list<WR_Task_Settings__c> taskSettings = new list<WR_Task_Settings__c>();
        
        for(WR_Task_Settings__c setting : allTaskSettings) {
            if(setting.General_Work_Request_Type__c == generalWRType && setting.Record_Type__c == rt)
                taskSettings.add(setting);
        }
        
        return taskSettings;
    }

    for(Pulse_Record_Type_to_Sub_Department__c subDept : [SELECT Record_Type__c, Sub_Department__c FROM Pulse_Record_Type_to_Sub_Department__c]) {
        if(!mapSubDept.ContainsKey(subDept.Record_Type__c)) {
            mapSubDept.put(subDept.Record_Type__c, subDept.Sub_Department__c);
        }
    }
    // skip any Monthly User & Storage record types
    set<Id> ClonedIds = new set<Id>();
    map<string, Id> mapClonedWRs = new map<string, Id>();
    for(EDiscovery_WorkRequest__c wr : trigger.new) {        
        currentRT = rt_map.get(wr.recordTypeID).getName();
        system.debug('currentRT: ' + currentRT);
        if(!currentRT.containsIgnoreCase('Monthly User & Storage') && (!currentRT.containsIgnoreCase('Monthly Auto Stats Collection'))) {
            wrsToProcess.add(wr);
            //system.debug('Wr ID: ' + wr.Id);
        }  
        system.debug('%%% wr.IsClone(): ' + wr.isCloned__c);      
        if(wr.isClone()) {
            ClonedIds.add(wr.Id);
            mapClonedWRs.put(wr.Work_Request_Cloned_From__c, wr.Id);
            system.debug('*****$ Cloned from: ' + wr.Work_Request_Cloned_From__c);
        }
    }
    system.debug('wrsToProcess: ' + wrsToProcess); 
    // no SOQL inside this for loop!!    
    for(EDiscovery_WorkRequest__c wr : wrsToProcess) {
        currentRT = rt_map.get(wr.recordTypeID).getName(); 
        deliveryLocation = wr.Delivery_Location__c;
        currentGeneralWorkRequestType = wr.General_Work_Request_Type__c;
        wrTaskSettings = getWRTaskSettings(currentRT, currentGeneralWorkRequestType);
        
        if(currentRT == 'ESI - General' ) {
            subDept = wr.General_Work_Request_Type__c;
        } else if(currentRT == 'General'){
            subDept = 'DTI ' + wr.General_Work_Request_Type__c;
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
            
            for(Pulse_Delivery_Location_Queues__c pdlq : DL_Queues) 
            {
                if(pdlq.Department__c == setting.Department__c && pdlq.Delivery_Location__c == deliveryLocation ) {            
                    for (queueSobject q : ESIqueues) {
                        if (q.Queue.DeveloperName == pdlq.Queue_Name__c) {
                            task.OwnerId = q.QueueId;
                            task.Department__c = pdlq.Queue_Name__c;
                            //task.Sub_Department__c = pdlq.Queue_Name__c;
                        }
                    }
                }
                else if(pdlq.Department__c == setting.Department__c && pdlq.Delivery_Location__c == 'Field Office') {
                    for (queueSobject q : ESIqueues) {
                        if (q.Queue.DeveloperName == pdlq.Queue_Name__c) {
                            task.OwnerId = q.QueueId;
                            task.Department__c = pdlq.Queue_Name__c;
                            //task.Sub_Department__c = pdlq.Queue_Name__c;
                        }
                    }
                
                }
            }
            
            if(setting.Task_Order__c <= 10) {
                //system.debug('WR Task: ' + task);
                if(!mapWRTask.containsKey(wr.Id)) {
                    mapWRTask.put(wr.Id, task);
                    //system.debug('mapWRTask: ' + mapWRTask);
                }
            }
            tasks.add(task);
        }  
    }
    //system.debug('wrIdsToUpdate: ' + wrIdsToUpdate);
    list<EDiscovery_WorkRequest__c> updateWRs = [select Id from EDiscovery_WorkRequest__c where Id in :wrIdsToUpdate];
    //system.debug('mapWRTask: ' + mapWRTask);
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
    system.debug('mapCLonedWRs: ' + mapClonedWRs);
    // if the WR is being cloned then create the tasks from the parent WR else add the default tasks 
    /*if(mapClonedWRs.size() > 0) {
        // mapClonedWRs contains the WR name WR-123456 not the SFDC ID
        list<EDiscovery_WorkRequest__c> clonedWRs = [Select Id from EDiscovery_WorkRequest__c where name in :mapClonedWRs.keyset()];
        system.debug('clonedWRs: ' + clonedWRs);
        // have to create a new list of the IDs like this as all we need are the Ids so we can get the list of tasks for each WR
        list<Id> clonedWRIds = new list<Id>();
        for(EDiscovery_WorkRequest__c clonedWR : clonedWRs) {
            clonedWRIds.add(clonedWR.Id);
        }
        list<EDiscovery_WorkRequest__c> clonedWRsToUpdate = [Select Id, Requested_Time__c, Current_Task_Owner__c, Current_Task__c, Current_Task_Status__c from EDiscovery_WorkRequest__c where Id in :mapClonedWRs.values()];
        system.debug('clonedWRsToUpdate: ' + clonedWRsToUpdate);
        list<EDiscovery_WR_Task__c> clonedTasks = [select Task_Type__c,Task_Order__c,Task_Notes__c,Task_Owner__c,Status__c, OwnerId,Department__c,
                    Date_Finished__c,Date_Time_Started__c,Due_Date__c,Task_Priority__c,Work_Request__c, WRID__c,QueueName__c
                    From EDiscovery_WR_Task__c
                    where Work_Request__c in : clonedWRIds
                    order by Work_Request__c, Task_Order__c];
        system.debug('clonedTasks: ' + clonedTasks);
        // reset all of the tasks so we can create them based off the parent WR            
        tasks.clear();
        integer index = 0;
        for(EDiscovery_WR_Task__c task : clonedTasks) {
            // the map is a cross reference list. the key is the parent name and the value is the newly cloned ID
            // WRID__c is a formula 
            Id newWRId = mapClonedWRs.get(task.WRID__c);            
            
            EDiscovery_WR_Task__c newTask = new EDiscovery_WR_Task__c();
            newTask.Task_Type__c = task.Task_Type__c;
            newTask.Task_Order__c = task.Task_Order__c;
            newTask.Task_Notes__c = task.Task_Notes__c;            
            newTask.OwnerId = task.OwnerId;
            newTask.Status__c = 'Not Started';
            newTask.Task_Priority__c = task.Task_Priority__c;
            newTask.Work_Request__c = newWRId;
            // QueueName is a formula field that translates the queue to the developer name or the user name
            newTask.Department__c = task.QueueName__c;
            
            for(EDiscovery_WorkRequest__c wr : clonedWRsToUpdate) {
                if(wr.Id == newWRId) {                    
                    newTask.Due_Date__c = wr.Requested_Time__c;
                    // the wr is updated only for the 1st task in the list. The tasks are sorted
                    if(index == 0) {
                        wr.Current_Task_Owner__c = newTask.Department__c;
                        wr.Current_Task__c = newTask.Task_Type__c;
                        wr.Current_Task_Status__c = newTask.Status__c;
                        update wr;
                        index += 1;
                    }
                }
            }            
            tasks.add(newTask);
        }
        insert tasks;
    } 
    else {*/
        // INSERT WR TASKS 
        if(tasks.size() > 0)
        {
            insert tasks;
        }
    //}    
}