public class Pulse_AddMediaController {
    ApexPages.StandardSetController con;
	public string projId {get; set;}
    public string wrId {get; set;}
    public list<Pulse_MediaWrapper> mediaList {get; set;}
   
    public Pulse_AddMediaController(ApexPages.StandardSetController controller) {
        con = controller;  
        // for some reason setting the page size throws an exception 'Modified rows exist in the records collection!' on the unit test
        //con.setPageSize(200);        
        Initialize();        
    }
    
    public void Initialize() {        
        projId = ApexPages.currentPage().getParameters().get('projid');
        EDiscovery_Project__c proj = [Select Id from EDiscovery_Project__c where Name = :projId];
        projId = proj.Id;        
        wrId = ApexPages.currentPage().getParameters().get('wrid');
        mediaList = new list<Pulse_MediaWrapper>();
        list<EDiscovery_Media__c> mediaItems = [Select Id, Name, Client_Label__c, CreatedDate, Drive_Make__c, Media_Type__c, Media_Classification__c, Media_Possession_CoC__c from EDiscovery_Media__c where Project__c = :projId];        
        list<EDiscovery_MediaAssignment__c> mAssigns = [Select Media__c from EDiscovery_MediaAssignment__c where WorkRequest__c = :wrId];
        list<Id> mediaIDs = new list<Id>();        
        
        // get a list of media ids that are already associated with this WR so they aren't added to the available list of media items that can be added to avoid duplicates
        for(EDiscovery_MediaAssignment__c ma : mAssigns) {
            mediaIDs.add(ma.Media__c);
        }
        for(EDiscovery_Media__c media : mediaItems) {
            if(!mediaIDs.contains(media.Id))
            	mediaList.add(new Pulse_MediaWrapper(media));
        }
    }
    public Pagereference checkAll() {
        boolean hasSelected = false;
        
        for(Pulse_MediaWrapper m : mediaList) {
            if(m.selected) hasSelected = true;
        }
        
        for(Pulse_MediaWrapper m : mediaList) {
            if(hasSelected)
                m.selected = false;
            else
                m.selected = true; 
        }
        return null;
    }
    public void AddMediaRecords() {
        list<EDiscovery_MediaAssignment__c> mediaAssignments = new list<EDiscovery_MediaAssignment__c>();
        for(Pulse_MediaWrapper mediaW : mediaList) {
            if(mediaW.selected) {
                EDiscovery_Media__c media = new EDiscovery_Media__c();
                media = mediaW.media;
            	EDiscovery_MediaAssignment__c ma = new EDiscovery_MediaAssignment__c();
               	ma.Media__c = media.Id;
               	ma.WorkRequest__c = wrId;
               	mediaAssignments.add(ma);
            }
        }
        if(mediaAssignments.size() > 0)
            insert mediaAssignments;
        
        if(mediaAssignments.size() == 1)
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Added ' + mediaAssignments.size() + ' new media assignment to the work request'));
        else
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Added ' + mediaAssignments.size() + ' new media assignments to the work request'));
    }
    
    public Pagereference Cancel() {
        pagereference p = new pageReference('/'+wrId);
        return p;
    } 
}