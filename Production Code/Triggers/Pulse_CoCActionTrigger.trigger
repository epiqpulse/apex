/*
 *	Description:	Trigger on Chain_of_Custody_Action__c records before insert. 
 *					New record creation trigger populates calculated fields and 
 *					updates parent Media records when necessary.
 *		Date			Developer			Summary 
 * ------------------------------------------------------------------------------------
 * 		3/4/2019		JDaru				Initial.
 */
trigger Pulse_CoCActionTrigger on Chain_of_Custody_Action__c (before insert) {
	Pulse_ChainofCustody_TriggerHandler.handleInsertTrigger(Trigger.New);
}