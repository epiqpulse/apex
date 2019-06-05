/*
*	Description:	Trigger handler for EDiscovery_Media__ records before insert and update. 
*					Insert populates calculated fields based on other values on the new record.
*					Update validates field values based on Media_Possession_CoC__c.
*		Date			Developer			Summary 
* ------------------------------------------------------------------------------------
* 		3/4/2019		JDaru				Newly Created.
*/
public class Pulse_Media_TriggerHandler {
    
    public static void handleInsertTrigger(list<EDiscovery_Media__c> triggerNew, boolean isBefore) {
        if(isBefore) {
            populateDefaultMediaInformation(triggerNew);
        } else {
            createInitialCustodyAction(triggerNew);
        }
    }
    
    public static void handleUpdateTrigger(list<EDiscovery_Media__c> triggerNew, map<Id, EDiscovery_Media__c> oldMap) {
        validateMediaUpdates(triggerNew, oldMap);
    }
    
    // default Form_Type__c, Media_Created_By__c, Date_Time_Captured__c, and COC__c based on the values
    // in other fields on the new record.
    public static void populateDefaultMediaInformation(list<EDiscovery_Media__c> triggerNew) {
        for(EDiscovery_Media__c mediaRecord : triggerNew) {
            mediaRecord.Form_Type__c = 'Media';
            if(mediaRecord.Computer_Make__c != null) {
                mediaRecord.Form_Type__c = 'Hardware';
            } else if(mediaRecord.UNC_Path__c != null) {
                mediaRecord.Form_Type__c = 'Network'; 
            }	         
            if(mediaRecord.Media_Created_By__c == null) {
                mediaRecord.Media_Created_By__c = userInfo.getFirstName() + ' ' + userInfo.getLastName();
            }
            if(mediaRecord.Date_and_Time_Captured__c == null) {
                mediaRecord.Date_and_Time_Captured__c = DateTime.now().format('yyyy-MM-dd hh:mm a');
            }
            if(mediaRecord.Evidence_Location__c.startsWithIgnoreCase('Epiq')) {
                if(mediaRecord.COC__c == null || !mediaRecord.COC__c.startsWithIgnoreCase('Media record created via')) {
                    mediaRecord.COC__c = 'COC initiated: ' + DateTime.now().format('yyyy-MM-dd hh:mm a');
                }
            }
        }
    }
    
    public static void createInitialCustodyAction(list<EDiscovery_Media__c> triggerNew) {
        list<Chain_of_Custody_Action__c> initialCustodyActions = new list<Chain_of_Custody_Action__c>();
        string owner = UserInfo.getFirstName() + ' ' + UserInfo.getLastName();
        for(EDiscovery_Media__c newMedia : triggerNew){
            string recBy = (!string.isBlank(newMedia.Collector__c)? newMedia.Collector__c : owner);
            if(newMedia.Took_Original__c == 'Yes') {
                initialCustodyActions.add(new Chain_of_Custody_Action__c(Media_ID__c = newMedia.Id, 
                                                                         Custody_Action_Date__c = newMedia.CreatedDate, Purpose__c = 'Acquisition of Item',
                                                                         Released_By__c = 'N/A', Received_By__c = recBy));
            } else {
                initialCustodyActions.add(new Chain_of_Custody_Action__c(Media_ID__c = newMedia.Id, Released_By__c = 'N/A',
                                                                         Custody_Action_Date__c = newMedia.CreatedDate, Received_By__c = recBy, 
                                                                         Purpose__c = 'Acquisition of copy of data. Original left on-site. See target and backup copies for chain of custody.',
                                                                         Courier__c = newMedia.Courier__c, Tracking_Number__c = newMedia.Tracking_Number__c));
            }
        }
        insert initialCustodyActions;
    }
    
    // validate Media field values and updates. If Storage Bin is chosen as location, must include
    // Bin number, and if Media_Possession_CoC__c = 'Switch Technician' and the technician has not changed
    // validate that some other change has been made on the record. 
    public static void validateMediaUpdates(list<EDiscovery_Media__c> triggerNew, map<Id, EDiscovery_Media__c> oldMap) {
        map<Id, string> updateErrorMap = new map<Id, string>();
        
        for(EDiscovery_Media__c mediaRecord : triggerNew) {
            if(mediaRecord.Media_Possession_CoC__c == 'Storage Bin') {
                if(string.isBlank(mediaRecord.Bin_Number__c)) {
                    updateErrorMap.put(mediaRecord.Id, 'Bin Number is required if Storage Bin is selected!');
                } 
            } else if(mediaRecord.Media_Possession_CoC__c == 'Switch Tech') {
                EDiscovery_Media__c oldMedia = oldMap.get(mediaRecord.Id);
                if(mediaRecord.Technician__c == null) {
                    updateErrorMap.put(mediaRecord.Id, 'Technician is required if Switch Tech is selected!');
                } else if(mediaRecord.Technician__c == oldMedia.Technician__c){
                    if(!otherFieldsChanged(triggerNew, oldMap)) {
                        updateErrorMap.put(mediaRecord.Id, 'Cannot save the update with the same technician!');
                    }
                }
            }
            if(updateErrorMap.get(mediaRecord.Id) != null) mediaRecord.addError(updateErrorMap.get(mediaRecord.Id));
        }
    }
    
    private static boolean otherFieldsChanged(list<EDiscovery_Media__c> triggerNew, map<Id, EDiscovery_Media__c> oldMap) {
        boolean rval = false;               
        Map<String, Schema.SObjectField> mapFields = Schema.SObjectType.EDiscovery_Media__c.fields.getMap(); 
        
        for(EDiscovery_Media__c newMedia : triggerNew) {
            EDiscovery_Media__c oldMedia = oldMap.get(newMedia.Id);
            
            for (String str : mapFields.keyset()) {
                if(str == 'Media_Possession_CoC__c') continue;
                if(newMedia.get(str) != oldMedia.get(str)) { 
                    rval = true;
                    break; 
                } 
            }
        }
        
        return rval;
    }
}