/*
	meaningful comment here
*/
trigger Pulse_WorkRequestTrigger on EDiscovery_WorkRequest__c (before insert, after insert, before update, after update) {
    if(trigger.isInsert){
        Pulse_WR_TriggerHandler.handleInsertTrigger(trigger.new, trigger.isBefore);
    }else if(trigger.isUpdate){
        Pulse_WR_TriggerHandler.handleUpdateTrigger(trigger.new, trigger.oldMap, trigger.isBefore);
    }
}