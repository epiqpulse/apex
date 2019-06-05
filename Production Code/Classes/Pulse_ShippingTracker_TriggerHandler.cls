public class Pulse_ShippingTracker_TriggerHandler {
	public static string mediaIdString;
    
    public static void handleInsertTrigger(list<EDiscovery_ShippingTracker__c> triggerNew, Boolean isBefore){
        if(isBefore){
            // for single record inserts, if there is a value in the Media_to_Associate__c field
            // store that value in the static mediaIdString field in this class and null it out on
            // the record. That string will be used to create the joiner records between the new
            // shipping tracker and the selected media records.
            if(triggerNew.size() == 1 && triggerNew[0].Media_to_Associate__c != null){
                mediaIdString = triggerNew[0].Media_to_Associate__c;
                triggerNew[0].Media_to_Associate__c = null;
            }
        } else {
            // for single record inserts if a value was stored in the mediaIdString field, use 
            // that value to create the association between shipping tracker and media and null
            // the static class variable
            if(triggerNew.size() == 1 && mediaIdString != null){
                // create the Shipping tracker media assignment records and
                // update the Media Records associated to show show Chain of custody 
                // change
                createAssignmentsAndUpdateMedia(triggerNew);                    

                mediaIdString = null;
            // If there is no value in the MedaiIdString variable, or if there are multiple Shipping Trackers being inserted
            // perform the original Media CoC updates.
            } else {
               // original after insert functionality
               addMediaAndCustodyInformation(triggerNew);
            }
        }
    }
    
    public static void createAssignmentsAndUpdateMedia(list<EDiscovery_ShippingTracker__c> triggerNew){
        list<string> mediaIds = mediaIdString.split(';');
        createMediaAssignmentRecords(mediaIds, triggerNew);
        updateMediaRecords(mediaIds, triggerNew);
    }
    
    // using the Shipping Trigger and the list of media Ids as strings, create the new associated media assignment record.
    public static void createMediaAssignmentRecords(list<string> mediaIds, list<EDiscovery_ShippingTracker__c> triggerNew){
        list<Shipping_Tracker_Media_Assignment__c> newMediaAssignments = new list<Shipping_Tracker_Media_Assignment__c>();
        for(EDiscovery_ShippingTracker__c each : triggerNew){
            for(string media : mediaIds){
                newMediaAssignments.add(new Shipping_Tracker_Media_Assignment__c(Shipping_Tracker__c = each.Id, Media__c = Id.valueOf(media)));
            }
        }
        
        insert newMediaAssignments;
    }
    
    // update the necessary fields for the chain of custody action.
    private static void updateMediaRecords(list<string> mediaIds, list<EDiscovery_ShippingTracker__c> triggerNew){
        list<EDiscovery_Media__c> mediaToUpdate = [Select Id, OwnerId, COC__c, Custody_Action_Date__c, 
                                                   Media_Possession_CoC__c, Evidence_Location__c, Bin_Number__c 
                                                   from EDiscovery_Media__c where Id in : mediaIds];
        list<Chain_of_Custody_Action__c> newCustodyActivity = new list<Chain_of_Custody_Action__c>();
		string userName = UserInfo.getName();
        for(EDiscovery_Media__c each : mediaToUpdate){
            each.Media_Possession_CoC__c = 'Shipped';
            each.Evidence_Location__c = 'Epiq - Shipped'; 
            each.COC__c = 'Shipped out of Epiq: Tracking # ' + triggerNew[0].Tracking_Number__c + 
                '^' + triggerNew[0].Courier__c + '^' + triggerNew[0].Work_Request_Name__c + '^' + 
                userName + '^' + each.Bin_Number__c;
            each.Bin_Number__c = '';
            system.debug('creating new custody action');
            newCustodyActivity.add(new Chain_of_Custody_Action__c(Media_ID__c = each.Id, 
																	Custody_Action_Date__c = Datetime.now(),
                                                                  	Released_By__c = 'N/A', 
                                                                  	Received_By__c = triggerNew[0].Courier__c,
                                                                  	Purpose__c = 'Shipped out of Epiq: \nTracking #: ' +
                                                                 		triggerNew[0].Tracking_Number__c));
        }
        
        update mediaToUpdate;
        insert newCustodyActivity;
    }
    
    // update Media Custody information and create joiner Shipping Tracker Media Assignment
    private static void addMediaAndCustodyInformation(list<EDiscovery_ShippingTracker__c> triggerNew){
        map<string, string> mapST2WR = new map<string, string>();   // map of shipping tracker to work request
        map<Id, string> mediaTrackingNumbers = new map<Id, string>();
        map<Id, string> mapmediaToWR = new map<Id, string>();
        
        list<User> newOwnerList;
        User newOwner;
        string newOwnerString;
        string newOwnerId;
        
        for(EDiscovery_ShippingTracker__c ST: triggerNew) {
            mapST2WR.put(ST.WorkRequest__c, ST.Id);
            mapmediaToWR.put(ST.WorkRequest__c, ST.Tracking_Number__c + '^' + ST.Courier__c);
        }
        
        // list of all media assignments
        map<Id, EDiscovery_WorkRequest__c> wrsToProcess = new map<Id, EDiscovery_WorkRequest__c>([Select Id, Name from EDiscovery_WorkRequest__c 
                                               where RecordType.Name in ('EO - Shipping', 'Hosting - Production/Disclosure', 'EH - Shipping', 'Hosting - Production/Disclosure (ESI)', 'Hosting - Disposition Final Export (ESI)', 'ESI - General', 'Hosting - Export (Image/Native)') 
                                               and Id in: mapST2WR.keyset()]);
                
        list<EDiscovery_MediaAssignment__c> mediaAssignments = [Select Media__c, WorkRequest__c from EDiscovery_MediaAssignment__c where WorkRequest__c in : wrsToProcess.keyset()];
                
        if(mediaAssignments.size() > 0) {
            list<Shipping_Tracker_Media_Assignment__c> TrackerAssignments = new list<Shipping_Tracker_Media_Assignment__c>();
            list<EDiscovery_Media__c> mediaToUpdate = new list<EDiscovery_Media__c>();
            list<Id> mediaIds = new list<Id>(); 
            
            // loop through all shipping trackers and match up the shipping tracker and media record
            for(EDiscovery_MediaAssignment__c MA : mediaAssignments) {
                Shipping_Tracker_Media_Assignment__c TA = new Shipping_Tracker_Media_Assignment__c();
                TA.Shipping_Tracker__c = mapST2WR.get(MA.WorkRequest__c);
                TA.Media__c = MA.Media__c;
                TrackerAssignments.add(TA);
                mediaIds.add(MA.Media__c);
                mediaTrackingNumbers.put(MA.Media__c, mapmediaToWR.get(MA.WorkRequest__c) + '^' + wrsToProcess.get(MA.WorkRequest__c).Name);
            }
            if(TrackerAssignments.size() > 0)
                insert TrackerAssignments;
            
            // we could now update all of the media records to set them as shipped and add a COC action as well   
               
            mediaToUpdate = [Select Id, OwnerId, COC__c, Custody_Action_Date__c, Media_Possession_CoC__c, Evidence_Location__c, Bin_Number__c from EDiscovery_Media__c where Id in : mediaIds];
            
            newOwnerList = [select FirstName,LastName from User where Id =: mediaToUpdate[0].OwnerId];
            if (newOwnerList.size() == 1)
            {
                newOwner = newOwnerList.get(0);
                newOwnerString = newOwner.FirstName + ' ' + newOwner.LastName;
            }
            else
            {
                newOwnerString = '';
            }
	        list<Chain_of_Custody_Action__c> newCustodyActivity = new list<Chain_of_Custody_Action__c>();
            for(EDiscovery_Media__c media : mediaToUpdate) {
                // extract the Courier and Tracking Number from the string
                // stored for this Media records CoC field update. Use 
                // those values for the Chain_of_Custody record.
                string trackingInfo = mediaTrackingNumbers.get(media.Id);
                string trackingNumber = trackingInfo.substringBefore('^');
                trackingInfo = trackingInfo.remove(trackingNumber + '^');
                string courier = trackingInfo.subStringBefore('^');
                media.COC__c = 'Shipped out of Epiq: Tracking # ' + mediaTrackingNumbers.get(media.Id) + '^' + newOwnerString + '^' + media.Bin_Number__c;
                media.Media_Possession_CoC__c = 'Shipped';
                media.Evidence_Location__c = 'Epiq - Shipped';
                media.Bin_Number__c = '';

                system.debug('creating new custody action');
                newCustodyActivity.add(new Chain_of_Custody_Action__c(Media_ID__c = media.Id, 
                                                                     	Custody_Action_Date__c = Datetime.now(),
                                                                       	Released_By__c = 'N/A',
                                                                     	Received_By__c = courier,
                                                                      	Purpose__c = 'Shipped out of Epiq: \nTracking #: ' +
                                                                 		trackingNumber));
            }
            update mediaToUpdate;
            insert newCustodyActivity;
        }
    }
}