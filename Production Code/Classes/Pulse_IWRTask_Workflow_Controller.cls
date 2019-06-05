Global class Pulse_IWRTask_Workflow_Controller {
    
    ApexPages.StandardSetController setCon;
    
    public Pulse_IWRTask_Workflow_Controller(ApexPages.StandardSetController controller) 
    {
        setCon = controller;
    }    

    webservice static string updateIndividaulIWRTStatus(string iwrtId, string newStatus){
        Internal_WR_Task__c updateIWRT = new Internal_WR_Task__c(Id=iwrtId, Status__c = newStatus);
        try{
            update updateIWRT;
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
    
    public void updateIWRTaskStatus(string newStatus) {
        List<Internal_WR_Task__c> selectedTasks = (List<Internal_WR_Task__c>) setCon.getSelected();
                
        for(Internal_WR_Task__c task : (List<Internal_WR_Task__c>) setCon.getSelected())
        {
            task.Status__c = newStatus;
        }
	}
    
    public PageReference updateTasks()
    {       
        // Call StandardSetController 'save' method to update
        return setCon.save();   
    }
}