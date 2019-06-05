@isTest
public class Pulse_Media_Controller_Test {
    
	private static testMethod void testCustodyActionSaveButton() {      
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1);
    	container.createUser(true);
        list<EDiscovery_Media__c> MediaItems;
        MediaItems = new list<EDiscovery_Media__c>();
      
        EDiscovery_Media__c m1 = new EDiscovery_Media__c();
        m1.Project__c = container.discoPros[0].id;
        m1.OwnerId = container.testUser.Id;
        m1.Evidence_Location__c = 'Epiq - US/PHX';
        m1.Media_Possession_CoC__c = 'Storage Bin';    
        m1.Bin_Number__c = 'A-1-1';
        m1.Switch_Tech_Reason__c = 'Place into storage';
        MediaItems.add(m1);
      
        EDiscovery_Media__c m2 = new EDiscovery_Media__c();
        m2.Project__c = container.discoPros[0].id;
        m2.OwnerId = container.testUser.Id;
        m2.Evidence_Location__c = 'Epiq - US/PHX';
        m2.Media_Possession_CoC__c = 'Technician';    
        m2.Bin_Number__c = '';
        m2.Switch_Tech_Reason__c = 'Internal Transfer';
        MediaItems.add(m2);
      
        EDiscovery_Media__c m3 = new EDiscovery_Media__c();
        m3.Project__c = container.discoPros[0].id;
        m3.OwnerId = container.testUser.Id;
        m3.Evidence_Location__c = 'Electronic Discovery - US';
        m3.Bin_Number__c = '';
        m3.Switch_Tech_Reason__c = 'Deliver to client';
        MediaItems.add(m3);
                 
        insert MediaItems;
        
    	m3.Media_Possession_CoC__c = 'Remote';
      	update m3;
      	m3.Custody_Action_Date__c = null;
      	update m3;
      
      	system.runAs(container.testUser) {
        	test.startTest();
    		testMediaControllerSave(m1);
            testMediaControllerSave(m2);
            testMediaControllerSave(m3);
                
        	PageReference pageRef = Page.Pulse_Media_CoC_Entry;
        	pageRef.getParameters().put('id',m2.id);
        	Test.setCurrentPage(pageRef);
        	ApexPages.StandardController con = new ApexPages.StandardController(m2);
        	Pulse_Media_Controller mycon = new Pulse_Media_Controller(con);
        	mycon.returnToMedia();
       	 	Pulse_Media_Controller.SendEmailNotification(m2.id); 
          
        	test.stopTest();
    	}
  	}
    
    private static void testMediaControllerSave(EDiscovery_Media__c media) {
        PageReference pageRef = Page.Pulse_Media_CoC_Entry;
        pageRef.getParameters().put('id',media.id);
        Test.setCurrentPage(pageRef);
        ApexPages.StandardController con = new ApexPages.StandardController(media);
        Pulse_Media_Controller mycon = new Pulse_Media_Controller(con);
        mycon.SaveMediaRecord();
    }
    
    
    
}