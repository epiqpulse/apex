trigger Pulse_IWRTask_Trigger on Internal_WR_Task__c (before insert, before update) {
    if(trigger.isInsert) {
        Pulse_IWRTaskTrigger_Handler.HandleInsert(trigger.New);
    } else {
        Pulse_IWRTaskTrigger_Handler.HandleUpdate(trigger.New, trigger.oldMap);
    }
}