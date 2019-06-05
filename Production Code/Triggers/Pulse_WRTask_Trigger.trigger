/*
    meaningful comment here
*/
trigger Pulse_WRTask_Trigger on EDiscovery_WR_Task__c (before update, after update) {
    if(trigger.isUpdate){
        Pulse_WRTask_TriggerHandler.handleUpdateTrigger(trigger.new, trigger.oldMap, trigger.isBefore);
    }
}