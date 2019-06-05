// W-000972 This trigger will make a chatter post on the WR when the WR Instruction fields are
// changed after a WR has been submitted

trigger Pulse_WRInstructionTrigger on Work_Request_Instruction__c (after update) {

	string postText = '';
	string InstructionType = '';
    list<Id> wrIds = new list<Id>();
    list<Work_Request_Instruction__c> wrInstructions = new list<Work_Request_Instruction__c>();
    list<Ediscovery_WorkRequest__c> wrList;
    Work_Request_Instruction__c oldWRI;
    
    Map<String, Schema.SObjectField> mapFields = Schema.SObjectType.Work_Request_Instruction__c.fields.getMap(); 
        
    for(Work_Request_Instruction__c WRI : trigger.new) {
        wrInstructions.add(WRI);
        wrIds.add(WRI.Work_Request__c);
    }
    
    //system.debug('*** wrIds: ' + wrIds);
    
    wrList = [Select Id, Work_Request_Status__c, Project_Code__c, WorkRequest__c from EDiscovery_WorkRequest__c where Id in :wrIds];
    
    system.debug('*** IwrList: ' + wrList);
    
    for(EDiscovery_WorkRequest__c wr : wrList) {
        if (wr.Work_Request_Status__c <> 'Pre-Submission') {
            
            for(Work_Request_Instruction__c newWRI : wrInstructions) {
                if (newWRI.Work_Request__c == wr.id) {
                    
                    oldWRI = trigger.oldMap.get(newWRI.Id);
                    InstructionType = newWRI.Instruction_Type__c;
                    for (String str : mapFields.keyset()) { 
                		try { 
                    		if((newWRI.get(str) != oldWRI.get(str)) && str != 'lastmodifieddate' && str != 'systemmodstamp') { 
								postText = postText + '\n' + str + ' has changed from ' + oldWRI.get(str) + ' to ' + newWRI.get(str);
                    		} 
                		} 
                      	catch (Exception e)  { 
                    		System.Debug('Error: ' + e); 
                		}	 
                                
                	}
            	}
        	}
            
			//post to WR chatter     
			FeedItem post = new FeedItem();
			post.ParentId = wr.id; 
			post.Body = wr.Project_Code__c + ' - '+ wr.WorkRequest__c + '\n' + '#[EMS WR Instruction Change]' + '\n' + system.Now() + '\n' + InstructionType + '\n' + postText;
			insert post;
            
            postText = '';
            
    	}
    }
    
}