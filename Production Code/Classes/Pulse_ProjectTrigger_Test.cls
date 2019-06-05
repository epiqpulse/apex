@isTest
private class Pulse_ProjectTrigger_Test {
    
    // creating two projects will result in one for data center and one for field office.
    // the final assert in this test should verify that a Pricing Library record was created
    // for every existing test Pricing Item, and the Pricing items available for both record types
    // resulted in two Pricing Libraries.
    static testMethod void testTwoProjectInsertPricingLibraryCreation() {
        integer noOfProjects = 2;
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(noOfProjects);
        set<string> projIds = Pulse_Utils.getFieldValueSet(container.discoPros, 'Id');
        list<EDiscovery_PricingItems__c> dualPricingItems = [select Id from EDiscovery_PricingItems__c 
                                                            where Available_for_Data_Center__c = true
                                                            and Available_for_Field_office__c = true];
        list<EDiscovery_PricingLibrary__c> pricingLibEntries = [select Id from EDiscovery_PricingLibrary__c where Project__c in : projIds];
        system.assertEquals(pricingLibEntries.size(), container.testPricingItems.size() + dualPricingItems.size());
    }
        
  // creating a single project results in only the pricing items corresponding to the correct
  // record type being created.
    static testMethod void testOneProjectInsertPricingLibraryCreation() {
      integer noOfProjects = 1;
      Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(noOfProjects);
      set<string> projIds = Pulse_Utils.getFieldValueSet(container.discoPros, 'Id');
      list<EDiscovery_PricingItems__c> pricingItems = [select Id from EDiscovery_PricingItems__c where Available_for_Data_Center__c = true];
      list<EDiscovery_PricingLibrary__c> pricingLibEntries = [select Id from EDiscovery_PricingLibrary__c where Project__c in : projIds];
      system.assertEquals(pricingLibEntries.size(), pricingItems.size());
    }
      
    // create a single Project and verify that all Pricing Libraries were created. Delete a few of the existing records, assert that the deletion was 
    // successful, then update the Project and recheck that the deleted records were recreated.
    static testMethod void testOneProjectUpdatePricingLibraryCreation() {
        integer noOfProjects = 1;
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(noOfProjects);
        set<string> projIds = Pulse_Utils.getFieldValueSet(container.discoPros, 'Id');
        list<EDiscovery_PricingItems__c> pricingItems = [select Id from EDiscovery_PricingItems__c where Available_for_Data_Center__c = true];
        list<EDiscovery_PricingLibrary__c> pricingLibEntries = [select Id from EDiscovery_PricingLibrary__c where Project__c in : projIds];
        system.assertEquals(pricingLibEntries.size(), pricingItems.size());
        integer originalLibs = pricingLibEntries.size();
        list<EDiscovery_PricingLibrary__c> libsToDelete = new list<EDiscovery_PricingLibrary__c>();
        for(integer x = 0; x <= pricingLibEntries.size() - 1; x++){
            if(x < originalLibs/2) libsToDelete.add(pricingLibEntries[x]);
        }
        delete libsToDelete;
        pricingLibEntries = [select Id from EDiscovery_PricingLibrary__c where Project__c in : projIds];
        system.assertEquals(originalLibs/2, pricingLibEntries.size());
        test.startTest();
        container.discoPros[0].Admin_Tag__c = 'Update_Pricing_Libraries';
        update container.discoPros;
        test.stopTest();
        pricingLibEntries = [select Id from EDiscovery_PricingLibrary__c where Project__c in : projIds];
        system.assertEquals(originalLibs, pricingLibEntries.size());
    }
    
    //Create a single project and verify that if needed a WR of type Environment Setup - Case Initiation is created
    static testMethod void testOneProjectInsertWRcreation(){
       list<Group> OwnerQ = [select Id from Group where Type = 'Queue' and Name = 'Technical Support' LIMIT 1]; 
       String QId = string.valueOf(OwnerQ[0].Id);
       integer noOfProjects = 1;
       Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
       container.createProjectsWithRecordType(1, 'Data Center Project', false);
       container.discoPros[0].Delivery_Location__c = 'SEA DC';
       container.discoPros[0].ESI_Project_Code__c = null;
       insert container.discoPros;
       container.createWorkRequestWithRecordType(1, 'Environment Setup - Case Initiation', false);
       container.testWorkRequests[0].Headline__c = 'Environment Set Up, Project Folders creation, and FTP Site Set Up.';
       container.testWorkRequests[0].PM_Instructions__c = 'Complete Environment Set Up, Create Project Folders, and Create FTP Site.';
       container.testWorkRequests[0].Tech_Time_Description__c = 'N/A';
       container.testWorkRequests[0].Work_Request_Status__c = 'Submitted';
       container.testWorkRequests[0].OwnerId = OwnerQ[0].id;
       insert container.testWorkRequests;
       system.debug('Container WR = ' + container.testWorkRequests);
    }
}