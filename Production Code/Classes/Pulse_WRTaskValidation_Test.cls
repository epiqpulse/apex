@isTest
private class Pulse_WRTaskValidation_Test {
    static testMethod void WRTaskTest() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
     	container.createWorkRequests(true);
        container.findWorkRequestTasks();
        Pulse_Utils.setFieldToValue(container.testWorkRequests, 'Work_Request_Status__c', 'Cancelled');
        update container.testWorkRequests;        
    }
}