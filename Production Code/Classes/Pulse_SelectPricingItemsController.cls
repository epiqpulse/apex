public class Pulse_SelectPricingItemsController {
    ApexPages.StandardSetController con;
    
    public Pulse_SelectPricingItemsController(ApexPages.StandardSetController controller) {
        con = controller;
        con.setPageSize(300);
        Initialize();
    }
    
    public list<Pulse_PricingItemWrapper> pricingItems {get; set;}
    public string projId;
    
    public void Initialize() {
        ProjId = ApexPages.currentPage().getParameters().get('projid');
        pricingItems = new list<Pulse_PricingItemWrapper>();
        list<EDiscovery_PricingLibrary__c> projPLIB = [select Id, Pricing_Item_ID__c From EDiscovery_PricingLibrary__c Where Project__c = :projId];
        list<string> PLIB_PricingIds = new list<string>();
        //system.debug('projId: ' + projId);
        for(EDiscovery_PricingLibrary__c plib : projPLIB) {
            if(!PLIB_PricingIds.contains(plib.Pricing_Item_ID__c))
                PLIB_PricingIds.add(plib.Pricing_Item_ID__c);
        }
        
        list<EDiscovery_PricingItems__c> newPricingItems = new list<EDiscovery_PricingItems__c>(
        [ Select Id, Name, BillableItem__c, ProcessingPlatform__c, HostingPlatform__c, WRType__c,
            Monthly__c, TieredPricingCategory__c, PricingType__c, MinimumFee__c, Material_Code__c,
            Rate__c, Unit__c, Service_Category__c, Labor_Item__c,Available_for_Data_Center__c, Notes__c,
            Available_for_Field_office__c,Resource_Code__c,GL_Account__c, GL_Account_Name__c, Rack_Rate__c 
            From EDiscovery_PricingItems__c
            where Name not in : PLIB_PricingIds 
            order by Material_Code__c
        ]);
        //system.debug('newPricingItems: ' + newPricingItems.size());
        for(EDiscovery_PricingItems__c pi : newPricingItems) {
            pricingItems.add(new Pulse_PricingItemWrapper(pi));         
        }
        //system.debug('pricingItems: ' + pricingItems);
    }
    public void addAll() {
        for(Pulse_PricingItemWrapper newPi : pricingItems) {
            newPi.selected = true;
        }
        addSelected();
    }
    public void addSelected() {
        list<EDiscovery_PricingLibrary__c> newPLIBItems = new list<EDiscovery_PricingLibrary__c>();
        
        for(Pulse_PricingItemWrapper newPi : pricingItems) {
            if(newPi.selected) {
                EDiscovery_PricingLibrary__c libItem = new EDiscovery_PricingLibrary__c();
                EDiscovery_PricingItems__c pi = new EDiscovery_PricingItems__c();
                pi = newPi.pricingItem;
                libItem.Project__c = projId; 
                //libItem.Item__c = pi.BillableItem__c;
                libItem.WRType__c = pi.WRType__c;
                libItem.Monthly__c = pi.Monthly__c;
                libItem.TieredPricingCategory__c = pi.TieredPricingCategory__c;
                libItem.PricingType__c = pi.PricingType__c;
                libItem.MinimumFee__c = pi.MinimumFee__c;
                //libItem.Unit__c = pi.Unit__c;
                libItem.Rate__c = pi.Rate__c;
                libItem.Service_Category__c = pi.Service_Category__c;
                libItem.Labor_Item__c = pi.Labor_Item__c;
                libItem.Resource_Code__c = pi.Resource_Code__c;
                libItem.GL_Account__c = pi.GL_Account__c;
                libItem.GL_Account_Name__c = pi.GL_Account_Name__c;
                libItem.Rack_Rate__c = pi.Rack_Rate__c;
                libItem.Pricing_Item_ID__c = pi.Name;
                libItem.PricingItem__c = pi.Id;
                //libItem.Material_Code__c = pi.Material_Code__c;
                libItem.Notes__c = pi.Notes__c;
                
                if(!newPLIBItems.contains(libItem))
                    newPLIBItems.add(libItem);
            }
        } 
        if(newPLIBItems.size() > 0)
            insert newPLIBItems;
        
        if(newPLIBItems.size() == 1)
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Added ' + newPLIBItems.size() + ' new pricing item to the library'));
        else
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Added ' + newPLIBItems.size() + ' new pricing items to the library'));
        
        Initialize();
    }
    
    public PageReference returnToProj()
    {
        PageReference result = new PageReference('/' + projId);
        return result;
    }
}