@isTest
public class Pulse_ClientCodeController_Test {
	private static testMethod void testClientCode()
  	{
        Contact c = new Contact(FirstName='Test Contact',lastname='Test Last Name');
        insert c;
        
        Opportunity o = new opportunity();
        o.Name= 'test';
        o.StageName = '4 - Closed/Won';
        o.Internal_Referral__c='Rep Generated';
        o.Internal_Referral_lookup__c = c.id;
        o.CloseDate = System.today().addDays(15);
      	o.Epiq_Client_Code__c = 'TT';
        insert o;
        
        test.startTest();
        PageReference pageRef = Page.Pulse_CheckClientCode;
        pageRef.getParameters().put('opptyid',o.id);
        Test.setCurrentPage(pageRef);
        //ApexPages.StandardController con = new ApexPages.StandardController(o);      
        Pulse_ClientCodeController mycon = new Pulse_ClientCodeController();
        mycon.CheckCode();
        mycon.Cancel();
        test.stopTest();
  	}
}