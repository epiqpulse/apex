@isTest
public class Pulse_ProjectGetProjectCode_Test {
    private static testMethod void testProjectCode() {
		Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(3, false);
		insert container.discoPros[0];
        container.testOpportunity.Region__c = 'Europe';
        container.testOpportunity.SAP_Client_Name__c = 'EUTest';
        update container.testOpportunity;
        
        container.discoPros[1].SAP_Contract_ID__c = '111ABC';
        container.discoPros[2].SAP_Contract_ID__c = '111ABCD';
		insert container.discoPros[1];
        insert container.discoPros[2];
    }
    
    private static testMethod void testProjectCodeNoESIProjectCode() {
		Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(3, false);
		insert container.discoPros[0];
        container.testOpportunity.Region__c = 'Europe';
        container.testOpportunity.SAP_Client_Name__c = 'EUTest';
        update container.testOpportunity;
        
        container.discoPros[1].SAP_Contract_ID__c = '111ABCD';
        container.discoPros[2].SAP_Contract_ID__c = '111ABCE';
        container.discoPros[2].ESI_Project_Code__c = null;
        
		insert container.discoPros[1];
        insert container.discoPros[2];      
    }
    
    private static testMethod void testProjectCodeNoClientCodeonOpp() {
		Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(3, false);
		insert container.discoPros[0];
        container.testOpportunity.Region__c = 'Europe';
        container.testOpportunity.SAP_Client_Name__c = 'EUTest';
        update container.testOpportunity;
        
        container.discoPros[1].SAP_Contract_ID__c = '111ABC';
        container.discoPros[2].SAP_Contract_ID__c = '111ABCD';
		insert container.discoPros[1];
        
        try{
            // need to null out the Client Code on Opportunity, so that the
            // Project insert will error out.
            container.testOpportunity.Epiq_Client_Code__c = null;
            update container.testOpportunity;
        	insert container.discoPros[2];
        } catch(Exception exc){
            system.assert(exc.getMessage().contains('Cannot create or edit the ESI project without a Client Code and SAP Client Name on the Opportunity!'));
        }
    }
    
    private static testMethod void testMultipleOppsWithSameClientCode(){
		// begin by creating an Opp/Project and inserting both.
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, false);
        container.discoPros[0].ESI_Project_Code__c = null;
        insert container.discoPros[0];
        test.startTest();
        // Now use the container class methods to create a new Opportunity that will have the same client code
        // and a Project associated to that.
        container.createOpportunity();
        container.createProjects(1, false);
        container.discoPros[0].ESI_Project_Code__c = null;
		container.discoPros[0].SAP_Contract_ID__c= '111';
        insert container.discoPros[0];
        addLetterToProjectCode(container);
        container.createOpportunity();
        container.createProjects(1, false);
        container.discoPros[0].ESI_Project_Code__c = null;
		container.discoPros[0].SAP_Contract_ID__c= '111';
        insert container.discoPros[0];
        container.createOpportunity();
        container.createProjects(1, false);
        container.discoPros[0].ESI_Project_Code__c = null;
		container.discoPros[0].SAP_Contract_ID__c= '111';
        insert container.discoPros[0];
        test.stopTest();
        list<string> expectedProjectCodes = new list<string>{'ZZZ0001', 'ZZZ0002M', 'ZZZ0003', 'ZZZ0004'};
        set<string> foundProjectCodes = new set<string>();
        for(EDiscovery_Project__c each : [select Id, ESI_Project_Code__c from EDiscovery_Project__c]){
            system.assert(!foundProjectCodes.contains(each.ESI_Project_Code__c));
            system.assert(expectedProjectCodes.contains(each.ESI_Project_Code__c));
            foundProjectCodes.add(each.ESI_Project_Code__c);
        }
    }
    
    private static void addLetterToProjectCode(Pulse_Test_Helpers.Test_Container container){
        list<EDiscovery_Project__c> pro = [select Id, ESI_Project_Code__c from EDiscovery_Project__c where Id in : container.discoPros];
        for(EDiscovery_Project__c each : pro){
            each.ESI_Project_Code__c = each.ESI_Project_Code__c + 'M';
        }
        update pro;
    }
    
    // this test is to verify a fix for a bug where ESI Project Codes with differing
    // amounts of padding preceeding their incremented number would cause the code to not
    // increment correctly and inserting Projects would fail due to a duplicate code existing.
    private static testMethod void testMultipleOppsWithDifferingPadding(){
        list<string> ProjectCodes = new list<string>{'ZZZ0001', 'ZZZ0002', 'ZZZ0003', 'ZZZ004', 'ZZZ005'};
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(5, true);
		// update the Projects with a mix of different padded Project Codes from the list above.
        for(integer x = 0; x < ProjectCodes.size(); x++){
            container.discoPros[x].ESI_Project_Code__c = ProjectCodes[x];
        }
        update container.discoPros;
        
        // create an additional project it should get the Project Code we add to the list below.
        container.createProjects(1, false);
        container.discoPros[0].ESI_Project_Code__c = null;
        insert container.discoPros;
        
        ProjectCodes.add('ZZZ0006'); // add a Project Code to check for on the inserted Projects
        list<EDiscovery_Project__c> projectsCreated = [select Id, ESI_Project_Code__c from EDiscovery_Project__c];
        system.assertEquals(ProjectCodes.size(), projectsCreated.size());
        for(EDiscovery_Project__c each : projectsCreated){ // 		loop through each Project and remove the code that matches from
            for(integer x = 0; x < ProjectCodes.size(); x++){ // 	the list of project codes. this prevents us from iterating over matched codes multiple times
                if(each.ESI_Project_Code__c == ProjectCodes[x]){
                    string matched = ProjectCodes.remove(x);
                    break;
                }
            }
        }
        system.assertEquals(0, ProjectCodes.size()); // should have found matches for and removed every entry from this list.
	}

}