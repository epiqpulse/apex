@isTest
public with sharing class Pulse_MassAddBillableItems_Test {
    
    public static testMethod void Pulse_MassAddBillableItems_Test() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createProjectsWithRecordType(1, 'Field Office Project', true);
        // the test helper adds the same WR BillableTypes to every Pricing Item record
        // remove the values from 10 of the Field Office Available records. Those records should
        // show up as available to create Billable Items from still but will not be marked as default
        // in the pages list.
        Integer numberOfPricingItemsToUpdate = 10;
        Integer numberUpdated = 0;
        for(EDiscovery_PricingItems__c eachPI : container.TestPricingItems){
            if(numberUpdated < numberOfPricingItemsToUpdate && eachPI.Available_for_Field_office__c){
                eachPI.WR_Billable_Types__c = null;
                numberUpdated += 1;
            }
        }
        update container.TestPricingItems;
        container.findPricingLibraries();
        container.createWorkRequestWithRecordType(1, 'Field Office Work Request', true);
        container.findBillableItems();
        Integer expectedBICount = container.testBillableItems.size();
        Integer numberOfBIToDelete = 5;
        Integer numberOfBIRemoved = 0;
        list<EDiscovery_BillableItems__c> biForDeletion = new list<EDiscovery_BillableItems__c>();
        for(EDiscovery_BillableItems__c eachBI : container.testBillableItems) {
            if(numberOFBIRemoved < numberOfBIToDelete){
                biForDeletion.add(eachBI);
                numberofBIRemoved += 1;
            }
        }
        //system.assertEquals(numberOfBIToDelete, biForDeletion.size());
        delete biForDeletion;
        container.findBillableItems();
        system.assertEquals(expectedBICount - numberOfBIRemoved, container.testBillableItems.size());
        test.startTest();

        PageReference pageRef = Page.Pulse_MassAddBillableItems;
        pageRef.getParameters().put('CF00N3100000GErwE_lkid', container.discoPros[0].Id);
        pageRef.getParameters().put('CF00N3100000GErwK_lkid', container.testWorkRequests[0].Id);

        Test.setCurrentPage(pageRef);
        Pulse_MassAddBillableItems controller = new Pulse_MassAddBillableItems(new ApexPages.StandardController(new EDiscovery_BillableItems__c()));

        // query for all Field Office Pricing Items that are not default for the WR
        // the result size + the number of Billable Items that were previously deleted
        // should match the number of selectable Pricing Items the page came up with.
        list<EDiscovery_PricingItems__c> nondefaultFOpricingItems = [select Id from EDiscovery_PricingItems__c 
                                                                        where Available_for_Field_office__c = true 
                                                                        and WR_Billable_Types__c = null];

        system.assertEquals(nondefaultFOPricingItems.size() + numberOfBIRemoved, controller.selectablePItems.size());
        // count the number of Selectable Pricing Items marked default, should match the 
        // number of Billable Items deleted earlier. Select the records that would have
        // been default, we will use the page functionality to recreate those Billable Items.
        Integer noOfDefaultSPItems = 0;
        for(Integer x = 0; x < controller.selectablePItems.size(); x++){
            if(controller.selectablePItems[x].defaultBillableItem){ 
                noOfDefaultSPItems += 1;
                controller.selectablePItems[x].selected = true;
            }
        }
        system.assertEquals(numberofBIRemoved, noOfDefaultSPItems);
        // run the method that selects the Pricing Items, they will be moved to a separate
        // list.
        controller.selectPricingItems();
        // verify that the list of selected items = the number of items expected
        system.assertEquals(noOfDefaultSPItems, controller.userChosenPItems.size());
        // create tne new Pricing Items from the selected records
        controller.createNewBillableItemsFromSelection();
        // run test Helper method to find BI associated to the WR assert that the 
        // number equals the original count of BI created.
        container.findBillableItems();
        system.assertEquals(expectedBICount, container.TestBillableItems.size());
        // test with a newly constructed controller that we can select all available Pricing Items and that
        // the reset selections code will clear the list and the selected attribute for each record.
        controller = new Pulse_MassAddBillableItems(new ApexPages.StandardController(new EDiscovery_BillableItems__c()));
        for(Integer x = 0; x < controller.selectablePItems.size(); x++) {
            controller.selectablePItems[x].selected = true;
        }
        // run method that selects records and moves them to chosen record list
        controller.selectPricingItems();
        system.assert(controller.userChosenPItems.size() > 0);
        // run method that resets selection and assert list size 0 and all
        // records are selected == false
        controller.updateItemSelection();
        system.assert(controller.userChosenPItems.size() == 0);
        for(Integer x = 0; x < controller.selectablePItems.size(); x++) {
           // system.assert(controller.selectablePItems[x].selected == false);
        }
        test.stopTest();
    }
    
    static testMethod void testTableSortsandFilters(){
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createProjectsWithRecordType(1, 'Field Office Project', true);
        // the test helper adds the same WR BillableTypes to every Pricing Item record
        // remove the values from 10 of the Field Office Available records. Those records should
        // show up as available to create Billable Items from still but will not be marked as default
        // in the pages list.
        Integer numberOfPricingItemsToUpdate = 10;
        Integer numberUpdated = 0;
        for(EDiscovery_PricingItems__c eachPI : container.TestPricingItems){
            if(numberUpdated < numberOfPricingItemsToUpdate && eachPI.Available_for_Field_office__c){
                eachPI.WR_Billable_Types__c = null;
                numberUpdated += 1;
            }
        }
        update container.TestPricingItems;
        container.findPricingLibraries();
        container.createWorkRequestWithRecordType(1, 'Field Office Work Request', true);
        container.findBillableItems();
        test.startTest();

        PageReference pageRef = Page.Pulse_MassAddBillableItems;
        pageRef.getParameters().put('CF00N3100000GErwE_lkid', container.discoPros[0].Id);
        pageRef.getParameters().put('CF00N3100000GErwK_lkid', container.testWorkRequests[0].Id);

        Test.setCurrentPage(pageRef);
        Pulse_MassAddBillableItems controller = new Pulse_MassAddBillableItems(new ApexPages.StandardController(new EDiscovery_BillableItems__c()));
        Integer selectNumber = 5; 
        // 5 of the records in the Pricing Item table will be marked as selected
        // Then the table will be sorted by another attribute so we can verify that the sorting code
        // is working properly. First by verifying that not all of the first 5 are selected any longer
        // then by sorting by selection and verifying that they are.
        for(Integer x = 0; x < selectNumber; x++) {
            controller.pageItems[x].selected = true;
        }
        // set sortDirection to none, the controller method will switch it to
        // the next value (ASC) before running the query. set the sortExpression to
        // Unit that is normally set by the user clicking on one of the column headers
        controller.sortDirection = 'None';
        controller.sortExpression = 'Unit';
        // query Pricing Items in ascending order and pull the first 5 Unit for verification.
        list<EDiscovery_PricingItems__c> orderedPI = [select Id, Name, Material_Code__c, Unit__c from EDiscovery_PricingItems__c 
                                                      where id in : controller.originalPIList order by Unit__c ASC];
        controller.updateTable();
        // orderChanged set to true if one of the first 5 records is not 'selected'
        boolean orderChanged = false;
        system.debug(orderedPI.size());
        system.debug(controller.selectablePItems.size());
        string firstUnit;
        string lastUnit;
        for(Integer x = 0; x < orderedPI.size(); x++) {
            if(x == 0) firstUnit = orderedPI[x].Unit__c;
            if(x == orderedPI.size() - 1) lastUnit = orderedPI[x].Unit__c;
            // system.assertEquals(orderedPI[x].Unit__c, controller.selectablePItems[x].item.Unit__c);
            if(x < 5 && controller.selectablePItems[x].selected == false) orderChanged = true;
        }
        system.assert(orderChanged);
        orderedPI = [select Id, Name, Material_Code__c, Unit__c from EDiscovery_PricingItems__c 
                where id in : controller.originalPIList order by Unit__c DESC];
        controller.updateTable();

        for(Integer x = 0; x < orderedPI.size(); x++) {
            // assert that the unit order is reversed by checking the first
            // and last are reversed from the previous run
            if(x == 0) system.assertEquals(orderedPI[x].Unit__c, lastUnit);
            if(x == orderedPI.size() - 1) system.assertEquals(orderedPI[x].Unit__c, firstUnit);
            // system.assertEquals(orderedPI[x].Unit__c, controller.selectablePItems[x].item.Unit__c);
            if(x < 5 && controller.selectablePItems[x].selected == false) orderChanged = true;
        }
        
        controller.updateTable();
    // the last run of updateTable should have set the controller sort variables back to the initial settings
    system.assertEquals('DESC', controller.sortDirection);
    //    system.assertEquals('', controller.sortExpression);
    controller.sortExpression = 'Selected';
        controller.prevsortExpression = 'Selected';
        controller.sortDirection = 'ASC';
        controller.UpdateTable();
        for(integer x = 0; x < selectNumber; x++) system.assert(controller.selectablePItems[x].selected);
            
    controller.materialCode = orderedPI[0].Material_Code__c;
        controller.sortExpression = '';
        
        controller.filterPricingItems();
        system.assertEquals(1, controller.selectablePItems.size());
    }
    
    static testMethod void testRedirect() {
                Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createProjectsWithRecordType(1, 'Field Office Project', true);
        // the test helper adds the same WR BillableTypes to every Pricing Item record
        // remove the values from 10 of the Field Office Available records. Those records should
        // show up as available to create Billable Items from still but will not be marked as default
        // in the pages list.
        Integer numberOfPricingItemsToUpdate = 10;
        Integer numberUpdated = 0;
        for(EDiscovery_PricingItems__c eachPI : container.TestPricingItems){
            if(numberUpdated < numberOfPricingItemsToUpdate && eachPI.Available_for_Field_office__c){
                eachPI.WR_Billable_Types__c = null;
                numberUpdated += 1;
            }
        }
        update container.TestPricingItems;
        container.findPricingLibraries();
        container.createWorkRequestWithRecordType(1, 'Field Office Work Request', true);
        container.findBillableItems();
        test.startTest();
    // the original run of redirect will return a pageRef because the mass add parameter is not there
        PageReference pageRef = Page.Pulse_MassAddBillableItems;
        pageRef.getParameters().put('CF00N3100000GErwE_lkid', container.discoPros[0].Id);
        pageRef.getParameters().put('CF00N3100000GErwK_lkid', container.testWorkRequests[0].Id);

        Test.setCurrentPage(pageRef);
        Pulse_MassAddBillableItems controller = new Pulse_MassAddBillableItems(new ApexPages.StandardController(new EDiscovery_BillableItems__c()));
        system.assertNotEquals(null, controller.redirect());
        pageRef.getParameters().put('MassAddBi', 'true');
    // the second run will return null so access to the vf page is granted.
        Test.setCurrentPage(pageRef);
        controller = new Pulse_MassAddBillableItems(new ApexPages.StandardController(new EDiscovery_BillableItems__c()));
        system.assertEquals(null, controller.redirect());
    }
    
    static testMethod void testPaging() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
    delete container.TestPricingItems;
        container.createPricingItems(120);
        for(EDiscovery_PricingItems__c eachPItem : container.testPricingItems) {
            eachPItem.WR_Billable_Types__c = null;
        }
        update container.testPricingItems;
        container.createProjectsWithRecordType(1, 'Field Office Project', true);
        container.findPricingLibraries();
        system.debug(container.testPricingLibraries.size());
        container.createWorkRequestWithRecordType(1, 'Field Office Work Request', true);
        container.findBillableItems();
        system.debug(container.testBillableItems.size());
        
        test.startTest();
        PageReference pageRef = Page.Pulse_MassAddBillableItems;
        pageRef.getParameters().put('CF00N3100000GErwE_lkid', container.discoPros[0].Id);
        pageRef.getParameters().put('CF00N3100000GErwK_lkid', container.testWorkRequests[0].Id);

        Test.setCurrentPage(pageRef);
        Pulse_MassAddBillableItems controller = new Pulse_MassAddBillableItems(new ApexPages.StandardController(new EDiscovery_BillableItems__c()));
    system.assertEquals('1', controller.PageNumber);
        controller.gotoNext();
        system.assertEquals('2', controller.PageNumber);
        controller.gotoPrevious();
        system.assertEquals('1', controller.PageNumber);
        controller.gotoLast();
        Integer listSize = controller.originalPIList.size();
        Integer pageSize = Integer.valueOf(controller.pageSize);
        boolean addPage = (math.mod(listSize, pageSize) > 0);
        Integer lastPage = (addPage? (listSize/pageSize) + 1 : (listSize/pageSize));
        system.assertEquals(String.valueOf(lastPage), controller.pageNumber);
        system.assert(controller.disableNext);
        controller.gotoFirst();
    system.assertEquals('1', controller.PageNumber);
    system.assert(controller.disablePrevious);
        test.stopTest();
    }
}