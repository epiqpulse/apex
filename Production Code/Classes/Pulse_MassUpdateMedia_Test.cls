@isTest
public with sharing class Pulse_MassUpdateMedia_Test {

    // test general page functionality around record selection and controller list
    // population and clearing.
    static testMethod void Pulse_MassUpdateMedia_Test() {
        Integer noOfMedia = 5;
        // create the necessary test records Project & media. Mark one media record closed
        // so we can verify that the pages query excludes that record.
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createProjectsWithRecordType(1, 'Field Office Project', true);
        container.createMedia(noOfMedia, false);
        container.testMediaList[0].Media_Possession_CoC__c = 'Closed';
        insert container.testMediaList;

        PageReference pageRef = Page.Pulse_MassUpdateMedia;
        pageRef.getParameters().put('CF00N3100000GErwB_lkid', container.discoPros[0].Id);

        Test.setCurrentPage(pageRef);
        Pulse_MassUpdateMedia controller = new Pulse_MassUpdateMedia(new ApexPages.StandardController(new EDiscovery_Media__c()));
        system.assertEquals(noOfMedia - 1, controller.unclosedMedia.size());
        // select a number of media from the unclosedMedia list associated to the controller
        // test that the select media method correctly moves them to the second list, and that
        // the update selection method correctly clears that list and resets all the selectable
        // media records to selected = false;
        Integer noOfMediaSelected = 2;
        for(Integer x = 0; x < noOfMediaSelected; x ++) {
            controller.unclosedMedia[x].selected = true;
        }
        controller.selectMedia();
        system.assertEquals(noOfMediaSelected, controller.userSelectedMedia.size());
        controller.updateSelection();
        system.assertEquals(0, controller.userSelectedMedia.size());
        for(Integer x = 0; x < controller.unclosedMedia.size(); x ++) {
            // assert that selected = false
            system.assert(!controller.unclosedMedia[x].selected);
        }
        // test cancel returns a PageReference 
        system.assertNotEquals(null, controller.cancel());
    }

    // test that the actions for updating the media result in the desired updates
    // and new record creation where applicable.
    // Take Possession => sets running user as the record owner.
    // Shipping => creates media assignment records for selected media and chosen Work Request
    // Literally anything else => results in the media record being updated with the fields 
    // set on the placeholder Media record.
    static testMethod void testMediaActionChoices() {
        Integer noOfMedia = 5;
        // create the necessary test records Project & media.
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createProjectsWithRecordType(1, 'Data Center Project', true);
        container.createUsers(1, 'System Administrator', true);
        container.createMedia(noOfMedia, false);
        container.createWorkRequestWithRecordType(1, 'EO - Media', true);
        // use a boolean to set the first record to POR DC and the remaining to SEA DC
        Boolean porMedia = true;
        for(EDiscovery_Media__c media : container.testMediaList) {
            media.OwnerId = container.testUsers[0].Id;
            if(porMedia){
                media.Evidence_Location__c = 'POR DC';
                porMedia = false;
            } else {
                media.Evidence_Location__c = 'SEA DC';
            }
        }
        insert container.testMediaList;
        for(EDiscovery_Media__c containerMedia : [select Id, OwnerId from EDiscovery_Media__c 
                                                    where Id in : container.testMediaList]) {
            system.assertNotEquals(containerMedia.OwnerId, UserInfo.getUserId());
        }

        PageReference pageRef = Page.Pulse_MassUpdateMedia;
        pageRef.getParameters().put('CF00N3100000GErwB_lkid', container.discoPros[0].Id);

        Test.setCurrentPage(pageRef);
        Pulse_MassUpdateMedia controller = new Pulse_MassUpdateMedia(new ApexPages.StandardController(new EDiscovery_Media__c()));
        // select a number of media from the unclosedMedia list associated to the controller
        Integer noOfMediaSelected = 2;
        for(Integer x = 0; x < noOfMediaSelected; x ++) {
            controller.unclosedMedia[x].selected = true;
        }
        // This initial run should not move the user to the next page
        // due to the first and second media records having different
        // Environment Locations. We can verify this using the controller
        // attribute that controls page rendering and also by checking for
        // the error that would be displayed on the page
        controller.selectMedia();
        system.assertEquals(false, controller.newRecordSection);
        system.assertEquals('You cannot select media from multiple locations. Please review your choices.', controller.recordError);
        system.assertEquals(true, controller.newRecordError);
        // reset the selections and start again.
        for(Integer x = 0, selected = 0; x < container.testMediaList.size(); x++) {
            if(x > 0 && selected < noOfMediaSelected) {
                controller.unclosedMedia[x].selected = true;
                selected++;
            } else {
                controller.unclosedMedia[x].selected = false;
            }
        }
        controller.selectMedia();
        controller.CoCAction = 'Take Possession';
        controller.placeHolderMedia.Switch_Tech_Reason__c = 'Internal Transfer';
        controller.placeHolderMedia.Custody_Action_Notes__c = 'test take possession updates';
        controller.updateSelectedMedia();
        // verify that the take possession action updates the owner of the selected media
        list<EDiscovery_Media__c> mediaRecordsUpdated = [select Id, OwnerId, Custody_Action_Date__c, Switch_Tech_Reason__c, Custody_Action_Notes__c
                                                            from EDiscovery_Media__c where Id in : container.testMediaList
                                                            and OwnerId not in : container.testUsers];
        system.assertEquals(noOfMediaSelected, mediaRecordsUpdated.size());
        for(EDiscovery_Media__c updatedMedia : mediaRecordsUpdated) {
            system.assertEquals(UserInfo.getUserId(), updatedMedia.OwnerId);
            system.assertEquals(updatedMedia.Switch_Tech_Reason__c, controller.placeHolderMedia.Switch_Tech_Reason__c);
            system.assertEquals(updatedMedia.Custody_Action_Notes__c, controller.placeHolderMedia.Custody_Action_Notes__c);
        }
        // check that the default value method updates the placeHolder media Media_Possession_CoC__c
        // when the CoCAction page attribute is updated
        controller.CoCAction = 'Closed';
        controller.updateDefaultMediaCoC();
        system.assertEquals('Closed', controller.placeHolderMedia.Media_Possession_CoC__c);
        controller.CoCAction = 'Take Possession';
        controller.updateDefaultMediaCoC();
        system.assertEquals('Technician', controller.placeHolderMedia.Media_Possession_CoC__c);
        // verify that the 'Closed' action media updates work appropriately
        controller.CoCAction = 'Closed';
        controller.updateDefaultMediaCoC();
        controller.updateSelectedMedia();
        mediaRecordsUpdated = [select Id, OwnerId, Custody_Action_Date__c, Switch_Tech_Reason__c, Custody_Action_Notes__c
                                                            from EDiscovery_Media__c where Id in : container.testMediaList
                                                            and Media_Possession_CoC__c = 'Closed'];
        system.assertEquals(noOfMediaSelected, mediaRecordsUpdated.size());
        // verify that when the button is method is run for createMediaAssignments a Media Assignment record is created
        // for each Media record selected and the Work Request chosen in the picklist created on the page
        controller.CoCAction = 'Shipping';
        system.debug(container.testWorkRequests);
        controller.selectedWR = container.testWorkRequests[0].Id;
        controller.createMediaAssignments();
        list<EDiscovery_MediaAssignment__c> newAssignments = [select Id, Media__c, WorkRequest__c from EDiscovery_MediaAssignment__c
                                                                where WorkRequest__c in : container.testWorkRequests];
        system.assertEquals(noOfMediaSelected, newAssignments.size());
    }
}