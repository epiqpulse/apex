/*-----------------------------------------------------------------------------------------------------
	Class: Pulse_InternalWR_Trigger

	Description:	Trigger for Internal_Work_Request__c
   
    Date            Version         Author              Summary of Changes  
-------------------------------------------------------------------------------------------------------
    1/31/2019	      1.0			Jerry Daru          Newly Created

-------------------------------------------------------------------------------------------------------*/
trigger Pulse_InternalWR_Trigger on Internal_Work_Request__c (before insert, after insert, before update) {
    if(trigger.isInsert) {
	    Pulse_InternalWRTrigger_Handler.HandleInsertTrigger(trigger.New, trigger.isBefore);
    } else {
    	Pulse_InternalWRTrigger_Handler.HandleUpdateTrigger(trigger.New, trigger.oldMap);
    }
}