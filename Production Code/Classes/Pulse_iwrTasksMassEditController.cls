public class Pulse_iwrTasksMassEditController {
    map<string, string> pageParams;
    Id iwrId;
    list<Internal_WR_Task__c> tasks;
    	 
	public ApexPages.StandardSetController setCon {
        get {
            if(setCon == null) {
                pageParams = ApexPages.currentPage().getParameters();
                string pageId = pageParams.get('id');
                setCon = new ApexPages.StandardSetController(Database.getQueryLocator(
                    [Select Id, Name, OwnerId, Task_Type__c, Task_Order__c, Status__c, Due_Date__c                    
                     FROM Internal_WR_Task__c 
                     WHERE Internal_Work_Request__c = :ApexPages.currentPage().getParameters().get('id')
                     ORDER BY Task_Order__c]));
            }
            setCon.setPageSize(150);
            return setCon;
        }
        set;
    }
    
    public list<Internal_WR_Task__c> getTasks() {
        return (List<Internal_WR_Task__c>) setCon.getRecords();

    }

    public PageReference save() {
        PageReference result = new PageReference('/' + ApexPages.currentPage().getParameters().get('id'));
        if(setCon.save() == null) {            
            ApexPages.Message errMsg = new ApexPages.Message(ApexPages.Severity.FATAL, 'The rule(s) below must be followed');
            ApexPages.addMessage(errMsg);
            return null;
        }
        else    
        	return result;
	}

    public PageReference cancel() {
        PageReference result = new PageReference('/' + ApexPages.currentPage().getParameters().get('id'));
    	return result;
	}

 }