@isTest
public class Pulse_AddMediaController_Test {
    static testMethod void controllerTest() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1);
        
        list<EDiscovery_Media__c> mediaItems = new list<EDiscovery_Media__c>();
        EDiscovery_Media__c media = new EDiscovery_Media__c();
        media.Project__c = container.discoPros[0].Id;
        media.Evidence_Location__c = 'Epiq - US/PHX';
        media.Media_Possession_CoC__c = 'Storage Bin';
        media.Bin_Number__c = 'A-1-1';
                
        EDiscovery_Media__c media2 = new EDiscovery_Media__c();
        media2.Project__c = container.discoPros[0].Id;
        media2.Evidence_Location__c = 'Epiq - US/PHX';
        media2.Media_Possession_CoC__c = 'Storage Bin';
        media2.Bin_Number__c = 'A-1-1';
        mediaItems.add(media);
        mediaItems.add(media2);
        insert mediaItems;
        
        list<RecordType> RecordTypes = [Select Id, SObjectType, Name, IsActive, DeveloperName 
                        				From RecordType Where SObjectType = 'EDiscovery_WorkRequest__c' And IsActive = true AND Name IN ('EH - Shipping')];
        EDiscovery_WorkRequest__c wr = new EDiscovery_WorkRequest__c();
        wr.Project__c = container.discoPros[0].Id;
        wr.Headline__c = 'Test';
        wr.RecordTypeId = RecordTypes[0].Id;  
      	wr.Name__c = 'ControllerTest';
      	wr.Work_Request_Status__c = 'Pre-Submission';
        
        insert wr;
        
        test.StartTest();
	    PageReference pageRef = Page.Pulse_AddMediaAssignmentsToWR;
        EDiscovery_Project__c prj = [Select Name from EDiscovery_Project__c where Id = :container.discoPros[0].Id];
	    pageRef.getParameters().put('wrid', wr.id);
        pageRef.getParameters().put('projid', prj.Name);
	    Test.setCurrentPage(pageRef);
        
	    ApexPages.StandardSetController setCon = new ApexPages.StandardSetController(mediaItems);
        
	    Pulse_AddMediaController controller = new Pulse_AddMediaController(setCon);
	    controller.Initialize();
	    controller.mediaList[0].selected = true;	    
	    controller.AddMediaRecords();
        controller.checkAll();
	    controller.cancel();
        //delete media;        
        controller.Initialize();
        controller.AddMediaRecords();
      	test.StopTest();
    }
}