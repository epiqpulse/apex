/*
 *	Description:	Trigger handler for Chain_of_Custody_Action__c records before insert. 
 *					Insert handler calculates field on the record based on pre-populated
 *					fields and information from the Media record.
 *		Date			Developer			Summary 
 * ------------------------------------------------------------------------------------
 * 		3/12/2019		JDaru				Newly Created.
 */
public class Pulse_ChainofCustody_TriggerHandler {

    public static void handleInsertTrigger(list<Chain_of_Custody_Action__c> triggerNew) {
        set<string> mediaIds = Pulse_Utils.getFieldValueSet(triggerNew, 'Media_ID__c');
        map<Id, EDiscovery_Media__c> mediaRecordMap = getMediaRecords(mediaIds);
        for(Chain_of_Custody_Action__c CoCAction : triggerNew) {
            EDiscovery_Media__c mediaRecord = mediaRecordMap.get(CoCAction.Media_ID__c);
            system.debug(mediaRecord);
            CoCAction.CoC_Time__c = mediaRecord.Custody_Action_Date__c.Time();
            // CoCAction.Media_Owner__c = mediaRecord.OwnerId;
            CoCAction.Bin_Number__c = mediaRecord.Bin_Number__c;
            CoCAction.Evidence_Location__c = MediaRecord.Evidence_Location__c;
            CoCAction.Media_Description__c = MediaRecord.Media_Description__c;
            CoCAction.Media_Possession_CoC__c = MediaRecord.Media_Possession_CoC__c;
            system.debug(CoCAction);
        }
    }
    
    public static map<Id, EDiscovery_Media__c> getMediaRecords(set<string> mediaIds) {
        map<Id, EDiscovery_Media__c> mediaMap = new map<Id, EDiscovery_Media__c>([select Id, Evidence_Location__c, Media_Classification__c,
                                                                                   Media_Description__c, Media_Possession_CoC__c, OwnerId,
                                                                                   Bin_Number__c, Custody_Action_Date__c
                                                                                   from EDiscovery_Media__c where Id in : mediaIds]);
        
        return mediaMap;
    }
    
}