global class Pulse_WRTask_Workflow_Controller {
    
    ApexPages.StandardSetController setCon;
    
    public Pulse_WRTask_Workflow_Controller(ApexPages.StandardSetController controller) 
    {
        setCon = controller;
    }

    webservice static string updateWRTStatus(string wrtId, string newStatus){
        system.debug('wrt id = ' + wrtid);
        EDiscovery_WR_Task__c updateWRT = new EDiscovery_WR_Task__c(Id=wrtId, Status__c = newStatus);
        system.debug('wrt id after = ' + wrtid);
        try{
            system.debug('before update wrt = ' + updatewrt);
            update updateWRT;
            return 'Success';
        }catch(Exception exc){
            string errorMessage = exc.getMessage();
            string tag = 'FIELD_CUSTOM_VALIDATION_EXCEPTION, ';
            if(errorMessage.contains(tag)){
                trimErrorMessage(errorMessage, tag);
            }
            system.debug(exc.getMessage());
            return errorMessage;
        }
    }
    
    // FIELD_CUSTOM_VALIDATION_EXCEPTION, This was the dummest thing ever. you cant set a wr lookup to a project id.: []'
    
    Public static string trimErrorMessage(string msg, string tag){
        integer startIndex = msg.indexOf(tag)+ tag.length();
        integer endIndex = msg.indexOf(': []');
        return msg.substring(startIndex, endIndex);
    }
    
    

}