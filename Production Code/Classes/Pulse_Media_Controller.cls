global class Pulse_Media_Controller 
{

    String mediaId {get;set;}
    public Ediscovery_Media__c mediaObj {get;set;}
    public list<Chain_of_Custody_Action__c> custodyActions {get;set;}
    public String message {get;set;}
    public string retUrl;
    public string oldEvidenceLocation;
    public list<User> oldOwnerList;
    public User oldOwner;
    public string oldOwnerString;
    public list<User> newOwnerList;
    public User newOwner;
    public string newOwnerString;
    public string newOwnerId;
    public string oldMediaPossession;
    public string oldBinNumber;
    public string fromString;
    public string caRecordFromString;
    public string toString;
    public string caRecordToString;
    
    
    public Pulse_Media_Controller(ApexPages.StandardController controller) 
    {
       retUrl = ApexPages.currentPage().getParameters().get('id');
        
       mediaId = controller.getRecord().Id;
       if(mediaId != NULL) {         
         mediaObj = [SELECT Custody_Action_Date__c,Bin_Number__c,Evidence_Location__c,
                     Id,Media_Possession_CoC__c,CreatedDate,OwnerId,Owner.Name,Notes__c,
                     Switch_Tech_Reason__c,COC__c,Custody_Action_Notes__c,Collector__c 
                     FROM EDiscovery_Media__c WHERE id=:mediaId];
         custodyActions = getCustodyActions();
       }
        // clear the contents of the notes field every time a new action is taken
        mediaObj.Custody_Action_Notes__c = '';
        mediaObj.Custody_Action_Date__c = DateTime.now();
        
        oldEvidenceLocation = mediaObj.Evidence_Location__c;
        oldOwnerList = [select FirstName,LastName from User where Id = :mediaObj.OwnerId];
        if (oldOwnerList.size() == 1) {
            oldOwner = oldOwnerList.get(0);
            oldOwnerString = oldOwner.FirstName + ' ' + oldOwner.LastName;
        }
        else {
            oldOwnerString = '';
        }
                    
        oldMediaPossession = '';
        oldBinNumber = '';
        oldMediaPossession = mediaObj.Media_Possession_CoC__c;
        oldBinNumber = mediaObj.Bin_Number__c;
    }
    
 
    
   //Method for Saving the Custom Object Record
   public PageReference saveMediaRecord(){
      try
      {
        newOwnerList = [select FirstName,LastName from User where Id = :mediaObj.OwnerId];
        
        if (newOwnerList.size() == 1)
        {
            newOwner = newOwnerList.get(0);
            newOwnerString = newOwner.FirstName + ' ' + newOwner.LastName;
        }
        else
        {
            newOwnerString = '';
        }
        // Owner must be a Queue or the current user, or the Media_Possession_CoC must be 'Shipped'
        string message = displayValidationError();
        if(!string.isBlank(message)) { 
            ApexPages.addMessage( new ApexPages.Message(ApexPages.Severity.ERROR, message));
            return null;
        }
          
          if (oldMediaPossession == 'Storage Bin') {
              caRecordFromString = 'Transferred from|' + oldEvidenceLocation + '|' + oldMediaPossession + '|' + oldBinNumber;
              fromString = oldEvidenceLocation + '|' + oldMediaPossession + '|' + oldBinNumber;
          }
          else {
              caRecordFromString = 'Transferred from|' + oldEvidenceLocation + '|' + oldMediaPossession + '|' + oldOwnerString;
              fromString = mediaObj.Evidence_Location__c + '|' + oldMediaPossession + '|' + oldOwnerString;
          }
          if (mediaObj.Media_Possession_CoC__c == 'Storage Bin') {
              caRecordToString = ' to|' + mediaObj.Evidence_Location__c + '|' + mediaObj.Media_Possession_CoC__c + '|' + mediaObj.Bin_Number__c;
              toString = mediaObj.Evidence_Location__c + '|' + mediaObj.Media_Possession_CoC__c + '|' + mediaObj.Bin_Number__c;
          } else {
                if (mediaObj.Media_Possession_CoC__c == 'Shipped') {  
                    caRecordToString = 'Shipped to|' + mediaObj.Evidence_Location__c + '|' + newOwnerString;
                    toString = 'Shipped to ' + newOwnerString;
                } else {
                    caRecordToString = ' to|' + mediaObj.Evidence_Location__c + '|' + mediaObj.Media_Possession_CoC__c + '|' + newOwnerString;
                    toString = mediaObj.Evidence_Location__c + '|' + mediaObj.Media_Possession_CoC__c + '|' + newOwnerString;
                }
                mediaObj.Bin_Number__c = '';
          }
          
          if(mediaObj.Custody_Action_Notes__c != null) {
              mediaObj.COC__c = mediaObj.Custody_Action_Date__c.format('yyyy-MM-dd hh:mm a') + '|' +fromString + '|' + toString + '|' + mediaObj.Switch_Tech_Reason__c + '|' + mediaObj.Custody_Action_Notes__c;
          }
          else
              mediaObj.COC__c = mediaObj.Custody_Action_Date__c.format('yyyy-MM-dd hh:mm a') + '|' + fromString + '|' + toString + '|' + mediaObj.Switch_Tech_Reason__c + '|';
              
        update mediaObj;
        createChainofCustodyActivityRecord(caRecordFromString, caRecordToString, mediaObj.Switch_Tech_Reason__c, mediaObj.Custody_Action_Notes__c);            
      
        
        PageReference nextpage= new PageReference('/'+mediaObj.id);
        return nextpage;
      }
      catch(Exception e){
            string errorMessage = e.getMessage();
            string tag = 'EXCEPTION, ';
            if(errorMessage.contains(tag)){
                errorMessage = Pulse_Utils.trimErrorMessage(errorMessage, tag);
            }
            message = 'Database error during saving...' + errorMessage;
            ApexPages.addMessage( new ApexPages.Message(ApexPages.Severity.ERROR, message));
            return null;
        }
    }
    
    public string displayValidationError() {
        string message = '';
        // media possession field validation
        switch on mediaObj.Media_Possession_CoC__c {
            when null { message = 'Media Possession (CoC) cannot be null!'; }
            when 'Remote' { message = 'Remote is not a valid COC action!'; }
            when else {} 
        }
        // owner validation. unless Media_Possession_CoC__c is 'Shipped' the media must be owned by
        // a Queue or the current user.
        if(!string.valueOf(mediaObj.OwnerId).startsWith('00G') && 
           mediaObj.OwnerId != UserInfo.getUserId() &&  
           mediaObj.Media_Possession_CoC__c != 'Shipped'){
                message = 'Only the logged in user may be take possession of Media!';        
        }
        // Custody Action Date validation
        if(mediaObj.Custody_Action_Date__c == null || mediaObj.Custody_Action_Date__c > DateTime.now()) {
            message = 'Custody Action Date is required, and cannot be in the future!';
        }
        // Reason validation
        if(mediaObj.Switch_Tech_Reason__c == null){
            message = 'Reason cannot be null!';
        }        
        return message;
    }
    
    public list<Chain_of_Custody_Action__c> getCustodyActions(){
        list<Chain_of_Custody_Action__c> custodyActionsFound = [select Attachments__c, Bin_Number__c, CoC_Notes__c, CoC_Time__c, Courier__c, Custody_Action_Date__c, 
                           Description_and_Note_on_Media__c, Evidence_Location__c, Media_Classification__c, Media_Description__c, 
                           Media_Possession_CoC__c, Media_Owner__c, Purpose__c, Received_By__c, Released_By__c, Tracking_Number__c 
                           from Chain_of_Custody_Action__c where Media_ID__c = : mediaId order by Custody_Action_Date__c Desc];
        list<Chain_of_Custody_Action__c> newActions = new list<Chain_of_Custody_Action__c>();
        if(custodyActionsFound.isEmpty()) {
            string recBy = (!string.isBlank(mediaObj.Collector__c)? mediaObj.Collector__c : UserInfo.getFirstName() + ' ' + UserInfo.getLastName());
            newActions.add(new Chain_of_Custody_Action__c(Media_ID__c = mediaId, 
                                                          Custody_Action_Date__c = mediaObj.CreatedDate,
                                                          Purpose__c = 'Acquisition of Item',
                                                          Released_By__c = 'N/A',
                                                          Received_By__c = recBy));
        }
        return newActions;
    }
    
    public void createChainofCustodyActivityRecord(string fromString, string toString, string reason, string notes) {
        Chain_of_Custody_Action__c newAction = new Chain_of_Custody_Action__c(Media_ID__c = mediaId, Custody_Action_Date__c = mediaObj.Custody_Action_Date__c,
                                                      Description_and_Note_on_Media__c = mediaObj.Media_Description__c + '/n' + mediaObj.Notes__c);
     
        if(!string.isEmpty(fromString)) newAction.Released_By__c = fromString.replace('|', '\n');
        if(!string.isEmpty(toString)) newAction.Received_By__c = toString.replace('|', '\n');
        if(!string.isEmpty(reason)) newAction.Purpose__c = reason;
        if(!string.isEmpty(notes)) newAction.CoC_Notes__c = notes;
        system.debug(newAction.Released_By__c);
        system.debug(newAction.Received_By__c);
        custodyActions.add(newAction);
        insert custodyActions;
    }
    
    
    public PageReference returnToMedia()
    {
        PageReference result = new PageReference('/' + retUrl);
        return result;
    }
    
    WebService static String SendEmailNotification(String MediaID) {
        
        //system.debug('*** MediaID:' + MediaID);
        
        List<Messaging.SingleEmailMessage> mails =  new List<Messaging.SingleEmailMessage>();
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        List<String> sendTo = new List<String>();
        
        EDiscovery_Media__c media;
        list<EDiscovery_Media__c> Medias = [SELECT Id,Name,Media_Arrival_Path__c,Project__c,Media_Type__c,Media_Description__c,Client_Label__c,Media_Staging_Path__c,Native_File_Size_In_GB__c,Native_File_Count__c,ESI_Project_Code__c,Project_name__c,Shipped_By__c,Sent_To__c,Tracking_Number__c,Date_Recieved__c FROM EDiscovery_Media__c Where Id=:MediaID];
        media = Medias[0];
        
        EDiscovery_Project__c prj;
        list<EDiscovery_Project__c> Projects = [SELECT Id,Project_Email_Distribution_List_Name__c,Primary_PM_email_address__c,Secondary_PM_email_address__c,Alternate_PM_email_address__c FROM EDiscovery_Project__c Where Id=:Media.Project__c];
        prj = Projects[0];
        if (prj.Project_Email_Distribution_List_Name__c <> null) {
            sendTo.add(prj.Project_Email_Distribution_List_Name__c);
        }
        if (prj.Alternate_PM_email_address__c <> null) {
            sendTo.add(prj.Alternate_PM_email_address__c);
        }
        if (prj.Primary_PM_email_address__c <> null) {
            sendTo.add(prj.Primary_PM_email_address__c);
        }
        if (prj.Secondary_PM_email_address__c <> null) {
            sendTo.add(prj.Secondary_PM_email_address__c);
        }
        
        if (sendTo.size() > 0) {
            //sendTo.add('ckoe@epiqglobal.com');
            mail.setToAddresses(sendTo);
            mail.setReplyTo('no-reply@epiqglobal.com');
            mail.setSenderDisplayName('Media Notifications');
            mail.setSubject(media.ESI_Project_Code__c + ' ' + media.Project_name__c + ':' + media.Name);
            String body = 'Media ID: ' + media.Name + '<br/><br/>' + '<a href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+media.id+'">'+media.Name+'</a>' + '<br/><br/>Media Type: ' + media.Media_Type__c + '<br/><br/>Client Label: ' + media.Client_Label__c   + '<br/><br/>Media Staging Path: ' + media.Media_Staging_Path__c + '<br/><br/>Media Arrival Path: ' + media.Media_Arrival_Path__c + '<br/><br/>Native File Size In GB: ' + media.Native_File_Size_In_GB__c + '<br/><br/>Native File Count: ' + media.Native_File_Count__c + '<br/><br/>Shipped By: ' + media.Shipped_By__c + '<br/><br/>Sent To: ' + media.Sent_To__c + '<br/><br/>Tracking Number: ' + media.Tracking_Number__c + '<br/><br/>Date Received: ' + media.Date_Recieved__c + '<br/><br/>Description: ' + media.Media_Description__c;
                                   
            system.debug('*** Notification Send To:' + sendTo);
            mail.setHtmlBody(body);
            mail.saveAsActivity = false;
            mails.add(mail);
            //Messaging.sendEmail(mails);
            return ('Media Notification Email has been sent');
        } else {
            return ('No PMs Have been defined on the Project');
        }
    }
}