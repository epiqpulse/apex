global class Pulse_InternalWR_Controller {
    
    ApexPages.StandardSetController control;
    
    public Pulse_InternalWR_Controller(ApexPages.StandardSetController controller) 
    {
        control = controller;
    }
    
	webservice static string updateIWRStatus(string iwrId, string newStatus){
    	Internal_Work_Request__c updateIWR = new Internal_Work_Request__c(Id = iwrId, Status__c = newStatus);
    	try{
        	update updateIWR;
        	return 'Success';
    	}catch(Exception exc){
        	string errorMessage = exc.getMessage();
        	string tag = 'FIELD_CUSTOM_VALIDATION_EXCEPTION, ';
            system.debug(errorMessage);
        	if(errorMessage.contains(tag)){
        		errorMessage = Pulse_Utils.trimErrorMessage(errorMessage, tag);
        	}
        	system.debug(exc.getMessage());
        	return errorMessage;
    	}
	}    
}