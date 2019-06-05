@isTest
public class Pulse_WRInstructionTrigger_Test {
    
    static testMethod void WRInstructionTriggerTest() {
    
    	list<RecordType> RecordTypes = Pulse_Test_Helpers.CreateRecordTypeListEMS();
    	Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1);
		set<string> projIds = Pulse_Utils.getFieldValueSet(container.discoPros, 'Id');
    	list<EDiscovery_Project__c> projects = [select Id from EDiscovery_Project__c where id in : projIds];
    	list<EDiscovery_PricingItems__c> pricingItems = [select Id from EDiscovery_PricingItems__c where Available_for_Data_Center__c = true];
    	list<EDiscovery_PricingLibrary__c> pricingLibEntries = [select Id from EDiscovery_PricingLibrary__c where Project__c in : projIds];
        
    	list<WR_Task_Settings__c> WRTaskSettings = Pulse_Test_Helpers.CreateTaskSettings(1);
    
    	EDiscovery_WorkRequest__c wr = new EDiscovery_WorkRequest__c();
		wr.Project__c = projects[0].id;
    	wr.RecordTypeId = RecordTypes[0].Id;  // EMS
    	//system.debug('RecordType: ' + RecordTypes[0].Id);
    	wr.Name__c = 'ControllerTest';
    	wr.Requested_Time__c = System.today().addDays(2);
    	wr.Work_Request_Status__c = 'Submitted';        
    	insert wr;
        
        Work_Request_Instruction__c WRI = new Work_Request_Instruction__c();
        WRI.Work_Request__c = wr.Id;
        WRI.Instruction_Order__c = 10;
        insert WRI;
        
        WRI.Special_Instructions__c = 'Test';
        update WRI;
        
    }
    
}