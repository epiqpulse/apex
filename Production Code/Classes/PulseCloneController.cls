global class PulseCloneController
{
    webservice static string cloneBillableItems(String wrId) // you can pass parameters
    { 
         
        EDiscovery_WorkRequest__c wrObj = [SELECT Name FROM EDiscovery_WorkRequest__c WHERE id=:wrId];
        return 'Success';
        /*EDiscovery_WorkRequest__c clonedWrObj = wrObj.clone(false, true, false, false);
        clonedWrObj.Legacy_Ops_QC_Performed_By__c = null;
        clonedWrObj.Ops_QC_Performed_by__c = null;
        clonedWrObj.Work_Request_Stage__c = null;
        clonedWrObj.Work_Request_Status__c = 'Submitted';
        clonedWrObj.Requested_Time__c = null;
        clonedWrObj.Submitted_Time__c = null;
        clonedWrObj.Ops_Done_Date__c = null;
        clonedWrObj.Original_Ready_For_Invoice_Date__c = null;
        clonedWrObj.Ready_for_Invoice__c = null;
        clonedWrObj.Estimated_Complete_Time__c = null;
        clonedWrObj.Quality_Control_Comments__c = null;
        clonedWrObj.isCloned__c = true;
        clonedWrObj.Work_Request_Cloned_From__c = wrObj.Name;
        insert clonedWrObj;
        */
        // Now get all the Billable Items
        /*List<EDiscovery_BillableItems__c> billItems = new List<EDiscovery_BillableItems__c>();
        List<EDiscovery_BillableItems__c> clonedbillItems = new List<EDiscovery_BillableItems__c>();
        billItems = [SELECT BillableItem__c,CR_Legacy_Billable_Item_ID__c,DataLoader__c,
                    Id,Ignore_Project_Level_Minimum__c,
                    MinimumFeeAmount__c,MinimumFee__c,Monthly__c,Name,NonBillable__c,Notes__c,PricingCategory__c,PricingLibrary__c,
                    PricingType__c,Project__c,Qty__c,Rate__c,ReasonNonBillable__c,Service_Category__c,
                    SFDC_Billable_Item_ID__c,Tier1BilledAmt__c,Tier1BilledQty__c,Tier1StorageQty__c,
                    Tier1StorageRate__c,Tier1UserQty__c,Tier1UserRate__c,Tier2BilledAmt__c,Tier2BilledQty__c,Tier2StorageQty__c,
                    Tier2StorageRate__c,Tier2UserQty__c,Tier2UserRate__c,Tier3BilledAmt__c,Tier3BilledQty__c,Tier3StorageQty__c,
                    Tier3StorageRate__c,Tier3UserQty__c,Tier3UserRate__c,Tiered_Category__c,Tiered_Pricing_Type__c,Unit__c,WorkRequest__c,
                    X3rd_Party_Vended__c FROM EDiscovery_BillableItems__c
                    WHERE WorkRequest__c=:wrId];
                    
        if(billItems.size() >0){
            for(EDiscovery_BillableItems__c items: billItems){
                EDiscovery_BillableItems__c clonedItem = items.clone(false, true, false, false);
                clonedItem.Qty__c = null;
                clonedItem.Rate__c = items.Rate__c;
                clonedItem.WorkRequest__c = clonedWrObj.id;
                clonedItem.isCloned__c = true;
                clonedbillItems.add(clonedItem);
            }
        }  
        
        if(clonedbillItems.size() > 0){
            insert clonedbillItems;
        } */         
        
        //return clonedWrObj.id;       

    }
    
   }