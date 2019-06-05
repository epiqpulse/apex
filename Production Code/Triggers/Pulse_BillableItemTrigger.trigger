/*
	Insert trigger populates Pricing info from the Pricing library
	Insert and update triggers use information from the Billable Item
		to calculate Sell Amount 
*/

trigger Pulse_BillableItemTrigger on EDiscovery_BillableItems__c (before insert, before update) {
    if(trigger.isInsert){
        Pulse_BillableItem_TriggerHandler.handleInsertTrigger(trigger.New);
    } else if(trigger.isUpdate){
		Pulse_BillableItem_TriggerHandler.handleUpdateTrigger(trigger.New);        
    }
}