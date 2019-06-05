/*
 	Summary:	
    Insert and Update triggers contain methods for finding and associating Pricing Items to the Project.
	Insert trigger also handles incrementing Project Codes.
*/
trigger Pulse_ProjectTrigger on EDiscovery_Project__c (before insert, after insert, after update) {
	
    if(trigger.isInsert){
		Pulse_Project_TriggerHandler.handleInsertTrigger(trigger.new);
	}
	if(trigger.isUpdate){ 
        Pulse_Project_TriggerHandler.handleUpdateTrigger(trigger.new, trigger.oldMap, trigger.isUpdate);
	}
    
}