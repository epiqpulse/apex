@isTest
private class Pulse_WRTrigger_Test {

    // test that the Work request trigger appropriately sets the Headline field based on the 
    // value of either ITAR_Project__c or HIPAA_Project__c on the parent Project.
    static testMethod void testWorkRequestHeadline() {
    	Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(2, false);
        container.discoPros[0].ITAR_Project__c = 'Yes';
        container.discoPros[1].HIPAA_Project__c = 'Yes';
        insert container.discoPros;
        test.startTest();
        container.createWorkRequests(false);
        for(EDiscovery_WorkRequest__c each : container.testWorkRequests) each.Headline__c = '_testHeadline_';
        insert container.testWorkRequests;
		test.stopTest();
        // add counts and assert that half of the Work Requests have each Headline to assert each are present
        integer countHIPAA = 0;
        integer countITAR = 0;
        // query for the inserted Work Requests and assert that the Headline__c field for each was populated appropriately
        // also increment each count when hit to assert later for positive values.
        for(EDiscovery_WorkRequest__c each : [select Id, Project__r.ITAR_Project__c, Project__r.HIPAA_Project__c, Headline__c 
                                              from EDiscovery_WorkRequest__c where Id in : container.testWorkRequests]){
            if(each.Project__r.ITAR_Project__c == 'Yes'){
                countITAR++;
            	system.assert(each.Headline__c.startsWithIgnoreCase('*** ITAR ***'));
            } else if(each.Project__r.HIPAA_Project__c == 'Yes'){
                countHIPAA++;
                system.assert(each.Headline__c.startsWithIgnoreCase('*** HIPAA ***'));
            } else {
                // each of the Projects found in the test should meet one of the two above criteria
                system.assert(false);
            }
        }
        system.assertEquals(countHIPAA, countITAR);
        system.assertEquals(container.testWorkRequests.size()/2, countHIPAA);
        system.assertEquals(container.testWorkRequests.size()/2, countITAR);
    }
    
}