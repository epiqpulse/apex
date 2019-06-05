@IsTest
public class Pulse_BillingLogic_Class_Test {
    
	static testMethod void Test_EBI_Stats() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        list<RecordType> RecordTypes = Pulse_Test_Helpers.CreateAutoStatRecordType();        
        EDiscovery_ApplicationDatabases__c appDB = CreateRelHostingDB(container);
        EDiscovery_WorkRequest__c WorkRequest = CreateWR(container);
        Application_Database_Assignments__c AppDBA = new Application_Database_Assignments__c();
        EDiscovery_Stat_Codes__c StatCode = new EDiscovery_Stat_Codes__c();
        EDiscovery_Stat_Codes__c StatCode2 = new EDiscovery_Stat_Codes__c();
        
        // assign the app db to the auto stat WR
        AppDBA.Work_Request__c = WorkRequest.Id;
        AppDBA.Application_Database__c = appDB.Id;
        insert AppDBA;
        
        // update the pricing item to be an EBI source type
        container.testPricingItems[0].WR_Billable_Types__c = null;
        container.testPricingItems[0].BillableItem__c = 'Native Files';
        container.testPricingItems[0].Source_Type__c = 'EBI';
        update container.testPricingItems;
        
        test.startTest();
        // the auto stat WR has been created so insert the stat code and then update the WR to fire the trigger
        StatCode.Project__c = container.discoPros[0].Id;
        StatCode.Work_Request__c = WorkRequest.Id;
        StatCode.Application_Database__c = appDB.Id;
        StatCode.Quantity__c = 50;
        StatCode.Billable__c = true;
        StatCode.PricingItem__c = container.testPricingItems[0].Id;
        insert StatCode;
        
        WorkRequest.Case_Name__c = 'Update me';
        update WorkRequest;
        
        // add a duplicate stat code so it aggregates the quantity instead of duplicating the billable item. This is for standard billable items only (where Source Type is null)
        StatCode2.Project__c = container.discoPros[0].Id;
        StatCode2.Work_Request__c = WorkRequest.Id;
        StatCode2.Application_Database__c = appDB.Id;
        StatCode2.Quantity__c = 50;
        StatCode2.Billable__c = true;
        StatCode2.PricingItem__c = container.testPricingItems[0].Id;
        insert StatCode2;
        
        container.testPricingItems[0].Source_Type__c = null;
        update container.testPricingItems[0];
        
        WorkRequest.Case_Name__c = 'Update me again';
        update WorkRequest;
        
        test.stopTest();
    }
    
    private static EDiscovery_WorkRequest__c CreateWR(Pulse_Test_Helpers.Test_Container container) {
        EDiscovery_WorkRequest__c wr = new EDiscovery_WorkRequest__c();
        RecordType wrRecordType = [Select Id, SObjectType, Name, IsActive, DeveloperName 
                                       From RecordType Where SObjectType = 'EDiscovery_WorkRequest__c' 
                                       And IsActive = true AND Name = 'Monthly Auto Stats Collection' limit 1];
        
        wr.Project__c = container.discoPros[0].Id;
        wr.RecordTypeId = wrRecordType.Id;
        wr.Headline__c = wrRecordType.Name;
        wr.Work_Request_Status__c = 'Submitted';
        
        insert wr;
        return wr;
    }
    private static EDiscovery_ApplicationDatabases__c CreateRelHostingDB(Pulse_Test_Helpers.Test_Container container) {
		map<id, string> recordTypeMap = Pulse_Utils.getSObjectRecordTypeMap('EDiscovery_ApplicationDatabases__c');
        EDiscovery_ApplicationDatabases__c appDB = new EDiscovery_ApplicationDatabases__c();
        for(id recordTypeId : recordTypeMap.keySet()) {
            if(recordTypeMap.get(recordTypeId) == 'Relativity Hosting') {
                appDB.Project__c = container.discoPros[0].Id;
                appDB.Database_Name__c = 'TestDB';
                appDB.RecordTypeId = recordTypeId;
                appDB.Bill_Code__c = 'ABC1';
                appDB.Apply_Custom_Billing__c = 'Use Standard';
                appDB.Custom_Billable_Hosting_Components__c = 'Native Files; Pristine Images; Production Images; MDF'; // the standard components
                appDB.Relativity_Host_Workspace_Artifcact_ID__c = '1234567';
            }
        }
        insert appDB;
        return appDB;
    }
}