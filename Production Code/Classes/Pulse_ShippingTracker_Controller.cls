public class Pulse_ShippingTracker_Controller {
    public list<selectableMedia> mediaAssociations {get; set;}
    public list<EDiscovery_MediaAssignment__c> userChosenMedia {get; set;}
    public list<string> wrRecordTypesWithAccess {get; set;}
    public Boolean newRecordSection {get; set;}
    public Boolean newRecordError {get; set;}
    public string recordError {get; set;}
    public Id wrId {get; set;}
    public string wrName {get; set;}
    public string wrRecordType {get; set;}
    public Id projId {get; set;}
    public string projName {get; set;}
    public string returnURL {get; set;}
    public string wrIdKey {get; set;}
    public string wrNameKey {get; set;}
    public string projIdKey {get; set;}
    public string projNameKey {get; set;}
    public EDiscovery_ShippingTracker__c newShippingTracker {get; set;}
    
    public Pulse_ShippingTracker_Controller(ApexPages.StandardController myController){
        system.debug(ApexPages.currentPage().getParameters());
        newRecordSection = false;
        wrRecordTypesWithAccess = new list<string>{ 'ILM - Project Closeout','EO - Shipping','Hosting - Production/Disclosure','EH - Shipping', 'EH - Media',
                                                    'Hosting - Production/Disclosure (ESI)','Hosting - Disposition Final Export (ESI)',
                                                    'EO - Media','ESI - General','Hosting - Export (Image/Native)'};
        wrIdKey = 'CF00N3100000GEs5s_lkid';
        wrNameKey = 'CF00N3100000GEs5s';
        projIdKey = 'CF00N3100000GErwE_lkid';
        projNameKey = 'CF00N3100000GErwE';
        populateIdentityParameters(wrIdKey, wrNameKey, projIdKey, projNameKey);       
        mediaAssociations = getMedia();
    }

    public void populateIdentityParameters(string wrIdKey, string wrNameKey, string projIdKey, string projNameKey){
        if(ApexPages.currentPage().getParameters().get(wrIdKey) != null){
            // given the work request Id populate the other 4
            wrId = ApexPages.currentPage().getParameters().get(wrIdKey);
            EDiscovery_WorkRequest__c wrRecord = [select Id, Name, Project__c, Project__r.Name, RecordType.Name from EDiscovery_WorkRequest__c where Id = : wrId];
            wrName = wrRecord.Name;
            wrRecordType = wrRecord.RecordType.Name;
            projId = wrRecord.Project__c;
            projName = wrRecord.Project__r.Name;
        } else if(ApexPages.currentPage().getParameters().get(projIdKey) != null){
            // given only the project Id populate the project specific parameters
            projId = ApexPages.currentPage().getParameters().get(projIdKey);
            EDiscovery_Project__c projRecord = [select Id, Name from EDiscovery_Project__c where Id = : projId];
            projName = projRecord.Name;
        }
        returnURL = ApexPages.currentPage().getParameters().get('retURL');        
    }
    
    public list<selectableMedia> getMedia() {
        mediaAssociations = new list<selectableMedia>();
        for(EDiscovery_MediaAssignment__c each : [Select Media__c, Media__r.Name, Media__r.Media_Type__c, Media__r.Serial_Number__c, 
                             Media__r.Media_Description__c, Media__r.Evidence_Location__c, Media__r.Bin_Number__c, Media__r.OwnerId,
                             // all information from the media record is above, WR information used is below.
                             WorkRequest__c, WorkRequest__r.Project__c
                             FROM EDiscovery_MediaAssignment__c 
                             WHERE WorkRequest__c = : wrId
                             AND Media__r.Media_Possession_CoC__c != 'Shipped'
                             AND Media__r.Evidence_Location__c != 'Epiq - Shipped']){
            mediaAssociations.add(new selectableMedia(each));
        }
        return mediaAssociations;
    }
    
    public void createShippingTrackerForMedia() {
        string mediaIdsSelected = '';
        userChosenMedia = new list<EDiscovery_MediaAssignment__c>();
        for(selectableMedia each : mediaAssociations){
            if(each.selected){
                if(mediaIdsSelected != '') mediaIdsSelected += ';';
                mediaIdsSelected += string.valueOf(each.item.Media__c);
                userChosenMedia.add(each.item);
            }
        }
        // create a new Shipping Tracker and associate it with the selected media 
        // records by creating Shipping Tracker Media Assignments through the trigger     
        if(mediaIdsSelected != ''){        
            newShippingTracker = new EDiscovery_ShippingTracker__c(WorkRequest__c = wrId,
                                                                   Project__c = projId, 
                                                                   Media_to_Associate__c = mediaIdsSelected);
            newRecordSection = true;
        }
    }
    
    public void selectNewMedia(){
        getMedia();
        newShippingTracker = new EDiscovery_ShippingTracker__c();
        newRecordSection = false;
    }
    
    public PageReference saveShippingTracker(){
        try{
            insert newShippingTracker;
            recordError = '';
            newRecordError = false;
            return new System.PageReference(returnURL);
        }catch(Exception exc){
            recordError = exc.getMessage();
            newRecordError = true;
            return null;
        }
    }
    
    public PageReference redirect(){
        if(wrRecordType != null && wrRecordTypesWithAccess.contains(wrRecordType)){
            return null;
        } else {
            return new System.PageReference(getNewRecordURL());
        }
    }
    
    public string getNewRecordURL(){
        string url = '/a2U/e?';
        if(projName != null){
            if(url != '/a2u/e?') url += '&';
            url += projNameKey + '=' + projName + '&' + projIdKey + '=' + projId;
        }
        
        if(wrName != null){
            if(url != '/a2u/e?') url += '&';
            url += wrNameKey + '=' + wrName + '&' + wrIdKey + '=' + wrId;
        }
        if(url != '/a2u/e?') url += '&';
        url += 'retURL=%2Fa2U%2Fo&nooverride=1';
            
        return url;
    }
    
    public PageReference cancel() {
        system.debug('cancel' + returnURL);
        return new System.PageReference(returnURL);
    }
    
    public class selectableMedia {
        public EDiscovery_MediaAssignment__c item {get; set;}
        public boolean selected {get; set;}
    
        public selectableMedia(EDiscovery_MediaAssignment__c mediaRecord){
            item = mediaRecord;
            selected = false;
        }
    }
}