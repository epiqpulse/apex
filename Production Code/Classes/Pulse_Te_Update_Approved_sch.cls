global class Pulse_Te_Update_Approved_sch implements Schedulable{
    
    global void execute(SchedulableContext sc) {
        Pulse_Te_Update_Approved_Batch batch = new Pulse_Te_Update_Approved_Batch();
        database.executebatch(batch, 1);
    }
}