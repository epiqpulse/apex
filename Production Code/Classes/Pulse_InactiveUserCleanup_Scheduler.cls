/* 
    Name:           Pulse_InactiveUserCleanup_Scheduler.cls
    Description:    Scheduler class for the Pulse_InactiveUserCleanup_Batch job. The 
                    constructor for the Batch populates a batchsize variable that is
                    pulled from the metadata settings record for this batch.
   
    Date            Version         Author              Summary of Changes  
-----------------------------------------------------------------------------------------------
    12/24/2018      1.0             Jerry Daru          Initial Release  
-----------------------------------------------------------------------------------------------*/
global class Pulse_InactiveUserCleanup_Scheduler implements Schedulable{
    
    global void execute(SchedulableContext sc) {
        Pulse_InactiveUserCleanup_Batch batch = new Pulse_InactiveUserCleanup_Batch();
        database.executebatch(batch, batch.batchSize);
    }
}