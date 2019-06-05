public with sharing class Pulse_PricingItemWrapper {
    
    public EDiscovery_PricingItems__c pricingItem {get; set;}
    public boolean selected {get; set;}
    
    public Pulse_PricingItemWrapper() {
        selected = false;
    }
    
    public Pulse_PricingItemWrapper(EDiscovery_PricingItems__c pi) {
        this();
        pricingItem = pi;
    }

}