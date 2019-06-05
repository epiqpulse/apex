public class Pulse_BillingLogic_Class {
    
 	list<string> wrIds = new list<string>();    
    
    private class BillableItemData {
        public string BillCode;
        public boolean NonBillable;
        public decimal Qty;
        public string WR;
        public decimal GB_Addendum;
    }
    
    public void ProcessAutoStatWRs(list<EDiscovery_WorkRequest__c> WRs) {        
        list<EDiscovery_BillableItems__c> bItems = new list<EDiscovery_BillableItems__c>();
        list<EDiscovery_Stat_Codes__c> EBI_Stats = new list<EDiscovery_Stat_Codes__c>();
        list<EDiscovery_Stat_Codes__c> StatCollector_Stats = new list<EDiscovery_Stat_Codes__c>();
        list<EDiscovery_Stat_Codes__c> EpiqDiscovery_Stats = new list<EDiscovery_Stat_Codes__c>();
        list<EDiscovery_Stat_Codes__c> StandardStats = new list<EDiscovery_Stat_Codes__c>();
        
        for(EDiscovery_WorkRequest__c wr : WRs) {
            if(!wrIds.contains(wr.Id)) wrIds.add(wr.Id);
        }
        
        list<EDiscovery_Stat_Codes__c> StatCodes = [Select Application_Database__c, Associated_WR_ID__c, Billable__c, Billable_Item__c, PricingItem__c, Material_Code__c, Quantity__c, Source_Type__c, Work_Request__c
                                                    from EDiscovery_Stat_Codes__c where Work_Request__c in : wrIds];
       
        for(EDiscovery_Stat_Codes__c sc : StatCodes) {
            switch on sc.Source_Type__c {
                when 'EBI', 'RR' { EBI_Stats.add(sc); }
                when 'Epiq Discovery' { EpiqDiscovery_Stats.add(sc); }
                when 'Stat Collector' { StatCollector_Stats.add(sc); }
                when null, '' { StandardStats.add(sc); }
            }
        }
        
        // have to first delete all billable items from the auto stats WRs
        bItems = [Select Id from EDiscovery_BillableItems__c where WorkRequest__c in : wrIds];
        delete bItems;
        
        if(EBI_Stats.size() > 0) ProcessEBIStats(EBI_Stats);
        if(StandardStats.size() > 0) AddStandardBillableitems(StandardStats);	// need to add these prior to Epiq Discovery and Stat Collector as they may insert non internal codes
        // if(EpiqDiscovery_Stats.size() > 0) ProcessEpiqDiscoveryStats(EpiqDiscovery_Stats);
        // if(StatCollector_Stats.size() > 0) ProcessStatCollectorStats(StatCollector_Stats);
    }
    private void ProcessEBIStats(list<EDiscovery_Stat_Codes__c> StatCodes) {
        map<string, string> appDBIds = new map<string, string>();
        list<BillableItemData> WRStatCodes = new list<BillableItemData>();
        list<string> MaterialCodes = new list<string>();        
        
        for(EDiscovery_Stat_Codes__c stat : StatCodes) {
            appDBIds.put(stat.Application_Database__c, stat.Work_Request__c);
        }
        // loop through all of the app dbs per WR and create a list of stat codes by WR (WRStatCodes)
        for(EDiscovery_ApplicationDatabases__c appDB : [Select Id, Bill_Code__c, Apply_Custom_Billing__c, Is_Billable__c, Custom_Billable_Hosting_Components__c, Hosting_GB_Addendum__c, Work_Request__c from EDiscovery_ApplicationDatabases__c where Id in : appDBIds.keyset()]) {

            for(EDiscovery_Stat_Codes__c stat : StatCodes) {                
                if(appDB.Custom_Billable_Hosting_Components__c.contains(stat.Billable_Item__c)) {
                    // we need the material codes to query the pricing items to get the correct pricing item ID. Will populate the MaterialCodeMap below
                    if(!MaterialCodes.contains(appDb.Bill_Code__c)) MaterialCodes.add(appDb.Bill_Code__c);
                    
                    BillableItemData bid = new BillableItemData();
                    bid.BillCode = appDb.Bill_Code__c;					// maps to the pricing item material code
                    bid.Qty = stat.Quantity__c;
                    bid.WR = appDBIds.get(appDb.Id);
                    bid.GB_Addendum = appDb.Hosting_GB_Addendum__c == null ? 0 : appDb.Hosting_GB_Addendum__c;	// set this to zero to avoid null reference when aggregating
                    bid.NonBillable = appDB.Is_Billable__c == 'Yes' ? false : true;
                    WRStatCodes.add(bid);                    
                }
            }
        }
        list<EDiscovery_PricingItems__c> PricingItems = [select Id, Material_Code__c from EDiscovery_PricingItems__c where Material_Code__c in : MaterialCodes];
        list<EDiscovery_BillableItems__c> BillableItems = new list<EDiscovery_BillableItems__c>();
        map<string, string> MaterialCodeMap = new map<string, string>();        
        
        // build the map from material code to pricing item
        for(EDiscovery_PricingItems__c pi : PricingItems) {
            if(!MaterialCodeMap.containsKey(pi.Material_Code__c))
                MaterialCodeMap.put(pi.Material_Code__c, pi.Id);
        }
        // loop through all of the unique WRs and build the billable items from the stat codes and aggregate the quantities for each stat that was found
        // making sure to add the GB addendum if there was one (only once)
        for(string wr : wrIds) {            
            EDiscovery_BillableItems__c bi = new EDiscovery_BillableItems__c();
            bi.Qty__c = 0;
            for(BillableItemData wrStat : WRStatCodes) {
                if(wrStat.WR == wr) {                    
                	if(bi.Qty__c == 0) bi.Qty__c = wrStat.GB_Addendum;
                    bi.Qty__c += wrStat.Qty;
                    bi.NonBillable__c = wrStat.NonBillable;
                    bi.WorkRequest__c = wr;
                    bi.PricingItem__c = MaterialCodeMap.get(wrStat.BillCode);
                }
            }
            
            BillableItems.add(bi);
        }
        if(BillableItems.size() > 0)
            insert BillableItems;
    }
    private void AddStandardBillableitems(list<EDiscovery_Stat_Codes__c> StatCodes) {
        list<EDiscovery_BillableItems__c> BillableItems = new list<EDiscovery_BillableItems__c>();
        list<string> MaterialCodes = new list<string>();
        
        for(EDiscovery_Stat_Codes__c stat : StatCodes) {
            EDiscovery_BillableItems__c bi = new EDiscovery_BillableItems__c();
            bi.Qty__c = stat.Quantity__c;
            bi.NonBillable__c = !stat.Billable__c;
            bi.WorkRequest__c = stat.Work_Request__c;
            bi.PricingItem__c = stat.PricingItem__c;
            bi.BillCode__c = stat.Material_Code__c;					// added a text field to store the material code so we can update the existing item rather than add 2 of the same
            
            if(!MaterialCodes.contains(stat.Material_Code__c)) {
            	BillableItems.add(bi);
                MaterialCodes.add(stat.Material_Code__c);
            }
            else {		// the material code has been previously added so update the quantity of the previous item rather than create a duplicate
                for(EDiscovery_BillableItems__c bItem : BillableItems) {
                    if(bItem.BillCode__c == stat.Material_Code__c) {
                        bItem.Qty__c += stat.Quantity__c;
                    }
                }
            }
        }
        
        if(BillableItems.size() > 0)
            insert BillableItems;
    }
}