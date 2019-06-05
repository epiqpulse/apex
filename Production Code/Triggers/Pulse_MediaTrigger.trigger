/*
 *	Description:	Trigger on EDiscovery_Media__ records before insert and update. 
 *					Routes media records to the appropriate handler method to populate 
 *					calculated field values and perform validation.
 *		Date			Developer			Summary 
 * ------------------------------------------------------------------------------------
 * 		3/4/2019		JDaru				Initial. Refactored two existing triggers into unified
 * 											trigger and created Handler class per our 
 * 											development standards.
 */
trigger Pulse_MediaTrigger on EDiscovery_Media__c (before insert, after insert, before update) {
    
    if(Trigger.isInsert) {
    	Pulse_Media_TriggerHandler.handleInsertTrigger(Trigger.New, Trigger.isBefore);
    }
    
    if(Trigger.isUpdate) {
    	Pulse_Media_TriggerHandler.handleUpdateTrigger(Trigger.New, Trigger.oldMap);
    }
}