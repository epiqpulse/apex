public class Pulse_TimeEntryUpdate_Queue implements Queueable, Database.AllowsCallouts{
    public set<Id> timeEntryIds; /* Time Entry Ids are passed here coming from Pulse_Te_Update_Approved_Batch Class */
    public List<Time_Entry__c> TeQList = new List<Time_Entry__c>(); /* Used to requrey time entry and update stataus */
    public List<Time_Entry__c> TeUpdate = new List<Time_Entry__c>(); /* Used to requrey time entry and update stataus */
    private static boolean success = true;
    string exceptionMessage;
      
    public Pulse_TimeEntryUpdate_Queue(set<Id> teQIds) {
        this.timeEntryIds = teQIds; /* the TeQIds is passed from Pulse_Te_Update_Approved_Batch Class */
        TeQList = [Select Id, Date__c, Sta__c FROM Time_Entry__c WHERE Id in : timeEntryIds]; /* Requery the one record to update status */
        for(Integer i = 0; i < TeQList.size(); i++){
          if(TeQList[i].sta__c == 'Transfer Failed'){
             TeQList[i].sta__c = 'Draft';
             system.debug('updating to draft');
          }
          else {
            TeQList[i].Sta__c = 'Approved';
            system.debug('Updating to Approved');
          }  
          TeUpdate.add(TeQList[i]);
          System.debug('add id to set to call time entry');
          system.debug('TeUpate = ' + TeUpdate);
        }        
         update TeUpdate; /* Update time entry status before called weberservice call that will send time entry to epoch */
         system.debug('before calling webservice');
         system.debug('After Calling webservice');
         system.debug('TeUpdate = ' + TeUpdate);     
    }

    public void execute(QueueableContext context){
        system.debug('Do I call wave6 from queue');
        Wave6_TimeEntryHandler.batchsendTimeEntrytoEpoch(timeEntryIds);
    }
}