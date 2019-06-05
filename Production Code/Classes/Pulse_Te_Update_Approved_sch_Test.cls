@isTest
private class Pulse_Te_Update_Approved_sch_Test {
    static testMethod void Pulse_Te_Update_Approved_sch_Test(){            
        test.startTest();
        // Schedule the test job
        Pulse_Te_Update_Approved_sch obj = new Pulse_Te_Update_Approved_sch();
        String chron = '0 0 3 2 * ?';
        system.schedule('Test Sched', chron, obj);
        test.stopTest();
    }
}