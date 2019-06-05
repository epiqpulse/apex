trigger Pulse_Media_Trigger on EDiscovery_Media__c (before update) {
    
    boolean otherFieldsChanged = otherFieldsEdited();
    
    for(integer i = 0; i < trigger.new.size(); i++) {
        if(trigger.new[i].Media_Possession_CoC__c == 'Switch Tech') {           
            if(trigger.new[i].Technician__c == null)
                trigger.new[i].addError('Technician is required if Switch Tech is selected!');
            else {          
                if(trigger.new[i].Technician__c == trigger.old[i].Technician__c && !otherFieldsChanged) {
                    trigger.new[i].addError('Cannot save the update with the same technician!');
                }
            }           
        }
        if(trigger.new[i].Media_Possession_CoC__c == 'Storage Bin' && trigger.new[i].Bin_Number__c == null) {
            trigger.new[i].addError('Bin Number is required if Storage Bin is selected!');
        }
    }
    private boolean otherFieldsEdited() {
        boolean rval = false;               
        Map<String, Schema.SObjectField> mapFields = Schema.SObjectType.EDiscovery_Media__c.fields.getMap(); 
        
        for(EDiscovery_Media__c newMedia : trigger.new) {
            EDiscovery_Media__c oldMedia = trigger.oldMap.get(newMedia.Id);

            for (String str : mapFields.keyset()) { 
                try { 
                    if(newMedia.get(str) != oldMedia.get(str)) { 
                        rval = true;
                        return (rval); 
                    } 
                } 
                catch (Exception e)  { 
                    System.Debug('Error: ' + e); 
                } 
            }
        }
    
        return (rval);
    }
}