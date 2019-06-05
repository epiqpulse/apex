/*-------------------------------------------------------------------------------------------------------
 Class: Pulse_IWRTaskController

  Description:  This IWRT controller handles the First, Previous and Next Buttons on the internal WR Task
  Notes:        Currently the VIEW Button on the Internal_WR_Task object is overwitten with a visualforce page
                Pulse_IWRTaskview (Visualforce page) which this page is usinge this controller.
  Visualforce Page: Pulse_IWRTaskview
  Test Class: Pulse_IWRTaskController_Test
             
    Date            Version         Author              Summary of Changes  
-------------------------------------------------------------------------------------------------------
    2/01/2019        1.0        Darren Davenport          Newly Created

-------------------------------------------------------------------------------------------------------*/

public with sharing class Pulse_IWRTaskController {
    private Internal_WR_Task__c currentRecord;
    public Internal_WR_Task__c iwrTask;
    public String idTask {get; set;}
    private ApexPages.StandardController stdController;
    public Id recordId;
    public PageReference returnPage; 
    public String returnURL;
    public String recordType;
    public String recordTypeName;
    public string urlAddition;
    
    public Pulse_IWRTaskController(ApexPages.StandardController controller) {
        system.debug('iwrt controller');
        stdController = controller;    
        idTask = ApexPages.currentPage().getParameters().get('id');
        system.debug('idtask = ' + idtask);
        
        map<Id, Schema.RecordTypeInfo> rt_map = Schema.getGlobalDescribe().get('Internal_WR_Task__c').getDescribe().getRecordTypeInfosById();
        
        recordType = getNecessaryRecordType();
        system.debug('back from getting necessary record type');
        recordTypeName = rt_map.get(recordType).getName();
        system.debug('recordtypename = ' + recordtypename);
        system.debug('apex page = ' + ApexPages.currentPage().getparameters().get('retURL'));
        returnURL = ApexPages.currentPage().getParameters().get('retURL');
        system.debug('return url = ' + returnURL);
        
        recordId = controller.getrecord().Id;
        map<string, string> pageParams = ApexPages.currentPage().getParameters();
        system.debug(pageParams);
        String internalWRTaskParameterId = 'CF00Ne0000001yO35_lkid';
        String internalWRTaskNameParameterId = 'CF00Ne0000001yO35';         
        String internalworkRequestParameterId = 'CF00N0Z00000HBN5h_lkid';
        String internalworkRequestNameParameterId = 'CF00N0Z00000HBN5h';
        /* String dueDateParameterId = '00N0Z00000H3Adf'; */
        String taskOrderParameterId = '00N0Z00000HBN5s';
        String taskTypeParameterId = '00N0Z00000HBN5w';
        
        if(internalworkRequestParameterId != null && ApexPages.currentPage().getParameters().get('retURL') != null){
            returnPage = new PageReference(ApexPages.currentPage().getParameters().get('retURL'));
            
            String InternalWRName = pageParams.get(internalworkRequestNameParameterId );
            string InternalWRId = pageParams.get(internalworkRequestParameterId);
            String taskOrder = '';
            String taskType = '';
            
            list<Internal_WR_Task__c> maxTaskOrder;
            maxTaskOrder = [SELECT Task_Order__c FROM Internal_WR_Task__c WHERE Internal_Work_Request__c = :InternalWRId ORDER BY Task_Order__c DESC LIMIT 1];
                        
            list<Internal_Work_request__c> parentWR = new list<Internal_Work_Request__c>();
            parentWR.addAll([select Id, Name, RecordType.Name, Requested_Time__c from Internal_Work_Request__c where Id = :InternalWRId]);    
                       
            if(parentWR.size() > 0 ){
                taskType = parentWR[0].RecordType.Name;
            }
            system.debug('here we are...');
            system.debug(InternalWRName);
            system.debug(InternalWRId);
            
            urlAddition = buildURLAdditionString(internalworkRequestParameterId, internalworkRequestNameParameterId, InternalWRName, InternalWRId, taskOrderParameterId, taskOrder, taskTypeParameterId, taskType);
            system.debug('urlAddition: ' + urlAddition);
        }  
    }
    
    //Created a public boolean for to check if exist next or previuos record and for check if we are viewing the first or last record

    public boolean getCheckNext() {
            Internal_WR_Task__c RTActual = [SELECT Name, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE Id = :idTask LIMIT 1];
        List<Internal_WR_Task__c> TaskNext = [SELECT Id, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE task_order__c > :RTActual.task_order__c AND task_order__c != null AND Internal_Work_Request__c =:RTActual.Internal_Work_Request__c];
        if (TaskNext.size() > 0 && RTActual.task_order__c != null){
            return true;
        }
        return false;
    }

    public boolean getCheckPrevious() {
            Internal_WR_Task__c RTActual = [SELECT Name, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE Id = :idTask LIMIT 1];
        List<Internal_WR_Task__c> iWRtaskPrevious = [SELECT Id, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE task_order__c < :RTActual.task_order__c AND task_order__c != null AND Internal_Work_Request__c =:RTActual.Internal_Work_Request__c];
        if (iWRtaskPrevious.size() > 0 && RTActual.task_order__c != null){
            return true;
        }
        return false;
    }

    public boolean getCheckLast() {
            Internal_WR_Task__c RTActual = [SELECT Name, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE Id = :idTask LIMIT 1];
        List<Internal_WR_Task__c> TaskNext = [SELECT Id, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE task_order__c > :RTActual.task_order__c AND task_order__c != null AND Internal_Work_Request__c =:RTActual.Internal_Work_Request__c];
        if (TaskNext.size() == 0 && RTActual.task_order__c != null){
            return true;
        }
        return false;
    }
// End Public boolean checks


//Create "public pagereference" for viewing the next, previous or the first record

    public PageReference doNext(){
            Internal_WR_Task__c RTActual = [SELECT Name, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE Id = :idTask LIMIT 1];
        
            Internal_WR_Task__c TaskNext = [SELECT Id, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE task_order__c > :RTActual.task_order__c AND task_order__c != null AND Internal_Work_Request__c =:RTActual.Internal_Work_Request__c ORDER BY task_order__c ASC LIMIT 1];
  
        PageReference pageRef = new PageReference('/apex/Pulse_IWRTaskView?id=' + TaskNext.id);
        pageRef.setRedirect(true);
        return pageRef; 
    }

    public PageReference doPrevious(){
            Internal_WR_Task__c RTActual = [SELECT Name, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE Id = :idTask LIMIT 1];        

            Internal_WR_Task__c TaskNext = [SELECT Id, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE task_order__c < :RTActual.task_order__c  and task_order__c != null AND Internal_Work_Request__c =:RTActual.Internal_Work_Request__c ORDER BY task_order__c DESC LIMIT 1];
  
        PageReference pageRef = new PageReference('/apex/Pulse_IWRTaskView?id=' + TaskNext.id);
        pageRef.setRedirect(true);
        return pageRef; 
    }

    public PageReference doFirst(){
            Internal_WR_Task__c RTActual = [SELECT Name, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE Id = :idTask LIMIT 1];
            Internal_WR_Task__c TaskNext = [SELECT Id, task_order__c, Internal_Work_Request__c FROM Internal_WR_Task__c WHERE task_order__c != null AND Internal_Work_Request__c =:RTActual.Internal_Work_Request__c ORDER BY task_order__c ASC LIMIT 1];
  
        PageReference pageRef = new PageReference('/apex/Pulse_IWRTaskView?id=' + TaskNext.Id);
        pageRef.setRedirect(true);
        return pageRef; 
    }
    
   public string getNecessaryRecordType(){
        system.debug('Current Page' + ApexPages.currentPage().getParameters().get('RecordType'));
        string rtString = ApexPages.currentPage().getParameters().get('RecordType');

        if(rtString == null){
            system.debug('recordType was null..');
            rtString = Pulse_Utils.getSObjectDefaultRecordType('Internal_WR_Task__c');
        }
        system.debug('returning ' + rtString);
        return rtString;
    }
    
    // build a string containing all the record ids and names necessary to prepopulate during a redirect.
    public string buildURLAdditionString(string internalworkRequestParameterId, string internalworkRequestNameParameterId, string InternalWRName, string InternalWRId, 
                                         String taskOrderParameterId, String taskOrder, String taskTypeParameterId, String taskType){
        urlAddition = '';
        
        if(InternalWRName !=null && InternalWRName !=''){
            urlAddition += '&' + internalworkRequestNameParameterId + '=' + InternalWRName;
        }
        if(InternalWRId !=null && InternalWRId !=''){
            urlAddition += '&' + internalworkRequestParameterId + '=' + InternalWRId;
        }
        if(taskOrder !=null && taskOrder !=''){
            urlAddition += '&' + taskOrderParameterId + '=' + taskOrder;
        }
        if(taskType !=null && taskType !=''){
            urlAddition += '&' + taskTypeParameterId + '=' + taskType;
        }  
        
        system.debug('url addition = ' + urlAddition);
               
        if(urlAddition != '' && !urlAddition.endsWith('&')) urlAddition += '&';
           return urlAddition;     
    }
    
      public PageReference redirect(){ 
        map<Id, string> recordTypeMap = Pulse_Utils.getSObjectRecordTypeMap('Internal_WR_Task__c');
        string redirectURL = buildRedirectURL();
        system.debug(redirectURL);
        return new PageReference(redirectURL);
    }
    
    public string buildRedirectURL(){
        string redirect = '';
        if(recordId != null){
            system.debug('recordId not null this is an edit');
            if(recordType != null){
                system.debug('record type was not null');
                redirect += '/' + recordId + '/e?nooverride=1&RecordType=' + recordType + '&retURL=' + returnURL;
            } else {
                system.debug('record type was null, master access only');
                redirect += '/' + recordId + '/e?nooverride=1&retURL=' + returnURL;
            }
        } 
        else{
              system.debug('record id was null, new record being created');
              system.debug('urladdition = ' + urladdition);
              system.debug('returnurl = ' + returnURL);
              system.debug('record type = ' + recordtype);
              redirect += '/a7F/e?' + urlAddition + 'retURL=' + returnURL + '&RecordType=' + recordType + '&nooverride=1';
        }

        system.debug(redirect);        
        return redirect;
    }

}