/*
 *	Class:			Pulse_InternalWRTask_Controller
 *
 *	Test:			Pulse_NewInternalWRTask_Test
 *
 *	Description: 	Controller for the overriden New Internal_WR_Task__c button
 *					on the Internal_Work_Request__c layout related list
 * 
 *  -----------------------------------------------------------------------------
 *  Developer           Date        Description
 *  -----------------------------------------------------------------------------
 *  Jerry Daru			2019/02/05	Newly Created
 *
 */
public class Pulse_InternalWRTask_Controller {
    public Internal_WR_Task__c iwrTask {get; set;}
    public map<string, string> pageParameters {get; set;}
    public string taskRecordType {get; set;}
    public string returnPage; 
    public string taskTypeParam;
    public string taskOrderParam;
    public string iwrIdParam;
    public string iwrNameParam;
    public string taskTypeValue;
    public string iwrIdValue;
    public string iwrNameValue;
    
    public Pulse_InternalWRTask_Controller(ApexPages.StandardController myController) {
        system.debug(ApexPages.currentPage().getParameters());
        // set the parameter strings to the field identifiers so they
        // can be plugged into the url constructed later
    	taskTypeParam = '00N0Z00000HBN5w';
        taskOrderParam = '00N0Z00000HBN5s';
        iwrIdParam = 'CF00N0Z00000HBN5h_lkid';
    	iwrNameParam = 'CF00N0Z00000HBN5h';
        // assign pageParameters to a variable for easier access
        // and grab values for the parameters we already have access
        // to.
        pageParameters = ApexPages.currentPage().getParameters();
        returnPage = pageParameters.get('retURL');
        iwrIdValue = (pageParameters.get(iwrIdParam) != null? pageParameters.get(iwrIdParam) : null);
        iwrNameValue = (pageParameters.get(iwrNameParam) != null? pageParameters.get(iwrNameParam) : null);       
        taskRecordType = pageParameters.get('RecordType');
        // use the information we have already to create a basic record.
        iwrTask = new Internal_WR_Task__c(RecordTypeId = Id.valueOf(taskRecordType),
                                         	Internal_Work_Request__c = pageParameters.get(iwrIdParam));
    }
    
    
    // pageReference for the 'Create' button populates fields on the Task and
    // returns the url necessary to move the user to the edit page of their
    // new record with all the expected fields populated.
    public PageReference newTask() {
        string editURL = '/a7F/e?';
        system.debug(iwrTask);
        if(iwrTask.New_Task_Type__c != 'Standard' && iwrTask.New_Task_Type__c != '--None--') {
            iwrTask.Task_Type__c = iwrTask.New_Task_Type__c;
        }
        system.debug(iwrTask);
        // get the additional URL parameters for the
        // Parent lookup field, the Task Type and the Task Order fields
        string urlAddition = getURLAddition();
    	editURL = editURL + urlAddition;
        system.debug(editURL);
        system.debug(pageParameters);
        return new PageReference(editURL);
    }
    
    
    // return the additional URL parameters for the
    // Parent lookup field, the Task Type and the Task Order fields
    public string getURLAddition() {
        string urlAddition = '';
        string newTaskOrder = getNextTaskOrder();
        if(iwrIdValue != null) urlAddition = urlAddition + iwrIdParam + '=' + iwrIdValue + '&';
        if(iwrNameValue != null) urlAddition = urlAddition + iwrNameParam + '=' + iwrNameValue + '&';
        if(iwrTask.Task_Type__c != '' && iwrTask.Task_Type__c != null && iwrTask.Task_Type__c != 'New') urlAddition = urlAddition + taskTypeParam + '=' + iwrTask.Task_Type__c + '&';
        urlAddition = urlAddition + taskOrderParam + '=' + newTaskOrder + '&';
        urlAddition = urlAddition + 'retURL=' + returnPage + '&RecordType=' + taskRecordType + '&nooverride=1';
        return urlAddition;
    }
    
    // query for the highest order task associated to the new tasks
    // parent and return a string 10 higher than that.
    public string getNextTaskOrder() {
        string taskOrder = '';
        if(iwrIdValue != null) {
        	list<Internal_WR_Task__c> lastTask = [select Task_Order__c from Internal_WR_Task__c
                                             		where Internal_Work_Request__c = : iwrIdValue
                                                 	order by Task_Order__c desc nulls last];
            system.debug('did we find any tasks? ' + !lastTask.isEmpty());
            system.debug(lastTask);
            if(!lastTask.isEmpty()) taskOrder = string.valueOf(lastTask[0].Task_Order__c + 10);            
        }
        system.debug(taskOrder + ' for the new tasks order');
        return taskOrder;
    }
    
    // unused required method
	public PageReference redirect() { 
    	return null;
    }

    // return the user to the detail page retrieved from the pageParameters
    public PageReference cancel() {
        return new PageReference(returnPage);
    }
}