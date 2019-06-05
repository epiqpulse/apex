@isTest
public class Pulse_ChatterCommentTrigger_Test {
  private static testmethod void testchatterAttachments() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1,true);
        FeedItem newChatter = new FeedItem( Body='this is a base comment', ParentId=container.DiscoPros[0].Id);
        insert newChatter;
        FeedComment textComment = new FeedComment(CommentBody='Good stuff, text only.', FeedItemId = newChatter.Id, CommentType= 'TextComment');
        FeedComment contentComment = new FeedComment(CommentBody='Bad news, I added a file.', FeedItemId = newChatter.Id, CommentType= 'ContentComment');
        test.startTest();
            try{
                insert textComment;
            } catch(Exception exc) {
                system.assert(false, 'Post failed unexpectedly: ' + exc.getMessage());
            }
            try{
                insert contentComment;
                system.assert(false, 'Post succeeded unexpectedly...');
            } catch(Exception exc) {
                system.assert(exc.getMessage().contains('Uploading content is not allowed in Chatter comments.'));
            }
        test.stopTest();
   }
   
   private static testmethod void testwrtask() {
        Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1, true);
        list<RecordType> RecordTypes = Pulse_Test_Helpers.CreateRecordTypeList();
        list<EDiscovery_WorkRequest__c> WorkRequests = new list<EDiscovery_WorkRequest__c>();
    
        list<Id> wrIds = new list<Id>();
        EDiscovery_WorkRequest__c wr = new EDiscovery_WorkRequest__c();
        wr.OwnerID = userInfo.getUserId();
        wr.Project__c = container.discoPros[0].Id;
        wr.RecordTypeId = RecordTypes[0].Id;  
        wr.Name__c = 'ControllerTest';
        wr.Work_Request_Status__c = 'Pre-Submission';
        WorkRequests.add(wr);
        
        insert WorkRequests;
        
   
        list<EDiscovery_WR_Task__c> WRTasks = new list<EDiscovery_WR_Task__c>();
        EDiscovery_WR_Task__c WRT1 = new EDiscovery_WR_Task__c();
        WRT1.Work_Request__c = wr.Id;
        WRT1.Task_Order__c = 10;
        WRT1.Task_Type__c = 'Task1';
        WRT1.WR_Chatter_ID__c = wr.id;
        WRT1.WR_Chatter_Comment__c  = 'Test';
        WRT1.WR_chatter_Last_Updated_By__c = 'Me';
        WRTasks.add(WRT1);
        
        insert WRTasks;
       // Pulse_Test_Helpers.Test_Container container = new Pulse_Test_Helpers.Test_Container(1,true);
       // container.createWorkRequests(true);
        
        FeedItem newChatter = new FeedItem( Body='this is a base comment', ParentId=wr.id);
        insert newChatter;
       // container.findWorkRequestTasks();
        FeedComment textComment = new FeedComment(CommentBody='Good stuff, text only.', FeedItemId = newChatter.Id, CommentType= 'TextComment');
        test.startTest();
            try{
              insert textComment;
            } catch(Exception exc) {
                system.assert(false, 'Post failed unexpectedly: ' + exc.getMessage());
            }
            
        List<EDiscovery_WR_Task__c> WRTLTU = new List<EDiscovery_WR_Task__c>(); 
        string uid = userinfo.getUsername();
        string fcpid = string.valueof(FeedComment.parentID); //.substring(0,15);
                        
        List<EDiscovery_WR_Task__c> WRTLTQ = [Select Id, Work_Request_ID__c from EDiscovery_WR_Task__c where WR_Chatter_Id__c = :wr.id Limit 1];
    
        if(WRTLTQ != null) {
           for(EDiscovery_WR_Task__c wrt : WRTLTQ) {
               wrt.WR_Chatter_ID__c = fcpid;
               wrt.WR_Chatter_Comment__c = wrt.wr_chatter_comment__c;
               wrt.WR_chatter_Last_Updated_By__c = uid;
               WRTLTU.add(wrt);
           }
           Update WRTLTU;
         }  
         test.stopTest();
  }
  
}