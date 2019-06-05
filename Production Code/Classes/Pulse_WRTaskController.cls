//Controller for WR Task. Handles Next, Previous and First Buttons
//Also pre-populates Task Type and Task Order for EMS Work Requests when New WR Task is created
public with sharing class Pulse_WRTaskController {
    Public Integer size{get;set;}
    private EDiscovery_WR_Task__c currentRecord;
    public EDiscovery_WR_Task__c wrTask;
    public String idTask {get; set;}
    private ApexPages.StandardController stdController;
    public Id recordId;
    public PageReference returnPage; 
    public String returnURL;
    public String recordType;
    public String recordTypeName;
    public string urlAddition;
    
    public Pulse_WRTaskController(ApexPages.StandardController controller) {
        stdController = controller;    
        idTask = ApexPages.currentPage().getParameters().get('id');
        
        map<Id, Schema.RecordTypeInfo> rt_map = Schema.getGlobalDescribe().get('EDiscovery_WR_Task__c').getDescribe().getRecordTypeInfosById();
        
        recordType = getNecessaryRecordType();
        recordTypeName = rt_map.get(recordType).getName();
        returnURL = ApexPages.currentPage().getParameters().get('retURL');
        
        recordId = controller.getrecord().Id;
        
        String workRequestParameterId = 'CF00N0Z00000H3Adq_lkid';
       	String workRequestNameParameterId = 'CF00N0Z00000H3Adq';
        String dueDateParameterId = '00N0Z00000H3Adf';
        String taskOrderParameterId = '00N0Z00000H3Adl';
        String taskTypeParameterId = '00N0Z00000H3Ado';
        
        if (ApexPages.currentPage().getParameters().get(workRequestParameterId) != null && ApexPages.currentPage().getParameters().get('retURL') != null)
        {
        	returnPage = new PageReference(ApexPages.currentPage().getParameters().get('retURL'));
        
            String workRequestId = ApexPages.currentPage().getParameters().get(workRequestParameterId);
        	String workRequestName = ApexPages.currentPage().getParameters().get(workRequestNameParameterId);
        	String dueDate;
        	String taskOrder = '';
        	String taskType = '';

            //EDiscovery_WR_Task__c maxTaskOrder = [SELECT Task_Order__c FROM EDiscovery_WR_Task__c WHERE Work_Request__c = :workRequestId ORDER BY Task_Order__c DESC LIMIT 1];
        	list<EDiscovery_WR_Task__c> maxTaskOrder = [SELECT Task_Order__c FROM EDiscovery_WR_Task__c WHERE Work_Request__c = :workRequestId ORDER BY Task_Order__c DESC LIMIT 1];
       
        	if(workRequestId !=null){
            	EDiscovery_WorkRequest__c wr = [select Id, Name, RecordType.Name, Requested_Time__c from EDiscovery_WorkRequest__c where Id = : workRequestId];
            	if(wr != null){
                	dueDate = wr.Requested_Time__c.format().escapeHtml4();
                    //pre-populate Order and Task Type if not Standard record type and EMS Work Request
        			if(recordTypeName != 'Standard' && wr.RecordType.Name.Startswith('EMS') ){
            			//taskOrder = String.valueof(maxTaskOrder.Task_Order__c + 10);
            			taskOrder = (maxTaskOrder.size() > 0 ? String.valueof(maxTaskOrder[0].Task_Order__c + 10) : '10');
            			taskType = recordTypeName;
        			}
            	}
        	}
        
        	system.debug('buildURLAdditionString: ' + workRequestParameterId + workRequestNameParameterId + workRequestName + workRequestId);
        	urlAddition = buildURLAdditionString(workRequestParameterId, workRequestNameParameterId, workRequestName, workRequestId, dueDateParameterId, dueDate, taskOrderParameterId, taskOrder, taskTypeParameterId, taskType);
        	system.debug('urlAddition: ' + urlAddition);
        }

        
    }
    
    //Created a public boolean for to check if exist next or previuos record and for check if we are viewing the first or last record

    public boolean getCheckNext() {
            EDiscovery_WR_Task__c RTActual = [SELECT Name, task_order__c, work_request__c FROM    EDiscovery_WR_Task__c WHERE Id = :idTask LIMIT 1];
        List<   EDiscovery_WR_Task__c> TaskNext = [SELECT Id, task_order__c, work_request__c FROM EDiscovery_WR_Task__c WHERE task_order__c > :RTActual.task_order__c AND task_order__c != null AND Work_request__c =:RTActual.Work_Request__c];
        if (TaskNext.size() > 0 && RTActual.task_order__c != null){
            return true;
        }
        return false;
    }

    public boolean getCheckPrevious() {
            EDiscovery_WR_Task__c RTActual = [SELECT Name, task_order__c, work_request__c FROM    EDiscovery_WR_Task__c WHERE Id = :idTask LIMIT 1];
        List<   EDiscovery_WR_Task__c> WRtaskPrevious = [SELECT Id, task_order__c, work_request__c FROM     EDiscovery_WR_Task__c WHERE task_order__c < :RTActual.task_order__c AND task_order__c != null AND Work_request__c =:RTActual.Work_Request__c];
        if (WRtaskPrevious.size() > 0 && RTActual.task_order__c != null){
            return true;
        }
        return false;
    }

    public boolean getCheckLast() {
            EDiscovery_WR_Task__c RTActual = [SELECT Name, task_order__c, work_request__c FROM    EDiscovery_WR_Task__c WHERE Id = :idTask LIMIT 1];
        List<EDiscovery_WR_Task__c> TaskNext = [SELECT Id, task_order__c, work_request__c FROM   EDiscovery_WR_Task__c WHERE task_order__c > :RTActual.task_order__c AND task_order__c != null AND Work_request__c =:RTActual.Work_Request__c];
        if (TaskNext.size() == 0 && RTActual.task_order__c != null){
            return true;
        }
        return false;
    }
// End Public boolean checks


//Create "public pagereference" for viewing the next, previous or the first record

    public PageReference doNext(){
            EDiscovery_WR_Task__c RTActual = [SELECT Name, task_order__c, work_request__c FROM    EDiscovery_WR_Task__c WHERE Id = :idTask LIMIT 1];
        
            EDiscovery_WR_Task__c TaskNext = [SELECT Id, task_order__c, work_request__c FROM  EDiscovery_WR_Task__c WHERE task_order__c > :RTActual.task_order__c AND task_order__c != null AND Work_request__c =:RTActual.Work_Request__c ORDER BY task_order__c ASC LIMIT 1];
  
        PageReference pageRef = new PageReference('/apex/Pulse_WRTaskView?id=' + TaskNext.id);
        pageRef.setRedirect(true);
        return pageRef; 
    }

    public PageReference doPrevious(){
            EDiscovery_WR_Task__c RTActual = [SELECT Name, task_order__c, work_request__c FROM    EDiscovery_WR_Task__c WHERE Id = :idTask LIMIT 1];        

            EDiscovery_WR_Task__c TaskNext = [SELECT Id, task_order__c, work_request__c FROM  EDiscovery_WR_Task__c WHERE task_order__c < :RTActual.task_order__c  and task_order__c != null AND Work_request__c =:RTActual.Work_Request__c ORDER BY task_order__c DESC LIMIT 1];
  
        PageReference pageRef = new PageReference('/apex/Pulse_WRTaskView?id=' + TaskNext.id);
        pageRef.setRedirect(true);
        return pageRef; 
    }

    public PageReference doFirst(){
            EDiscovery_WR_Task__c RTActual = [SELECT Name, task_order__c, work_request__c FROM    EDiscovery_WR_Task__c WHERE Id = :idTask LIMIT 1];
            EDiscovery_WR_Task__c TaskNext = [SELECT Id, task_order__c, work_request__c FROM  EDiscovery_WR_Task__c WHERE task_order__c != null AND Work_request__c =:RTActual.Work_Request__c ORDER BY task_order__c ASC LIMIT 1];
  
        PageReference pageRef = new PageReference('/apex/Pulse_WRTaskView?id=' + TaskNext.Id);
        pageRef.setRedirect(true);
        return pageRef; 
    }
    
   public string getNecessaryRecordType(){
        string rtString = ApexPages.currentPage().getParameters().get('RecordType');

        if(rtString == null){
            system.debug('recordType was null..');
            rtString = Pulse_Utils.getSObjectDefaultRecordType('EDiscovery_WR_Task__c');
        }
        system.debug('returning ' + rtString);
        return rtString;
    }
    
    // build a string containing all the record ids and names necessary to prepopulate during a redirect.
    public string buildURLAdditionString(string workRequestParameterId, string workRequestNameParameterId, string workRequestName, string workRequestId, 
                                         string dueDateParameterId, String dueDate, String taskOrderParameterId, String taskOrder, String taskTypeParameterId, String taskType){
    	urlAddition = '';
        
        if(workRequestName !=null && workRequestName !=''){
        	urlAddition += '&' + workRequestNameParameterId + '=' + workRequestName;
        }
        if(workRequestId !=null && workRequestId !=''){
        	urlAddition += '&' + workRequestParameterId + '=' + workRequestId;
        }
        if(dueDate !=null ){
        	urlAddition += '&' + dueDateParameterId + '=' + dueDate;
        }
        if(taskOrder !=null && taskOrder !=''){
        	urlAddition += '&' + taskOrderParameterId + '=' + taskOrder;
        }
        if(taskType !=null && taskType !=''){
        	urlAddition += '&' + taskTypeParameterId + '=' + taskType;
        }  
               
        if(urlAddition != '' && !urlAddition.endsWith('&')) urlAddition += '&';
    	return urlAddition;
    }
    
    public PageReference redirect(){ 
        map<Id, string> recordTypeMap = Pulse_Utils.getSObjectRecordTypeMap('EDiscovery_WR_Task__c');
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
        } else {
            system.debug('record id was null, new record being created');
        	redirect += '/a5x/e?' + urlAddition + 'retURL=' + returnURL + '&RecordType=' + recordType + '&nooverride=1';

        }
		system.debug(redirect);        
        return redirect;
    }

}