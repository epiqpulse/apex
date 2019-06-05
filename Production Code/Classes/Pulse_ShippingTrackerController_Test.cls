@isTest
public class Pulse_ShippingTrackerController_Test {

    public static testMethod void testShippingTrackerCreation(){
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        container.createWorkRequests(true);
        container.createMedia(5, true);
        createMediaAssociations(container);
        
        Test.startTest();
        PageReference pageRef = Page.Pulse_NewShippingTracker;
        pageRef.getParameters().put('CF00N3100000GErwE_lkid', container.discoPros[0].Id);
        pageRef.getParameters().put('CF00N3100000GEs5s_lkid', container.testWorkRequests[0].Id);
        Test.setCurrentPage(pageRef);
        
        Pulse_ShippingTracker_Controller controller = new Pulse_ShippingTracker_Controller(new ApexPages.StandardController(new EDiscovery_ShippingTracker__c()));
        //populate the list of selectable associatedMedia records in the controller
        controller.getMedia();
        system.assertEquals(container.testMediaList.size(), controller.mediaAssociations.size());
        // select a few records to create a shipping tracker for
        selectMediaRecords(controller, 3);
        // verify that records were actually selected.
        verifySelection(controller, 3);
        // run the back action for selecting media, this should set selections back to 0
        controller.selectNewMedia();
        // verify that no records are selected.
        verifySelection(controller, 0);
        selectMediaRecords(controller, 3);
        verifySelection(controller, 3);
        // create a shipping Tracker record with the selected media
        controller.createShippingTrackerForMedia();
        EDiscovery_ShippingTracker__c newSTRecord = controller.newShippingTracker;
        system.assertNotEquals(null, newSTRecord.Project__c);
        system.assertNotEquals(null, newSTRecord.WorkRequest__c);
        system.assertNotEquals(null, newSTRecord.Media_to_Associate__c);
        controller.saveShippingTracker();
        string newRecordURL = controller.getNewRecordURL();
        system.debug(newRecordURL);
        Test.stopTest();
    }
    
    public static void createMediaAssociations(Pulse_Test_Helpers.Test_Container container){
        list<EDiscovery_MediaAssignment__c> mediaAssignments = new list<EDiscovery_MediaAssignment__c>();
        for(EDiscovery_Media__c media : container.testMediaList){
            mediaAssignments.add(new EDiscovery_MediaAssignment__c(WorkRequest__c = container.testWorkRequests[0].Id, Media__c = media.Id));
        }
        insert mediaAssignments;
    }
    
    public static void selectMediaRecords(Pulse_ShippingTracker_Controller controller, integer noToSelect){
        Integer noSelected = 0;
        for(Integer x = 0; x < controller.mediaAssociations.size(); x++){
            if(noSelected < noToSelect) controller.mediaAssociations[x].selected = true;
            noSelected += 1;
        }
    }
    
    public static void verifySelection(Pulse_ShippingTracker_Controller controller, integer noSelected){
        Integer selectionsFound = 0;
        for(Integer x = 0; x < controller.mediaAssociations.size(); x++){
            if(controller.mediaAssociations[x].selected) selectionsFound += 1;
        }
        system.assertEquals(noSelected, selectionsFound);
    }
    
}