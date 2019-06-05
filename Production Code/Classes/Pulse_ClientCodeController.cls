public class Pulse_ClientCodeController {
	public string ClientCode {get; set;}
    public string pageId {get; set;}
    
    public Pulse_ClientCodeController() {
        pageId = ApexPages.currentPage().getParameters().get('opptyid'); 
    }
    public Pagereference CheckCode() {
        if(ClientCode != '') {
            list<Opportunity> opptys = [Select ID, Epiq_Client_Code__c from Opportunity where Epiq_Client_Code__c = :ClientCode];
            if(opptys.size() > 0)
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Client code already exists!'));
            else
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Client code DOES NOT exist!'));
        }
        else
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please first enter a client code to check!'));
        return null;
    }
    
    public Pagereference Cancel() {
        pagereference p = new pageReference('/'+pageId);
        return p;
    }  
}