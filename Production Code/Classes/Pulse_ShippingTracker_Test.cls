@isTest
private class Pulse_ShippingTracker_Test {
    
    static testMethod void testShippingTrackerTrigger() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
		container.createMedia(1, true);
        
        container.createWorkRequestWithRecordType(1, 'EO - Shipping', true);
        
        EDiscovery_MediaAssignment__c MA = new EDiscovery_MediaAssignment__c();
        MA.WorkRequest__c = container.testWorkRequests[0].Id;
        MA.Media__c = container.testMediaList[0].Id;
        insert MA;
        
        EDiscovery_ShippingTracker__c ST = new EDiscovery_ShippingTracker__c();
        ST.WorkRequest__c = container.testWorkRequests[0].Id;
        ST.Project__c = container.discoPros[0].Id;
        insert ST;
    }

    static testMethod void ShippingTrackerTest() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        container.createMedia(1, false);
        list<RecordType> RecordTypes = Pulse_Test_Helpers.CreateRecordTypeList2();
                
        container.testMediaList[0].Media_Possession_CoC__c = 'Remote';
        container.testMediaList[0].Evidence_Location__c = 'Epiq - US/PHX';
                
        insert container.testMediaList;
        
        EDiscovery_WorkRequest__c wr = new EDiscovery_WorkRequest__c();
      	wr.Project__c = container.discoPros[0].Id;
      	wr.RecordTypeId = RecordTypes[0].Id;      	
      	wr.Name__c = 'ControllerTest';
      	wr.Requested_Time__c = System.today().addDays(2);
      	wr.Work_Request_Status__c = 'Pre-Submission';
      	
      	insert wr;
      	
      	EDiscovery_ShippingTracker__c STracker = new EDiscovery_ShippingTracker__c();
      	STracker.Project__c = container.discoPros[0].Id;
      	STracker.WorkRequest__c = wr.Id;
      	STracker.Tracking_Number__c = '1234567890';
      	STracker.Media__c = container.testMediaList[0].Id;
      	
      	Test.startTest();
      	insert STracker;
      	
      	delete STracker;
      	Test.stopTest();
    }

    // Test that when a single EDiscovery_ShippingTracker__c is inserted with 
    // a value in Media_to_Associate__c that an associated Assignment record 
    // is created for every Id stored in that field.
    static testMethod void testMediaAssignmentCreation(){
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        string stTrackingNumber = 'TEST-1234-TEST';
        string stCourier = 'Some guy on a bike';
        container.createWorkRequests(true);
        Integer mediaRequested = 5;
        container.createMedia(mediaRequested, true);
        string mediaIds = '';
        for(EDiscovery_Media__c each : container.testMediaList){
            mediaIds += string.valueOf(each.Id) + ';';
        }
        mediaIds.removeEnd(';');
        system.debug(mediaIds);
        // create and insert a new Shipping Tracker with a delimited string of media ids in the Media_to_Associate__c field
        // populating that field will kick off the process that the visual force page runs and create Shipping_Tracker_Media_Association records
        // and update the Media records accordingly.
        EDiscovery_ShippingTracker__c newST = new EDiscovery_ShippingTracker__c(
            																		Project__c = container.discoPros[0].Id,
            																		WorkRequest__c = container.testWorkRequests[0].Id,
            																		Tracking_Number__c = stTrackingNumber,
            																		Courier__c = stCourier,
        																			Media_to_Associate__c = mediaIds
        																		);
        insert newST;
        
        list<Shipping_Tracker_Media_Assignment__c> trackerMediaAssignments = [select Id from Shipping_Tracker_Media_Assignment__c where Shipping_Tracker__c = : newST.Id];
        system.assertEquals(mediaRequested, trackerMediaAssignments.size());
        // query the Shipping Tracker to verify that the media Id text field was not actually saved to the record.
        newST = [select Id, Media_to_Associate__c from EDiscovery_ShippingTracker__c where Id = : newST.Id];
        system.assert(newSt.Media_to_Associate__c == null);
		EDiscovery_WorkRequest__c wr = [select Id, Name from EDiscovery_WorkRequest__c where Id = : container.testWorkRequests[0].Id];
        string userName = UserInfo.getName();
        string expectedCustodyString = 'Shipped out of Epiq: Tracking # ' + stTrackingNumber + '^' + stCourier + '^' + 
            wr.Name + '^' + userName + '^A-1-1';
        // requery the media to capture the updated fields and assign the first to a variable for assertions
		container.testMediaList = [select id, Media_Possession_CoC__c, Evidence_Location__c, COC__c, Bin_Number__c
                                  from EDiscovery_Media__c where Id in : container.testMediaList];
        EDiscovery_Media__c sample = container.testMediaList[0];
        // assert that all values were appropriately updated on the Media record we queried. All
        // Media records would have received the same update.
      //    system.assertEquals('Shipped', sample.Media_Possession_CoC__c);
      //    system.assertEquals('Epiq - Shipped', sample.Evidence_Location__c);
      //    system.assertEquals(null, sample.Bin_Number__c);
      //    system.assertEquals(expectedCustodyString, sample.COC__c);
        list<Chain_of_Custody_Action__c> cocActionList = [select Id, Evidence_Location__c, Bin_Number__c, Released_By__c, Received_By__c 
                                                          from Chain_of_Custody_Action__c where Purpose__c != 'Acquisition of Item'];
    //    system.assert(!cocActionList.isEmpty());
    //    system.assertEquals(stCourier + '\nTracking #: ' + stTrackingNumber, cocActionList[0].Released_By__c);
    //    system.assertEquals(sample.Evidence_Location__c, cocActionList[0].Evidence_Location__c);
    //    system.assertEquals(sample.Bin_Number__c, cocActionList[0].Bin_Number__c);
     }
}