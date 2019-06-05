global class Pulse_WR_Workflow_Controller {
    
    ApexPages.StandardSetController setCon;
    
    public Pulse_WR_Workflow_Controller(ApexPages.StandardSetController controller) 
    {
        setCon = controller;
    }
    
    webservice static string updateWRStatus(string wrId, string newStatus){
        EDiscovery_WorkRequest__c updateWR = new EDiscovery_WorkRequest__c(Id=wrId, Work_Request_Status__c = newStatus);
        try{
            update updateWR;
            return 'Success';
        }catch(Exception exc){
            string errorMessage = exc.getMessage();
            string tag = 'FIELD_CUSTOM_VALIDATION_EXCEPTION, ';
            if(errorMessage.contains(tag)){
                errorMessage = Pulse_Utils.trimErrorMessage(errorMessage, tag);
            }
            system.debug(exc.getMessage());
            return errorMessage;
        }
    }

    webservice static string updateWROwner(string wrId, string newOwner){
        EDiscovery_WorkRequest__c wr = [SELECT OwnerId, Work_Request_Status__c, Ready_for_Invoice__c, Project__c FROM EDiscovery_WorkRequest__c WHERE id = :wrId];
        Map<string, string> queueMap = GetQueueMap();
        wr.OwnerId = queueMap.get('Field_Office_Tech_Support');
        system.debug('owner id = ' + wr.ownerId);
        EDiscovery_WorkRequest__c updateWR = new EDiscovery_WorkRequest__c(Id=wrId, OwnerId = wr.OwnerId);
        try{
            update updateWR;
            return 'Success';
        }catch(Exception exc){
            string errorMessage = exc.getMessage();
            string tag = 'FIELD_CUSTOM_VALIDATION_EXCEPTION, ';
            if(errorMessage.contains(tag)){
                integer startIndex = errorMessage.indexOf('FIELD_CUSTOM_VALIDATION_EXCEPTION, ')+ tag.length();
                integer endIndex = errorMessage.indexOf(': []');
                errorMessage = errorMessage.substring(startIndex, endIndex);
            }
            system.debug(exc.getMessage());
            return errorMessage;
        }
    }
       
    webservice static String CancelWR(String wrId)
    {        
        List<EDiscovery_WR_Task__c> wrTasks = getAllWRTasks(wrId);
        
        if(wrTasks.size() > 0) {
            for(EDiscovery_WR_Task__c task :wrTasks) {
                if(task.Status__c <> 'Finished' && task.Status__c <> 'Cancelled') 
                {
                    return ('Cannot Cancel a Work Request unless all WR Tasks are Cancelled or Finished');
                }
            }
        }
        
        EDiscovery_WorkRequest__c wr = [SELECT OwnerId, Work_Request_Status__c, Ready_for_Invoice__c FROM EDiscovery_WorkRequest__c WHERE id = :wrId];
        Map<string, string> queueMap = GetQueueMap();
        
            wr.Work_Request_Status__c = 'Cancelled';
            update wr;
            //wr.OwnerId = queueMap.get('Pulse_Work_Request_Closed');
            //update wr;
        
        return ('Success');
    }
    
    webservice static String TransferToOE(String wrId, String newOwner)
    {        
        List<EDiscovery_WR_Task__c> WrtList = new List<EDiscovery_WR_Task__c>();
        WrtList = [Select id, status__c from EDiscovery_WR_Task__c where Work_Request__c = :wrId];
        
        for(EDiscovery_WR_Task__c task: WrtList) {
            if(task.Status__c == 'Pending' || task.Status__c == 'Started') {
               return ('Cannot Transfer to OE unless all WR Tasks are Cancelled or Finished');
            }else if(task.status__c == 'Not Started') {
                     task.status__c = 'Cancelled';
                     update WrtList;
                  }
        }
        
         EDiscovery_WorkRequest__c wr = [SELECT id, OwnerId, Owner_ID__c, CreatedBy.ID, Related_WR__c, App_Database__c,
                                        Request_Details__c, Destination_Application_Database__c,
                                        User_Story__c, Target_Universe__c, Expected_Output__c, 
                                        Work_Request_Status__c, Ready_for_Invoice__c, Input__c,
                                        Project__c, Headline__c, Requested_Time__c, Platform__c
                                        FROM EDiscovery_WorkRequest__c WHERE (id = :wrid) limit 1];
        if((wr.work_request_status__c <> 'Cancelled') && (wr.Work_Request_Status__c <> 'Complete')){
          // determine if the WR owner is group  or queue transfer will not work if owner is a group or queue        
          
          string OwnerType = Pulse_Utils.getObjectKeyPrefix('Group');
          string curowner = wr.ownerId;   
          
          If(!curowner.StartsWith(OwnerType)){
             string IWRPOC;
             string CreatedByWR;
             IWRPOC = wr.OwnerId;  // This user will be the Point of Contact on the new OE IWR and we need to save this before 
                                   // we update the WR.
          
             // We then change the owner on the WR to close it out but we have captured the Owner before to use later at Point of Contact
             Map<string, string> queueMap = GetQueueMap();
             // wr.OwnerId = queueMap.get('Pulse_Work_Request_Closed');
        
             // wr.Work_Request_Status__c = 'Cancelled';
             // update wr;
                          
             RecordType RTID = [Select Id From RecordType  Where recordtype.name = 'OE - Custom Reporting'];
             
             // create new OE Internal WR 
             Internal_Work_Request__c IWR = New Internal_Work_Request__c();
             IWR.Processing_App_DB__c = wr.App_Database__c;
             IWR.Hosting_App_DB__c = wr.Destination_Application_Database__c;
             IWR.Request_Details__c = wr.Request_Details__c;
             IWR.Input__c = wr.Input__c;
             IWR.Linked_Work_Request__c = wr.Related_WR__c;
             CreatedByWR = wr.id;
             IWR.Created_From_WR__c = wr.id;
             IWR.Point_of_Contact__c = wr.CreatedBy.id;
             IWR.User_Story__c = wr.User_Story__c;

             IWR.Expected_Output__c = wr.Expected_Output__c;  
             IWR.Pulse_Project__c = wr.Project__c;
             IWR.Headline__c = wr.Headline__c;  
             IWR.Requesting_Team__c = 'OE';
             IWR.Region__c = 'NA';
             IWR.Created_By_Transfer__c = 'Yes';
             IWR.Platform__c = wr.Platform__c;
             IWR.Server_Instance__c = 'test';
             IWR.Status__c = 'Submitted';
             IWR.Submitted_Time__c = datetime.now();
             IWR.Requested_Time__c = datetime.now().addDays(1);
             IWR.RecordTypeID = RTID.id;
             IWR.OwnerId = queueMap.get('Ops_Engineering');
             IWR.OwnerId = IWR.OwnerId;
             insert IWR;
             
             // After insert of new OE IWR pull the data again to get the new ID to tie back to the initiating WR
             Internal_Work_Request__c IWR1 = [SELECT id, Linked_Work_Request__c
                                                FROM Internal_Work_Request__c WHERE Created_From_WR__c = :CreatedByWR Limit 1];
       
            // Pull the data of the original WR in order to update with included IWR id
            EDiscovery_WorkRequest__c wr1 = [SELECT id, OwnerId, Owner_ID__c, Related_WR__c, App_Database__c,
                                                Request_Details__c, Destination_Application_Database__c,
                                                User_Story__c, Target_Universe__c, Expected_Output__c, 
                                                Work_Request_Status__c, Ready_for_Invoice__c, Input__c,
                                                Project__c, Headline__c, Requested_Time__c, Platform__c,
                                                Transferred_to_OE_IWR__c, OE_IWR_ID__c
                                                FROM EDiscovery_WorkRequest__c WHERE (id = :wrid and (Work_Request_Status__c <> 'Cancelled' or Work_Request_Status__c <> 'Closed'))];
        
            wr1.OE_Internal_Work_Request__c = IWR1.id;
            wr1.Work_Request_Status__c = 'Cancelled';
            wr1.Owner_ID__c = newOwner;
            wr1.Transferred_to_OE_IWR__c = 'Yes';
            update wr1;
               
            return ('Success');
          }
          else{
            return('The owner of this WR must be a user in order to transfer to OE.  Please change the owner to a user and try again.');
          }  
        }
        else{
          return('Current WR is in a cancelled or complete status and may not be transferred');
        }
    }
    
     
    public pageReference OwnSelectedTasks()
    {
        List<EDiscovery_WR_Task__c> selectedTasks = (List<EDiscovery_WR_Task__c>) setCon.getSelected();
                
        for(EDiscovery_WR_Task__c task : selectedTasks )
        {
            task.OwnerId = userInfo.getUserId();
        }
        return null;
    }
    
    public pageReference StartSelectedTasks()
    {
        List<EDiscovery_WR_Task__c> selectedTasks = (List<EDiscovery_WR_Task__c>) setCon.getSelected();
                
        for(EDiscovery_WR_Task__c task : selectedTasks )
        {
            task.Status__c = 'Started';
        }
        return null;
    }
    
    public pageReference FinishSelectedTasks()
    {
        List<EDiscovery_WR_Task__c> selectedTasks = (List<EDiscovery_WR_Task__c>) setCon.getSelected();
                
        for(EDiscovery_WR_Task__c task : selectedTasks )
        {
            task.Status__c = 'Finished';
        }
        return null;
    }
    
    public PageReference updateTasks()
    {       
        // Call StandardSetController 'save' method to update
        return setCon.save();   
    }
    
   /* webservice static String CompleteWR(String wrId)
    {
        Map<ID,Schema.RecordTypeInfo> rt_Map = EDiscovery_WorkRequest__c.sObjectType.getDescribe().getRecordTypeInfosById();
        String currentRT;
        String deliveryLoc;
        boolean AllTasksCompleted = true;
        
        // get a list of the queues with their queue Id
        Map<string, string> queueMap = GetQueueMap();
        List<EDiscovery_WR_Task__c> wrTasks = getAllWRTasks(wrId);
        List<Pulse_WR_Complete_Queues__c> ownerSettings = new List<Pulse_WR_Complete_Queues__c>();        
        
        EDiscovery_WorkRequest__c wr = [SELECT OwnerId, Work_Request_Status__c, Delivery_Location__c, General_Work_Request_Type__c, RecordTypeId, Submitted_Time__c FROM EDiscovery_WorkRequest__c WHERE id = :wrId];
          
        for(EDiscovery_WR_Task__c task :wrTasks) {
            if(task.Status__c <> 'Finished') {
                AllTasksCompleted = false;
            }
        }
        
        if(AllTasksCompleted == true) {
            currentRT = rt_map.get(wr.recordTypeID).getName(); 
            deliveryLoc = wr.Delivery_Location__c;
            
            ownerSettings = [Select Queue_Name__c from Pulse_WR_Complete_Queues__c WHERE Delivery_Location__c = :deliveryLoc];
            
            // if(wr.Work_Request_Status__c == 'Submitted') {
            for(Pulse_WR_Complete_Queues__c pdlq : ownerSettings) {
                if(queueMap.ContainsKey(pdlq.Queue_Name__c)) {
                    wr.OwnerId = queueMap.get(pdlq.Queue_Name__c);
                    wr.Work_Request_Status__c = 'Complete';
                    wr.Ops_Done_Date__c = System.now();
                }                
            }
            update wr;
            // }
            return ('Success');
        }
        else
           return ('Cannot complete a WR with unfinished tasks!');
    }*/
    
    static List<EDiscovery_WR_Task__c> getAllWRTasks(String wrId)
    {
        List<EDiscovery_WR_Task__c> wrTasks = new List<EDiscovery_WR_Task__c>();
        
        wrTasks = [Select Date_Finished__c, Department__c, Due_Date__c, Status__c, Sub_Department__c, Task_Owner__c, Task_Order__c, Task_Type__c, Work_Request__c, 
                   WR_Type__c, Project_Name__c, Project__c, Delivery_Location__c FROM EDiscovery_WR_Task__c where Work_Request__c = :wrId];
        return wrTasks;
    }
    
    static Map<string, string> GetQueueMap() {
        Map<string, string> queueMap = new Map<string, string>();
        
        List<queueSobject> ESIqueues = [select QueueId, Queue.DeveloperName from queueSobject];
        
        for (queueSobject q : ESIqueues) {
            if(!queueMap.ContainsKey(q.Queue.DeveloperName))
                queueMap.put(q.Queue.DeveloperName, q.QueueId);
        }
        return queueMap;
    }
}