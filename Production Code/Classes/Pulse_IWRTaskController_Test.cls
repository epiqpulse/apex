@isTest
private class Pulse_IWRTaskController_Test {

    @isTest static void testPrevNextFirstButtons() {
        map<string, string> pageParams = ApexPages.currentPage().getParameters();
        String internalTaskParameterId = 'CF00Ne0000001yO35_lkid';
        String internalTaskNameParameterId = 'CF00Ne0000001yO35';         
        String internalworkRequestParameterId = 'CF00Ne0000001yMkB_lkid';
        String internalworkRequestNameParameterId = 'CF00Ne0000001yMkB';
        /* String dueDateParameterId = '00N0Z00000H3Adf'; */
        String taskOrderParameterId = '00Ne0000001yMkF';
        String taskTypeParameterId = '00Ne0000001yMkI';
        String urlAddition;

        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createInternalProjects(1, 'CI Project', true);
        container.createInternalWorkRequests(1, 'CI Work Request', true);
        container.findInternalWRTasks();
        
        list<Internal_WR_Task__c> IWRTasks = new list<Internal_WR_Task__c>();
        
        system.debug('internal wr id = ' + container.testInternalWorkRequests[0].id);
        Internal_WR_Task__c IWRT = new Internal_WR_Task__c();
        IWRT.Internal_Work_Request__c = container.testInternalWorkRequests[0].id;
        IWRT.Task_Order__c = 10;
        IWRT.Task_Type__c = 'Task1';
        IWRTasks.add(IWRT);
        
        system.debug('IWRT internal WR = ' + IWRT);
        
        Internal_WR_Task__c IWRT2 = new Internal_WR_Task__c();
        IWRT2.Internal_Work_Request__c = container.testInternalWorkRequests[0].id;
        IWRT2.Task_Order__c = 20;
        IWRT2.Task_Type__c = 'Task2';
        IWRTasks.add(IWRT2);
        
        system.debug('IWRT2 internal WR = ' + IWRT2);
        
        Internal_WR_Task__c IWRT3 = new Internal_WR_Task__c();
        IWRT3.Internal_Work_Request__c = container.testInternalWorkRequests[0].id;
        IWRT3.Task_Order__c = 30;
        IWRT3.Task_Type__c = 'Task3';
        IWRTasks.add(IWRT3);
        
        system.debug('IWRT3 internal WR = ' + IWRT3);
        
        insert IWRTasks;
        
        test.startTest();
          PageReference pageRef = Page.Pulse_IWRTaskview;
          pageRef.getParameters().put('internalTaskParameterId','CF00Ne0000001yO35_lkid'); 
          pageRef.getParameters().put('internalTaskNameParameterId','CF00Ne0000001yO35'); 
          pageRef.getParameters().put('internalworkRequestParameterId','CF00Ne0000001yMkB_lkid'); 
          pageRef.getParameters().put('internalworkRequestNameParameterId','CF00Ne0000001yMkB');
          pageRef.getParameters().put('taskOrderParameterId','00Ne0000001yMkF'); 
          pageRef.getParameters().put('taskTypeParameterId','00Ne0000001yMkI');
          pageRef.getParameters().put('id',IWRT2.id);
          pageRef.getParameters().put('retURL','returnURL');
          Test.setCurrentPage(pageRef);
          pageRef.getUrl();
          system.debug('current page =  ' + pageref);
          ApexPages.StandardController con = new ApexPages.StandardController(IWRT2);
          Pulse_IWRTaskController mycon = new Pulse_IWRTaskController(con);
                                        
          mycon.getCheckNext();
          mycon.getCheckPrevious();
          mycon.getCheckLast();
        
          mycon.doNext();
          mycon.doPrevious();
          mycon.doFirst();
          
          pageReference pr = mycon.redirect();
          urlAddition += '&' + internalworkRequestNameParameterId + '=' + container.testInternalWorkRequests[0].name;
          system.debug('urladdition = ' + urlAddition);
          
        test.stopTest(); 
    }
    
    // test the controller for the New task buttons tied to Internal Work Request
    @isTest static void testNewTaskButtonController() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createInternalProjects(1, 'CI Project', true);
        container.createInternalWorkRequests(1, 'CI Work Request', true);
        container.findInternalWRTasks();
        
