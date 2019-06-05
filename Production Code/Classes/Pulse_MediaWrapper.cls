public with sharing class Pulse_MediaWrapper {
	public EDiscovery_Media__c media {get; set;}
    public boolean selected {get; set;}
    
    public Pulse_MediaWrapper() {
        selected = false;
    }
    
    public Pulse_MediaWrapper(EDiscovery_Media__c m) {
        this();
        media = m;
    }

}