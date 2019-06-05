public with sharing class Pulse_WRInstructionController {
    Public Integer size{get;set;}
    private Work_Request_Instruction__c currentRecord;
    public String idTask {get; set;}
    private ApexPages.StandardController stdController;
    
    public Pulse_WRInstructionController(ApexPages.StandardController controller) {
        stdController = controller;    
        idTask = ApexPages.currentPage().getParameters().get('id');
    }
    
    //Created a public boolean for to check if exist next or previuos record and for check if we are viewing the first or last record

    public boolean getCheckNext() {
        Work_Request_Instruction__c RTActual = [SELECT Name, Instruction_Order__c, work_request__c FROM Work_Request_Instruction__c WHERE Id = :idTask LIMIT 1];
        List<Work_Request_Instruction__c> TaskNext = [SELECT Id, Instruction_Order__c, work_request__c FROM Work_Request_Instruction__c WHERE Instruction_Order__c > :RTActual.Instruction_Order__c AND Instruction_Order__c != null AND Work_request__c =:RTActual.Work_Request__c ORDER BY Instruction_Order__c ASC LIMIT 1];
        if (TaskNext.size() > 0 && RTActual.Instruction_Order__c != null){
            return true;
        }
        return false;
    }

    public boolean getCheckPrevious() {
        Work_Request_Instruction__c RTActual = [SELECT Name, Instruction_Order__c, work_request__c FROM Work_Request_Instruction__c WHERE Id = :idTask LIMIT 1];
        List<Work_Request_Instruction__c> WRtaskPrevious = [SELECT Id, Instruction_Order__c, work_request__c FROM Work_Request_Instruction__c WHERE Instruction_Order__c < :RTActual.Instruction_Order__c AND Instruction_Order__c != null AND Work_request__c =:RTActual.Work_Request__c ORDER BY Instruction_Order__c ASC LIMIT 1];
        if (WRtaskPrevious.size() > 0 && RTActual.Instruction_Order__c != null){
            return true;
        }
        return false;
    }

    public boolean getCheckLast() {
        Work_Request_Instruction__c RTActual = [SELECT Name, Instruction_Order__c, work_request__c FROM Work_Request_Instruction__c WHERE Id = :idTask LIMIT 1];
        List<Work_Request_Instruction__c> TaskNext = [SELECT Id, instruction_order__c, work_request__c FROM Work_Request_Instruction__c WHERE Instruction_Order__c > :RTActual.Instruction_Order__c AND Instruction_Order__c != null AND Work_request__c =:RTActual.Work_Request__c ORDER BY Instruction_Order__c ASC LIMIT 1];
        if (TaskNext.size() == 0 && RTActual.Instruction_Order__c != null){
            return true;
        }
        return false;
    }
// End Public boolean checks


//Create "public pagereference" for viewing the next, previous or the first record

    public PageReference doNext(){
        Work_Request_Instruction__c RTActual = [SELECT Name, Instruction_Order__c, work_request__c FROM Work_Request_Instruction__c WHERE Id = :idTask LIMIT 1];
        
        Work_Request_Instruction__c TaskNext = [SELECT Id, Instruction_Order__c FROM Work_Request_Instruction__c WHERE Instruction_Order__c > :RTActual.Instruction_Order__c AND Instruction_Order__c != null AND Work_request__c =:RTActual.Work_Request__c ORDER BY Instruction_Order__c ASC LIMIT 1];
  
        PageReference pageRef = new PageReference('/apex/Pulse_WRInstructionView?id=' + TaskNext.id);
        pageRef.setRedirect(true);
        return pageRef; 
    }

    public PageReference doPrevious(){
        Work_Request_Instruction__c RTActual = [SELECT Name, Instruction_Order__c, work_request__c FROM Work_Request_Instruction__c WHERE Id = :idTask LIMIT 1];        

        Work_Request_Instruction__c TaskNext = [SELECT Id, Instruction_Order__c FROM Work_Request_Instruction__c WHERE Instruction_Order__c < :RTActual.Instruction_Order__c  and Instruction_Order__c != null AND Work_request__c =:RTActual.Work_Request__c ORDER BY Instruction_Order__c DESC LIMIT 1];
  
        PageReference pageRef = new PageReference('/apex/Pulse_WRInstructionView?id=' + TaskNext.id);
        pageRef.setRedirect(true);
        return pageRef; 
    }

    public PageReference doFirst(){
        Work_Request_Instruction__c RTActual = [SELECT Name, Instruction_Order__c, work_request__c FROM Work_Request_Instruction__c WHERE Id = :idTask LIMIT 1];
        Work_Request_Instruction__c TaskNext = [SELECT Id, Instruction_Order__c, Work_Request__c FROM Work_Request_Instruction__c WHERE Instruction_Order__c != null AND Work_request__c =:RTActual.Work_Request__c ORDER BY Instruction_Order__c ASC LIMIT 1];
  
        PageReference pageRef = new PageReference('/apex/Pulse_WRInstructionView?id=' + TaskNext.Id);
        pageRef.setRedirect(true);
        return pageRef; 
    }

}