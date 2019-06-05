/*
 *  VF Page:        Pulse_MassUpdateMedia
 *  Controller:     Pulse_MassUpdateMedia
 *  Test Class:     Pulse_MassUpdateMedia_Test
 *  Description:    VF Page for Performing Mass CoC Updates
 *                  to Media records attached to a Pulse Project
 *                  that are not already closed. Users are presented
 *                  with a list of selectable media and then can
 *                  navigate to a page where they can select the
 *                  action to apply to each media selected.
 *
 *      Date:       Developer:          Detail:
 *  --------------------------------------------------------------------------------
 *      04/02/19    JDaru               Newly Created
*/
public class Pulse_MassUpdateMedia {
    public list<selectableMedia> unclosedMedia {get; set;}
    public list<EDiscovery_Media__c> userSelectedMedia {get; set;}
    public list<SelectOption> CoCActionList {get; set;}
    public string CoCAction {get; set;}
    public list<SelectOption> WRSelectionList {get; set;}
    public string selectedWR {get; set;}
    public boolean newRecordSection {get; set;}
    public map<string, string> pageParams {get; set;}
    public Boolean newRecordError {get; set;}
    public string recordError {get; set;}
    public string projIdKey {get; set;}
    public Id projId {get; set;}
    public EDiscovery_Media__c placeHolderMedia {get; set;}
    public list<EDiscovery_MediaAssignment__c> newMediaAssignments {get; set;}

    // constructor for the pages standard controller contains the key used to 
    // obtain the Project passed in and sets up the action selection list and 
    // the selectable media and Work Request Id lists
    public Pulse_MassUpdateMedia(ApexPages.StandardController myController){
        newRecordSection = false;
        pageParams = ApexPages.currentPage().getParameters();
        system.debug(pageParams);
        projIdKey = 'CF00N3100000GErwB_lkid';
        projId = pageParams.get(projIdKey);
        system.debug(projId);
        // populate the picklist for actions
        CoCActionList = new list<SelectOption>{ new SelectOption('Closed', 'Closed'), 
                                                new SelectOption('Take Possession', 'Take Possession'),
                                                new SelectOption('Shipping', 'Shipping')};
        // get the list of media selectable by the user
        getUnclosedMedia();
        // get the WorkRequest Names and Ids to populate a picklist for creating
        // Media Assignment records
        getWRIdlist();
        // create a dummy Media record that will hold the users field choices to be applied to all
        // selected media. This ensures the user is presented with the appropriate choices on each 
        // field they might want to update.
        placeHolderMedia = new EDiscovery_Media__c(ownerId = UserInfo.getUserId(), Custody_Action_Date__c = System.Now());
    }

    // query for all unclosed media associated to the project and create an instance of the selectable record
    // class for each record returned by the query
    public void getUnclosedMedia(){
        unclosedMedia = new list<selectableMedia>();
        for(EDiscovery_Media__c mediaRecord : [select Name, Media_Possession_CoC__c, Evidence_Location__c, Media_Type__c, 
                                                Bin_Number__c, Media_Classification__c, OwnerId, Date_Recieved__c
                                                from EDiscovery_Media__c 
                                                where Project__c = : projId 
                                                and Evidence_Location__c != 'Remote'
                                                and Media_Possession_CoC__c != 'Closed'
                                                order by Evidence_Location__c ASC Nulls Last]){
            unclosedMedia.add(new selectableMedia(mediaRecord));
        }
    }

    // query for Work Requests that have access to the Shipping Tracker functionality and present the user a picklist
    // of Work Request names if 'Shipping' is their chosen action.
    public void getWRIdlist() {
        WRSelectionList = new list<SelectOption>();
        list<string> wrRecordTypes = new list<string>{'ILM - Project Closeout','EO - Shipping','Hosting - Production/Disclosure',
                                                'EH - Shipping', 'EH - Media','Hosting - Production/Disclosure (ESI)',
                                                'Hosting - Disposition Final Export (ESI)','EO - Media','ESI - General',
                                                'Hosting - Export (Image/Native)'};
        system.debug(projId);
        // using the records returned, populate a SelectOption list for the user to interact with
        for(EDiscovery_WorkRequest__c eachWR : [select Id, Name, WR_Record_Type_Formula_Field__c from EDiscovery_WorkRequest__c 
                                                where Project__c = : projId 
                                                AND WR_Record_Type_Formula_Field__c 
                                                IN : wrRecordTypes]) {
            WRSelectionList.add(new SelectOption(eachWR.Id, eachWR.Name));
        }
    }

    //update the placeholder media records Media_Possession_CoC field to a default based on the action chosen.
    public void updateDefaultMediaCoC() {
        system.debug(CoCAction);
        if(CoCAction == 'Take Possession'){ 
            placeHolderMedia.Media_Possession_CoC__c = 'Technician';
        } else {
            placeHolderMedia.Media_Possession_CoC__c = 'Closed';
        }
    }

