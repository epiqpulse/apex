public class Pulse_PricingLibraryController {

    public string projId {get; set;}
    public string projName {get; set;}
    public string projRecordType {get; set;}
    
    EDiscovery_Project__c proj;
    list<EDiscovery_PricingItems__c> DataCenterItems = new list<EDiscovery_PricingItems__c>();
    list<EDiscovery_PricingItems__c> FieldOfficeItems = new list<EDiscovery_PricingItems__c>();
    list<EDiscovery_PricingLibrary__c> ProjectPricingItems = new list<EDiscovery_PricingLibrary__c>();
    
    list<EDiscovery_PricingItems__c> PricingItems = new list<EDiscovery_PricingItems__c>(
        [ Select Id, Name, BillableItem__c, ProcessingPlatform__c, HostingPlatform__c, WRType__c,
            Monthly__c, TieredPricingCategory__c, PricingType__c, MinimumFee__c,Material_Code__c,
            Rate__c, Unit__c, Service_Category__c, Labor_Item__c,Available_for_Data_Center__c,
            Available_for_Field_office__c,Resource_Code__c,GL_Account__c, GL_Account_Name__c, Rack_Rate__c 
            From EDiscovery_PricingItems__c 
        ]
     );
    
    public Pulse_PricingLibraryController() {
        projId = ApexPages.currentPage().getParameters().get('projid');        
        proj = [select id,Name,Opportunity__c, RecordTypeId from EDiscovery_Project__c where id= :projId ];          
        projName = ApexPages.currentPage().getParameters().get('projname');        
        Map<ID,Schema.RecordTypeInfo> rt_Map = EDiscovery_Project__c.sObjectType.getDescribe().getRecordTypeInfosById();
        projRecordType = rt_map.get(proj.recordTypeID).getName();        
    }
    
    public Pagereference UpdateItems() {        
        ProjectPricingItems = [select Id, Project__c, WRType__c, Monthly__c,TieredPricingCategory__c,PricingType__c,MinimumFee__c,Rate__c,Service_Category__c,
                               Labor_Item__c,Resource_Code__c,GL_Account__c,GL_Account_Name__c,Rack_Rate__c,Pricing_Item_ID__c, PricingItem__c
                              From EDiscovery_PricingLibrary__c
                              Where Project__c = :projId];
        
        for(EDiscovery_PricingItems__c pi : PricingItems) {
            if(pi.Available_for_Data_Center__c == true) DataCenterItems.add(pi);
            if(pi.Available_for_Field_office__c == true) FieldOfficeItems.add(pi);
        }
        
        list<EDiscovery_PricingLibrary__c> NewProjectPricingItems = new list<EDiscovery_PricingLibrary__c>();
        list<EDiscovery_PricingItems__c> ItemsToAdd = new list<EDiscovery_PricingItems__c>();
        
        if(projRecordType == 'Data Center Project') {
            for(EDiscovery_PricingItems__c pi :DataCenterItems) {
                boolean match = false;
                for(EDiscovery_PricingLibrary__c projItem : ProjectPricingItems) {
                    if((string)pi.Name == (string)projItem.Pricing_Item_ID__c) match = true;
                    //if(pi.Service_Category__c + pi.BillableItem__c + pi.Unit__c == projItem.Service_Category__c + projItem.Item__c + projItem.Unit__c)
                    //    match = true;
                }
                if(!match) {
                    if(!ItemsToAdd.contains(pi))
                        ItemsToAdd.add(pi);
                }
            }
        }
        else {
            if(projRecordType == 'Field Office Project') {
                for(EDiscovery_PricingItems__c pi :FieldOfficeItems) {
                    boolean match = false;
                    for(EDiscovery_PricingLibrary__c projItem : ProjectPricingItems) {
                        if((string)pi.Name == (string)projItem.Pricing_Item_ID__c) match = true;
                    }
                    if(!match) {
                        if(!ItemsToAdd.contains(pi))
                            ItemsToAdd.add(pi);
                    }
                }
            }
        }
        system.debug('ItemsToAdd: ' + ItemsToAdd);
        if(ItemsToAdd.size() > 0) {
            for(EDiscovery_PricingItems__c Item : ItemsToAdd) {
                EDiscovery_PricingLibrary__c libItem = new EDiscovery_PricingLibrary__c();
                libItem.Project__c = proj.Id; 
                //libItem.Item__c = Item.BillableItem__c;
                libItem.WRType__c = Item.WRType__c;
                libItem.Monthly__c = Item.Monthly__c;
                libItem.TieredPricingCategory__c = Item.TieredPricingCategory__c;
                libItem.PricingType__c = Item.PricingType__c;
                libItem.MinimumFee__c = Item.MinimumFee__c;
                //libItem.Unit__c = Item.Unit__c;
                libItem.Rate__c = Item.Rate__c;
                libItem.Service_Category__c = Item.Service_Category__c;
                libItem.Labor_Item__c = Item.Labor_Item__c;
                libItem.Resource_Code__c = Item.Resource_Code__c;
                libItem.GL_Account__c = Item.GL_Account__c;
                libItem.GL_Account_Name__c = Item.GL_Account_Name__c;
                libItem.Rack_Rate__c = Item.Rack_Rate__c;
                libItem.Pricing_Item_ID__c = Item.Name;
                libItem.PricingItem__c = Item.Id;
                //libItem.Material_Code__c = Item.Material_Code__c;
                
                if(!NewProjectPricingItems.contains(libItem))
                    NewProjectPricingItems.add(libItem); 
            }
            if(NewProjectPricingItems.size() > 0)
                insert NewProjectPricingItems;
        }
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Added ' + NewProjectPricingItems.size() + ' new items'));
        return null;
    }
    public Pagereference Cancel() {
        pagereference p = new pageReference('/'+projId);
        return p;
    }
}