        string taskTypeParam = '00Ne0000001yMkI';
        string taskOrderParam = '00Ne0000001yMkF';
        string iwrIdParam = 'CF00Ne0000001yMkB_lkid';
    	string iwrNameParam = 'CF00Ne0000001yMkB';
        string expectedRetURL = '/' + string.valueOf(container.testInternalWorkRequests[0].id);
		// setup the necessary pageReference and the initial Page Parameters
		// that would be accessible to the page
        PageReference pageRef = Page.NewInternalWRTask;
        pageRef.getParameters().put(iwrIdParam, container.testInternalWorkRequests[0].id);
        pageRef.getParameters().put(iwrNameParam, container.testInternalWorkRequests[0].Name);
        pageRef.getParameters().put('RecordType', container.testInternalWRTasks[0].RecordTypeId);
        pageRef.getParameters().put('retURL', expectedRetURL);
        Test.setCurrentPage(pageRef);
        // create the controller and set a value in the New Task Type field which is used to determine
        // what type of Task we are created at the users request.
        ApexPages.StandardController con = new ApexPages.StandardController(container.testInternalWRTasks[0]);
        Pulse_InternalWRTask_Controller mycon = new Pulse_InternalWRTask_Controller(con);
        mycon.iwrTask.New_Task_Type__c = container.testInternalWRTasks[0].Task_Type__c;
        mycon.newTask();
        // the New_Task_Type field value is selected by the user and used to populate the Task Type on the new record
        system.assertEquals(mycon.iwrTask.New_Task_Type__c, mycon.iwrTask.Task_Type__c);
        // the page reference returned by the cancel method matches that stored in the return url page parameter
        system.assert(string.valueOf(mycon.cancel()).contains(expectedRetURL));
    }
    
    // test Internal WR Task status update buttons
    @isTest static void testIWRTaskStatusUpdateButtonController() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createInternalProjects(1, 'CI Project', true);
        container.createInternalWorkRequests(1, 'CI Work Request', true);
        container.findInternalWRTasks();

        ApexPages.StandardSetController setController = new ApexPages.StandardSetController(container.testInternalWRTasks);
        Pulse_IWRTask_Workflow_Controller myController = new Pulse_IWRTask_Workflow_Controller(setController);
        // set selected in the list of Internal Work Request Tasks then use the controller extension methods
        // to update the status of all of them to 'Started' and save the change.
        setController.setSelected(container.testInternalWRTasks);
        myController.updateIWRTaskStatus('Started');
        myController.updateTasks();
        // requery the tasks in the container and assert they are all started.
        container.findInternalWRTasks();
        for(Internal_WR_Task__c eachIWRTask : container.testInternalWRTasks) {
            system.assertEquals('Started', eachIWRTask.Status__c);
        }
        
        Pulse_IWRTask_Workflow_Controller.updateIndividaulIWRTStatus(string.valueOf(container.testInternalWRTasks[0].Id), 'Cancelled');
        // requery the tasks in the container and assert the first record in the list is now 'Cancelled'.
        container.findInternalWRTasks();
        system.assertEquals('Cancelled', container.testInternalWRTasks[0].Status__c);
        // the below update will fail because the picklist is restricted so the status of that first task will remain 'Cancelled'.
        Pulse_IWRTask_Workflow_Controller.updateIndividaulIWRTStatus(string.valueOf(container.testInternalWRTasks[0].Id), 'Stopped');
        // requery the tasks in the container and assert the first record in the list is still 'Cancelled'.
        container.findInternalWRTasks();
        system.assertEquals('Cancelled', container.testInternalWRTasks[0].Status__c);
    }
    
    @isTest static void testIWRTaskMassUpdateButtonController() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container();
        container.createInternalProjects(1, 'CI Project', true);
        container.createInternalWorkRequests(1, 'CI Work Request', true);
        container.findInternalWRTasks();
        
        string expectedRetURL = '/' + string.valueOf(container.testInternalWorkRequests[0].id);
        PageReference pageRef = Page.MassEditInternalWRTasks;
        pageRef.getParameters().put('id', container.testInternalWorkRequests[0].id);
        pageRef.getParameters().put('retURL', expectedRetURL);
        Test.setCurrentPage(pageRef);

        ApexPages.StandardSetController setController = new ApexPages.StandardSetController(container.testInternalWRTasks);
        Pulse_iwrTasksMassEditController myController = new Pulse_iwrTasksMassEditController();
        system.assert(!myController.getTasks().isEmpty());
        double taskOrderNumber = 1;
        // set the Task Order for the tasks in the controller to consecutive numbers starting at 1
        for(Internal_WR_Task__c iWRTask : myController.getTasks()) {
            iWRTask.Task_Order__c = taskOrderNumber;
            taskOrderNumber++;
        }
        // save the changes from above using the standard save and verify
        // that it returns the url for the Internal Work Request detail page
        system.assert(string.valueOf(myController.save()).contains(expectedRetURL));
        // validate that the standard cancel returns the expected url
        system.assert(string.valueOf(myController.cancel()).contains(expectedRetURL));
        container.findInternalWRTasks();
        taskOrderNumber = 1;
        for(Internal_WR_Task__c eachIWRTask : container.testInternalWRTasks) {
            system.assertEquals(taskOrderNumber, eachIWRTask.Task_Order__c);
            taskOrderNumber++;
        }
    }
}