    // for the 'Shipping' action, create a new Media Assignment with the Chosen Work Request
    // for each selected Media record.
    public pagereference createMediaAssignments() {
        String PageID;
        PageID = ApexPages.currentPage().getParameters().get('id');
        newMediaAssignments = new list<EDiscovery_MediaAssignment__c>();
        for(EDiscovery_Media__c selectedMedia : userSelectedMedia) {
            newMediaAssignments.add(new EDiscovery_MediaAssignment__c(Media__c = selectedMedia.Id, WorkRequest__c = selectedWR));
        }
        if(newMediaAssignments.size() > 0) {
            try {
                insert newMediaAssignments;
                recordError = '';
                newRecordError = false;
                // returnLocation('WorkRequest');
            } catch(DMLException exc) {
                newRecordError = true;
                recordError = Pulse_Utils.trimErrorMessage(exc.getMessage(), 'EXCEPTION: ');
                system.debug(exc.getMessage());
            }
        }
        
        if(newRecordError == false) {
          return returnLocation('selectedWR');
        }
        else{
          PageReference pageRef = new PageReference('/'+PageID);
          pageRef.setRedirect(true);
          return pageRef;
        }    
    }

    // for each record in the list of selectable media that is selected,
    // add that Media record to the list of records that will be used in
    // the selected action.
    public void selectMedia() {
        newRecordError = false;
        recordError = '';
        userSelectedMedia = new list<EDiscovery_Media__c>();
        set<string> locations = new set<string>();
        string selectedLocation;
        for(selectableMedia projectMedia : unclosedMedia){
            if(projectMedia.selected) {
                userSelectedMedia.add(projectMedia.item);
                locations.add(projectMedia.item.Evidence_Location__c);
                if(selectedLocation == null) selectedLocation = projectMedia.item.Evidence_Location__c;
            }
            if(locations.size() > 1) {
                recordError = 'You cannot select media from multiple locations. Please review your choices.';
                newRecordError = true;
            }
        }
        // newRecordSection indicates which pageBlock is currently being displayed
        // true places them in the second stage of the process after they've 
        // selected records. Move over only if newRecordError is still false.
        if(!newRecordError && userSelectedMedia.size() > 0) {
            newRecordSection = true;
            placeHolderMedia.Evidence_Location__c = selectedLocation;
        }
    }

    // return to the media selection step and clear out the selected checkbox
    // also reinitiallize the selected record list to remove any records from it.
    public void updateSelection() {
        userSelectedMedia = new list<EDiscovery_Media__c>();
        for(selectableMedia projectMedia : unclosedMedia){
            projectMedia.selected = false;
        }
        newRecordSection = false;
    }

    // perform the selected action on the chosen media records. Will only affect
    // records valid for the choice. Take only updates the owner on Media not owned
    // by the running user, the other actions only function on Media owned by the current
    // user
    // public void updateSelectedMedia(){
     public pagereference updateSelectedMedia() {
        String PageID;
        PageID = ApexPages.currentPage().getParameters().get('id');
        system.debug('updating media');
        system.debug('CoCAction: ' + CoCAction);
        for(EDiscovery_Media__c selectedMedia : userSelectedMedia){
            if(CoCAction == 'Take Possession') {
                if(selectedMedia.ownerId != UserInfo.getUserId()) {
                    selectedMedia.ownerId = placeHolderMedia.ownerId;
                    selectedMedia.Custody_Action_Date__c = system.now();
                    selectedMedia.Switch_Tech_Reason__c = placeHolderMedia.Switch_Tech_Reason__c;
                    selectedMedia.Custody_Action_Notes__c = placeHolderMedia.Custody_Action_Notes__c;
                }
            } else {
                if(selectedMedia.ownerId == UserInfo.getUserId()) {
                    selectedMedia.Evidence_Location__c = placeHolderMedia.Evidence_Location__c;
                    selectedMedia.Custody_Action_Date__c = system.now();
                    selectedMedia.Media_Possession_CoC__c = placeHolderMedia.Media_Possession_CoC__c;
                    selectedMedia.Bin_Number__c = placeHolderMedia.Bin_Number__c;
                    selectedMedia.Switch_Tech_Reason__c = placeHolderMedia.Switch_Tech_Reason__c;
                    selectedMedia.Custody_Action_Notes__c = placeHolderMedia.Custody_Action_Notes__c;
                }
            }
        }
        try {
            system.debug('trying update');
            update userSelectedMedia;
            recordError = '';
            newRecordError = false;
            system.debug('redirection');
         //   returnLocation('Project');
        } catch(Exception exc) {
            newRecordError = true;
            recordError = Pulse_Utils.trimErrorMessage(exc.getMessage(), 'EXCEPTION: ');
            system.debug(exc.getMessage());
        }
          if(newRecordError == false) {
            return returnLocation('Project');
          }
          else{
             PageReference pageRef = new PageReference('/'+PageID);
             pageRef.setRedirect(true);
             return pageRef; 
          }
    }

    public PageReference cancel(){
        system.debug('running cancel');
        return new System.PageReference('/' + projId);
    }

    // cancel out to the Pulse Project detail page
    public PageReference returnLocation(string objectName){
        system.debug(objectName);
        String sfdcBaseURL = URL.getOrgDomainUrl().toExternalForm();
        System.debug('Base URL: ' + sfdcBaseURL );
        if(objectName == 'Project') {
            system.debug(new System.PageReference(sfdcBaseURL + '/' + projId));
            //return new System.PageReference(sfdcBaseURL + '/' + projId);
            return new System.PageReference('/' + projId);
        } else {
            return new System.PageReference(sfdcBaseURL + '/' + selectedWR);
        }
    }

    // selectable class for unclosed Media related to 
    // the Pulse Project they accessed the page from.
    public class selectableMedia {
        public EDiscovery_Media__c item {get; set;}
        public boolean selected {get; set;}
    
        public selectableMedia(EDiscovery_Media__c mediaRecord){
            item = mediaRecord;
            selected = false;
        }
    }
}