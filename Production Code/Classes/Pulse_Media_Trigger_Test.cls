@isTest
private class Pulse_Media_Trigger_Test {
    
    static testMethod void testMediaInsertandCoCRecordCreation() {
    	Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
		container.createMedia(2, false);
        Boolean originalTaken = true;
        for(EDiscovery_Media__c newMedia : container.testMediaList){
            if(originalTaken){
                newMedia.Took_Original__c = 'Yes';
                originalTaken = false;
            } else {
            	newMedia.Took_Original__c = 'No';
            	newMedia.Courier__c = 'DHL';
                newMedia.Tracking_Number__c = 'ABC-12345';
            }
        }
		insert container.testMediaList;
        container.findChainofCustodyActions();
        system.assertEquals(container.testMediaList.size(), container.testChainofCustodyActions.size());
        for(Chain_of_Custody_Action__c coCAction : container.testChainofCustodyActions){
            if(coCAction.Took_Original__c == 'No') {
				system.assertEquals('Acquisition of copy of data. Original left on-site. See target and backup copies for chain of custody.', coCAction.Purpose__c);
                system.assert(!string.isBlank(coCAction.Courier__c));
                system.assert(!string.isBlank(coCAction.Tracking_Number__c)); 
            } else {
				system.assertEquals('Acquisition of Item', coCAction.Purpose__c);
                system.assert(string.isBlank(coCAction.Courier__c));
                system.assert(string.isBlank(coCAction.Tracking_Number__c));                
            }
        }
    }
    
    static testMethod void testMediaUpdateValidations() {
    	Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
		container.createMedia(1, false);
        container.testMediaList[0].Media_Possession_CoC__c = 'Received';
        container.testMediaList[0].Bin_Number__c = null;
        insert container.testMediaList;
        // attempt to update Media_Possession_CoC__c to 'Storage Bin' 
        // first without the required Bin_Number__c then successfully with
        // the required information
        container.testMediaList[0].Media_Possession_CoC__c = 'Storage Bin';
        try{
            update container.testMediaList;
            system.assert(false, 'This update should have failed due to lacking a Bin_Number__c value');
        } catch(Exception exc) {
            system.assert(exc.getMessage().contains('Bin Number is required if Storage Bin is selected!'));
        }
        container.testMediaList[0].Bin_Number__c = 'BN-12345';
        try{
            update container.testMediaList;
        } catch(Exception exc) {
            system.assert(false,'This update should have succeeded, Bin_Number__c was provided.');
        }
        // the next validation will check that 'Switch Tech' fails if no Technician__c value is provided.
        container.testMediaList[0].Media_Possession_CoC__c = 'Switch Tech';
        container.testMediaList[0].Technician__c = null;
        system.debug('null technician fail');
        try{
            update container.testMediaList;
            system.assert(false, 'This update should have failed due to lacking a Technician__c value');
        } catch(Exception exc) {
            system.assert(exc.getMessage().contains('Technician is required if Switch Tech is selected!'));
        }
        container.testMediaList[0].Technician__c = UserInfo.getUserId();
        try{
            update container.testMediaList;
        } catch(Exception exc) {
            system.assert(false,'This update should have succeeded, Technician__c was provided.');
        }
        
        // the following update will initially fail due to Media_Possession_CoC__c being 'Switch Tech'
        // and no other fields being changed.        
        container.testMediaList[0].Media_Possession_CoC__c = 'Switch Tech';
        try{
            update container.testMediaList;
            system.assert(false, 'This update should have failed due to Technician__c value or no other value changing');
        } catch(Exception exc) {
            system.assert(exc.getMessage().contains('Cannot save the update with the same technician!'));
        }







        
        container.testMediaList[0].Switch_Tech_Reason__c = 'Internal Transfer';
        try{
            update container.testMediaList;
        } catch(Exception exc) {
            system.assert(false,'This update should have succeeded, Switch_Tech_Reason__c was updated.');
        }







    }
}