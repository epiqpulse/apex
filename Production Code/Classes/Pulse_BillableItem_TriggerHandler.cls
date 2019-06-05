public class Pulse_BillableItem_TriggerHandler {
    public static boolean secondRun = false;
    
    public static void handleInsertTrigger(list<EDiscovery_BillableItems__c> triggerNew){
        getcalculatedquantity(triggerNew);
        getPricingItemID(triggerNew);
    }

   public static void getPricingItemID(list<EDiscovery_BillableItems__c> triggerNew) {
       system.debug('triggerNew: ' + triggerNew);
       List<string> PricingItemIds = new List<string>();
        
       for(EDiscovery_BillableItems__c bi : triggerNew) {
          if(bi.Pricing_Item_ID__c != null) {
              PricingItemIds.add(bi.pricing_Item_Id__c);
          }
       }
       if(pricingItemIds.size() > 0) {
         List<EDiscovery_PricingItems__c> PricingItems = [select ID, name from EDiscovery_PricingItems__c where name in : PricingItemIds];                    
         for(EDiscovery_BillableItems__c bi :triggerNew) {
             for(Ediscovery_PricingItems__c pi :PricingItems) {
                 if(bi.Pricing_Item_Id__c == pi.name)
                     bi.PricingItem__c = pi.Id;
             }    
         }
       }    
   }
   
    public static void handleUpdateTrigger(list<EDiscovery_BillableItems__c> triggerNew) {
        getcalculatedquantity(triggerNew);
        secondRun = !secondRun; // secondRun variable prevents Salesforce order of events from causing this to fire twice.
    }
    
    private static void getcalculatedquantity (list<EDiscovery_BillableItems__c> billableItems){
      for(EDiscovery_BillableItems__c bi :billableItems){
          if(bi.adjusted_quantity__c == 0.0){
             bi.calculated_quantity__c = bi.adjusted_quantity__c;
          }else{
             bi.calculated_quantity__c = bi.quantity_formula__c;   
          }
      }
    } 
}